# frozen_string_literal: true

require_relative '../classfile/classfile'
require_relative 'language'
require_relative 'instructions'
require_relative '../../native/native'

module Giuseppe
	# An execution frame
	class Frame
		attr_reader :stack, :locals, :code_attr, :method, :parent_frame
		attr_accessor :pc

		def initialize method, params, parent_frame
			method_attr = method.attr
			fail "Unknown method #{method.name}" unless method_attr
			@method = method
			@pc = 0
			@parent_frame = parent_frame
			if native?
				@locals = params
			else
				@stack = []
				@locals = []
				@code_attr = method_attr.attributes[ClassAttributeCode].first
				save_into_locals params
			end
		end

		def constant_pool
			@method.jvmclass.class_file.constant_pool
		end

		def native?
			@method.attr.access_flags.native?
		end

		def next_instruction
			fail if @pc >= @code_attr.code.length
			@pc += 1
			instruction(-1)
		end

		def instruction offset = 0
			@code_attr.code[@pc + offset]
		end

		def exception_handlers
			@code_attr.exception_handlers_for(@pc - 1)
		end

		def line_number
			return 0 if native?
			@code_attr.line_number_for(@pc - 1)
		end

		def depth
			1 + (parent_frame&.depth || 0)
		end

		def to_s
			"[#{depth}] #{if native? then 'N' else ' ' end} #{@method.to_s}"
		end

			private

		def save_into_locals params
			fail if params.size > @method.descriptor.args.size + 1
			p = params.reverse
			@locals.push(p.pop) if params.size == @method.descriptor.args.size + 1
			@method.descriptor.args.each do |a|
				value = p.pop
				@locals.push value
				@locals.push value if a.wide_primitive?
			end
		end
	end

	# Runs the frame code and handles exceptions
	class Interpreter
		attr_reader :current_frame

		def initialize jvm
			@jvm = jvm
			@current_frame = nil
		end

		def run method, params
			previous_frame = @current_frame
			$logger.debug('jvm.rb') { "[#{previous_frame.depth}] Line number #{previous_frame.line_number}" } if previous_frame
			@current_frame = Frame.new(@jvm.resolve!(method), params, previous_frame)
			$logger.debug('jvm.rb') { @current_frame.to_s }
			if @current_frame.native? then run_native else main_loop end
		ensure
			@current_frame = previous_frame
		end

			private

		def run_native
			send native_name, @jvm, @current_frame.locals
		end

		def native_name
			name = @current_frame.method.jvmclass.descriptor.class_name
			if name.include? '/'
				n = name.gsub('/', '_')
				n[n.rindex('_')] = '_jni_'
				n[0] = n[0].upcase
			else
				n = "Jni_#{name}"
			end
			"#{n.gsub('$', '_')}_#{@current_frame.method.name}"
		end

		def main_loop
			$logger.debug('jvm.rb') { "Running bytecode #{@current_frame.code_attr.code}" }
			loop do
				begin
					opcode = @current_frame.next_instruction
					case opcode
					when 172, 176
						return @current_frame.stack.pop
					when 177
						break
					else
						Instruction.new(@jvm).execute opcode
					end
				rescue JVMError => e
					handle_java_exception e.exception
				rescue ZeroDivisionError
					handle_java_exception @jvm.new_java_object_with_constructor(
							JavaMethodHandle.new(@jvm.java_class('java/lang/ArithmeticException'))
					)
				rescue NoMethodError => e
					raise e if e.receiver
					handle_java_exception @jvm.new_java_object_with_constructor(
							JavaMethodHandle.new(@jvm.java_class('java/lang/NullPointerException'))
					)
				end
			end
		end

		def handle_java_exception exception
			handler = find_exception_handler exception
			raise JVMError, exception unless handler
			@current_frame.stack.push exception
			@current_frame.pc = handler.handler_pc
		end

		def find_exception_handler exception
			handlers = @current_frame.exception_handlers
			i = handlers.index do |e|
					e.catch_type.nil? ||
							@jvm.type_equal_or_superclass?(exception.jvmclass, @jvm.java_class(e.catch_type))
			end
			return handlers[i] if i
		end
	end

	# Resolves fields and methods and checks type equality
	class Resolver
		def initialize jvm
			@jvm = jvm
			@resolved = {}
		end

		def resolve! field
			if @resolved.key? field
				field.jvmclass = @resolved[field]
			else
				original_field = field.clone
				until field.declared?
					fail "Unknown symbol #{original_field}" unless field.jvmclass.super_class
					field.jvmclass = @jvm.java_class(field.jvmclass.super_class)
				end
				@resolved[original_field] = field.jvmclass
			end
			field
		end

		def resolve_special_method! reference_jvmclass, method
			if reference_jvmclass.class_file.access_flags.super? &&
				method.name != '<init>' &&
				reference_jvmclass != method.jvmclass &&
				type_equal_or_superclass?(reference_jvmclass, method.jvmclass)
				method.jvmclass = @jvm.java_class(reference_jvmclass.super_class)
			end
			method
		end

		def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
			return true if jvmclass_a.eql?(jvmclass_b)
			if jvmclass_a.descriptor.array? && jvmclass_b.descriptor.array?
				return false if jvmclass_a.descriptor.dimensions != jvmclass_b.descriptor.dimensions
				type_equal_or_superclass?(
						@jvm.java_class(jvmclass_a.descriptor.element_type),
						@jvm.java_class(jvmclass_b.descriptor.element_type)
				)
			else
				superclass_equal?(jvmclass_a, jvmclass_b) ||
						interface_equal?(jvmclass_a, jvmclass_b)
			end
		end

			private

		def superclass_equal?(jvmclass_a, jvmclass_b)
			return true if
					jvmclass_a.super_class &&
					type_equal_or_superclass?(
							@jvm.java_class(jvmclass_a.super_class),
							jvmclass_b
					)
		end

		def interface_equal?(jvmclass_a, jvmclass_b)
			jvmclass_a.class_file.interfaces.each.any? do |i|
				return true if type_equal_or_superclass?(
						@jvm.java_class(i),
						jvmclass_b
				)
			end
		end
	end

	# Loads classes and creates java arrays and objects
	class Allocator
		def initialize jvm
			@jvm = jvm
			@classes = {}
		end

		def java_to_native_string reference
			method = JavaMethodHandle.new(reference.jvmclass, 'getBytes', '()[B')
			arrayref = @jvm.run(method, [reference])
			arrayref.values.pack('c*')
		end

		def new_java_string value
			jvmclass = @jvm.java_class('java/lang/String')
			stringref = new_java_object jvmclass
			arrayref = new_java_array @jvm.java_class('[B'), [value.chars.size]
			value.unpack('c*').each_with_index { |s, i| arrayref.values[i] = s }
			@jvm.run(JavaMethodHandle.new(jvmclass, '<init>', '([B)V'), [stringref, arrayref])
			stringref
		end

		def new_java_array jvmclass, sizes
			JavaArrayInstance.new jvmclass, sizes
		end

		def new_java_object jvmclass
			initialize_fields_for JavaInstance.new(jvmclass)
		end

		def new_java_object_with_constructor method, params = []
			method = JavaMethodHandle.new(method.jvmclass, '<init>', '()V') unless method.name
			reference = new_java_object method.jvmclass
			@jvm.run method, [reference] + params
			reference
		end

		def new_java_class_object name
			new_java_object_with_constructor(
					JavaMethodHandle.new(@jvm.java_class('java/lang/Class'), '<init>', '(Ljava/lang/String;)V'),
					[new_java_string(TypeDescriptor.from_internal(name).to_s)]
			)
		end

		def java_class descriptor
			if @classes.key? descriptor
				@classes[descriptor]
			else
				jvmclass = JavaClassInstance.new(JavaInstance.new, descriptor)
				@classes[descriptor] = jvmclass
				unless descriptor.array? || descriptor.primitive?
					jvmclass.class_file = ClassFileLoader.new(descriptor.class_name).load
					initialize_static_fields_for jvmclass
					clinit = JavaMethodHandle.new(jvmclass, '<clinit>', '()V')
					@jvm.run(clinit, []) if clinit.declared?
				end
				jvmclass
			end
		end

			private

		def initialize_fields_for reference, jvmclass = reference.jvmclass
			jvmclass.fields
					.reject { |_, f| f.access_flags.static? }
					.each { |f, _| @jvm.set_field(reference, f, f.default_value) }
			return reference if jvmclass.super_class.nil?
			initialize_fields_for(reference, @jvm.java_class(jvmclass.super_class))
		end

		def initialize_static_fields_for jvmclass
			jvmclass.fields
					.select { |_, f| f.access_flags.static? }
					.each { |f, _| @jvm.set_static_field(f, f.default_value) }
		end
	end

	# Mediates between Resolver, Allocator and Interpreter
	class JVM
		extend Forwardable

		def_delegators :@resolver, :resolve!, :resolve_special_method!, :type_equal_or_superclass?
		def_delegators :@allocator, :new_java_array, :new_java_object, :new_java_object_with_constructor, :new_java_class_object, :new_java_string, :java_to_native_string
		def_delegators :@interpreter, :current_frame, :run

		def initialize
			@resolver = Resolver.new self
			@allocator = Allocator.new self
			@interpreter = Interpreter.new self
		end

		def java_class class_type
			class_type = TypeDescriptor.from_internal(class_type) unless class_type.is_a?(TypeDescriptor)
			@allocator.java_class class_type
		end

		def check_array_index reference, index
			return if index >= 0 && index < reference.values.size
			raise JVMError, new_java_object_with_constructor(
					JavaMethodHandle.new(java_class('java/lang/ArrayIndexOutOfBoundsException'))
			)
		end

		def get_field reference, field
			reference.get_field(resolve!(field))
		end

		def get_static_field field
			field.jvmclass.reference.get_field(resolve!(field))
		end

		def set_field reference, field, value
			reference.set_field(resolve!(field), value)
		end

		def set_static_field field, value
			field.jvmclass.reference.set_field(resolve!(field), value)
		end
	end
end
