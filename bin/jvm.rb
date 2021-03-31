# frozen_string_literal: true

require_relative 'classfile'
require_relative 'language'
require_relative 'operations'
require_relative 'native'

# An execution frame
class Frame
	attr_reader :jvmclass, :stack, :locals, :code_attr, :method, :parent_frame
	attr_accessor :pc

	def initialize method, params, parent_frame
		method_attr = method.jvmclass.methods[method]
		fail "Unknown method #{method.method_name}" unless method_attr
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
		@method.jvmclass.methods[method].access_flags.native?
	end

	def next_instruction
		fail if @pc >= @code_attr.code.length
		@pc += 1
		@code_attr.code[@pc - 1]
	end

		private

	def save_into_locals params
		fail if params.size > @method.args.size + 1
		p = params.reverse
		@locals.push(p.pop) if params.size == @method.args.size + 1
		@method.args.each do |a|
			value = p.pop
			@locals.push value
			@locals.push value if %w[J D].include? a
		end
	end
end

# Runs the frame code and handles exceptions
class Scheduler
	attr_reader :current_frame

	def initialize jvm
		@jvm = jvm
		@current_frame = nil
	end

	def run method, params
		frame = @current_frame
		@current_frame = Frame.new(@jvm.resolve_method!(method), params, frame)
		$logger.debug('jvm.rb') { "#{jvmclass.class_type}, #{method.method_name}" }
		if @current_frame.native?
			send method.native_name(method.jvmclass), @jvm, @current_frame.locals
		else
			loop_code
		end
	ensure
		@current_frame = frame
	end

		private

	def loop_code
		$logger.debug('jvm.rb') { @current_frame.code_attr.code.to_s }
		dispatcher = OperationDispatcher.new @jvm
		loop do
			begin
				opcode = @current_frame.next_instruction
				case opcode
				when 172, 176
					return @current_frame.stack.pop
				when 177
					break
				else
					dispatcher.interpret opcode
				end
			rescue JVMError => e
				handle_exception e.exception
			rescue ZeroDivisionError
				handle_exception @jvm.new_java_object_with_constructor(JavaMethod.new(@jvm.load_class('java/lang/ArithmeticException')))
			rescue NoMethodError => e
				raise e if e.receiver
				handle_exception @jvm.new_java_object_with_constructor(JavaMethod.new(@jvm.load_class('java/lang/NullPointerException')))
			end
		end
	end

	def handle_exception exception
		handler = find_exception_handler exception
		raise JVMError, exception unless handler
		@current_frame.stack.push exception
		@current_frame.pc = handler.handler_pc
	end

	def find_exception_handler exception
		handlers = @current_frame.code_attr.exception_handlers_for(@current_frame.pc - 1)
		i = handlers.index do |e|
				e.catch_type.zero? ||
						@jvm.type_equal_or_superclass?(
								exception.jvmclass,
								@jvm.load_class(
										@current_frame.constant_pool.get_attrib_value(e.catch_type)
								)
						)
		end
		return handlers[i] if i
	end
end

# Resolves fields and methods and checks type equality
class Resolver
	def initialize jvm
		@jvm = jvm
	end

	def resolve_field! field
		if field.jvmclass.resolved.key? field
			field.jvmclass = field.jvmclass.resolved[field]
		elsif field.jvmclass.super_class
			field.jvmclass = @jvm.load_class(field.jvmclass.super_class)
			resolve_field!(field)
			field.jvmclass.resolved[field] = field.jvmclass
		else
			fail "Unknown field #{field.field_name}"
		end
		field
	end

	def resolve_special_method! reference_jvmclass, method
		if reference_jvmclass.class_file.access_flags.super? &&
			method.method_name != '<init>' &&
			reference_jvmclass != method.jvmclass &&
			type_equal_or_superclass?(reference_jvmclass, method.jvmclass)
			method.jvmclass = @jvm.load_class(reference_jvmclass.super_class)
			resolve_method!(method)
		end
		method
	end

	def resolve_method! method
		if method.jvmclass.resolved.key? method
			method.jvmclass = method.jvmclass.resolved[method]
		elsif method.jvmclass.super_class
			method.jvmclass = @jvm.load_class(method.jvmclass.super_class)
			resolve_method!(method)
			method.jvmclass.resolved[method] = method.jvmclass
		else
			fail "Unknown method #{method.method_name} #{method.method_type}"
		end
		method
	end

	def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		return true if jvmclass_a.class_type == jvmclass_b.class_type
		if jvmclass_a.array? && jvmclass_b.array?
			return false if jvmclass_a.dimensions != jvmclass_b.dimensions
			jvmclass_a = @jvm.load_class class_type_a.element_type
			jvmclass_b = @jvm.load_class class_type_b.element_type
			type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		else
			superclass_or_interface_equal?(jvmclass_a, jvmclass_b)
		end
	end

		private

	def superclass_or_interface_equal?(jvmclass_a, jvmclass_b)
		return true if
				jvmclass_a.super_class &&
				type_equal_or_superclass?(
						@jvm.load_class(jvmclass_asuper_class),
						jvmclass_b
				)
		jvmclass_a.interfaces.each.any? do |i|
			return true if type_equal_or_superclass?(
					@jvm.load_class(i),
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
		method = JavaMethod.new(reference.jvmclass, 'getBytes', '()[B')
		arrayref = @jvm.run(method, [reference])
		arrayref.values.pack('c*')
	end

	def new_java_string value
		jvmclass = load_class('java/lang/String')
		stringref = new_java_object jvmclass
		arrayref = new_java_array load_class('[B'), [value.chars.size]
		value.unpack('c*').each_with_index { |s, i| arrayref.values[i] = s }
		@jvm.run(JavaMethod.new(jvmclass, '<init>', '([B)V'), [stringref, arrayref])
		stringref
	end

	def new_java_array jvmclass, sizes
		JavaInstanceArray.new jvmclass, sizes
	end

	def new_java_object jvmclass
		initialize_fields_for JavaInstance.new(jvmclass), jvmclass
	end

	def new_java_class name
		@jvm.run(
				JavaMethod.new(load_class('java/lang/Class'), 'forName', '(Ljava/lang/String;)Ljava/lang/Class;'),
				[new_java_string(name)]
		)
	end

	def load_class class_type
		if @classes.key? class_type
			@classes[class_type]
		else
			jvmclass = JavaClass.new(JavaInstance.new, class_type)
			@classes[class_type] = jvmclass
			unless jvmclass.array? || jvmclass.primitive?
				jvmclass.class_file = ClassLoader.new(class_type).load
				initialize_static_fields_for jvmclass
				clinit = JavaMethod.new(jvmclass, '<clinit>', '()V')
				@jvm.run(clinit, []) if jvmclass.methods.include?(clinit)
			end
			jvmclass
		end
	end

		private

	def initialize_fields_for reference, jvmclass
		static = reference.class_reference?
		jvmclass.fields
				.select { |_, f| static == !f.access_flags.static?.nil? }
				.each { |f, _| @jvm.set_field(reference, f, f.default_value) }
		return reference if static || jvmclass.super_class.nil?
		initialize_fields_for(reference, load_class(jvmclass.super_class))
	end

	def initialize_static_fields_for jvmclass
		initialize_fields_for jvmclass.reference, jvmclass
	end
end

# Mediates between Resolver, Allocator and Scheduler
class JVM
	def initialize
		@resolver = Resolver.new self
		@allocator = Allocator.new self
		@scheduler = Scheduler.new self
	end

	def current_frame
		@scheduler.current_frame
	end

	def load_class class_type
		@allocator.load_class class_type
	end

	def check_array_index reference, index
		return if index >= 0 && index < reference.values.size
		raise JVMError, new_java_object_with_constructor(JavaMethod.new(load_class('java/lang/ArrayIndexOutOfBoundsException')))
	end

	def run method, params
		@scheduler.run method, params
	end

	def new_java_object jvmclass
		@allocator.new_java_object jvmclass
	end

	def new_java_object_with_constructor method, params = []
		method = JavaMethod.new(method.jvmclass, '<init>', '()V') unless method.method_name
		reference = @allocator.new_java_object method.jvmclass
		run method, [reference] + params
		reference
	end

	def new_java_array jvmclass, sizes
		@allocator.new_java_array jvmclass, sizes
	end

	def new_java_class name
		@allocator.new_java_class name
	end

	def new_java_string value
		@allocator.new_java_string value
	end

	def java_to_native_string reference
		@allocator.java_to_native_string reference
	end

	def resolve_method! method
		@resolver.resolve_method! method
	end

	def resolve_special_method! reference_jvmclass, method
		@resolver.resolve_special_method! reference_jvmclass, method
	end

	def get_field reference, field
		reference.get_field(@resolver.resolve_field!(field))
	end

	def get_static_field field
		field.jvmclass.reference.get_field(@resolver.resolve_field!(field))
	end

	def set_field reference, field, value
		reference.set_field(@resolver.resolve_field!(field), value)
	end

	def set_static_field field, value
		field.jvmclass.reference.set_field(@resolver.resolve_field!(field), value)
	end

	def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		@resolver.type_equal_or_superclass?(jvmclass_a, jvmclass_b)
	end
end
