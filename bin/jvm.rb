# frozen_string_literal: true

require_relative 'classfile'
require_relative 'language'
require_relative 'interpreter'
require_relative 'native'

class Frame
	attr_reader :jvmclass, :stack, :locals, :code_attr, :method
	attr_accessor :pc

	def initialize jvmclass, method, params
		m = jvmclass.methods[method]
		fail "Unknown method #{method.method_name}" unless m
		@jvmclass = jvmclass
		@method = method
		@pc = 0
		@code_attr = m.code
		if native?
			@locals = params
		else
			@stack = []
			@locals = []
			save_into_locals params
		end
	end

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

	def native?
		@code_attr.nil?
	end

	def next_instruction
		@pc += 1
		@code_attr.code[@pc - 1]
	end

	def line_number
		a = @code_attr.attributes.find { |attrib| attrib.is_a? ClassAttributeLineNumber }
		return 0 unless a
		i = a.line_number_table.index { |t| t.start_pc > @pc } || 0
		a.line_number_table[i - 1].line_number
	end
end

class Scheduler
	attr_reader :frames

	def initialize jvm
		@jvm = jvm
		@frames = []
	end

	def run frame
		result = run_and_return frame
		return unless frame.method.return_value?
		return result if @frames.last.native?
		@frames.last.stack.push(result)
	end

	def run_and_return frame
		@frames.push frame
		$logger.debug('jvm.rb') do
			"#{@frames.size}, "\
			"#{frame.jvmclass.class_type}, "\
			"#{frame.method.method_name}"
		end
		if frame.code_attr
			Interpreter.new(@jvm, frame).loop_code
		else
			send frame.method.native_name(frame.jvmclass), @jvm, frame.locals
		end
	ensure
		@frames.pop
	end
end

class Resolver
	def initialize jvm
		@jvm = jvm
	end

	def resolve_field jvmclass, field
		if jvmclass.resolved.key? field
			jvmclass.resolved[field]
		elsif jvmclass.class_file.super_class.nonzero?
			jvmclass.resolved[field] = resolve_field(
					@jvm.load_class(
							jvmclass.class_file.get_attrib_name(
									jvmclass.class_file.super_class
							)
					),
					field
			)
		else
			fail "Unknown field #{field.field_name}"
		end
	end

	def resolve_special_method reference_jvmclass, method_jvmclass, method
		if reference_jvmclass.class_file.access_flags.super? &&
			method.method_name != '<init>' &&
			reference_jvmclass != method_jvmclass &&
			type_equal_or_superclass?(reference_jvmclass, method_jvmclass)
			resolve_method(
					@jvm.load_class(
							reference_jvmclass.class_file.get_attrib_name(
									reference_jvmclass.class_file.super_class
							)
					),
					method
			)
		else
			method_jvmclass
		end
	end

	def resolve_method jvmclass, method
		if jvmclass.resolved.key? method
			jvmclass.resolved[method]
		elsif jvmclass.array?
			jvmclass.resolved[method] = resolve_method(
					@jvm.load_class('java/lang/Object'),
					method
			)
		elsif jvmclass.class_file.super_class.nonzero?
			jvmclass.resolved[method] = resolve_method(
					@jvm.load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)),
					method
			)
		else
			fail "Unknown method #{method.method_name} #{method.method_type}"
		end
	end

	def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		return true if jvmclass_a.class_type == jvmclass_b.class_type
		if jvmclass_a.primitive?
			jvmclass_b == @jvm.load_class('java/lang/Object')
		elsif jvmclass_a.array?
			if jvmclass_b.array?
				return false if jvmclass_a.dimensions != jvmclass_b.dimensions
				jvmclass_a = @jvm.load_class class_type_a.element_type
				jvmclass_b = @jvm.load_class class_type_b.element_type
				type_equal_or_superclass?(jvmclass_a, jvmclass_b)
			else
				jvmclass_b == @jvm.load_class('java/lang/Object')
			end
		else
			superclass_or_interface_equal?(jvmclass_a, jvmclass_b)
		end
	end

	def superclass_or_interface_equal?(jvmclass_a, jvmclass_b)
		return true if
				jvmclass_a.class_file.super_class.nonzero? &&
				type_equal_or_superclass?(
						@jvm.load_class(jvmclass_a.class_file.get_attrib_name(jvmclass_a.class_file.super_class)),
						jvmclass_b
				)
		jvmclass_a.class_file.interfaces.each.any? do |i|
			return true if type_equal_or_superclass?(@jvm.load_class(jvmclass_a.class_file.get_attrib_name(i)), jvmclass_b)
		end
	end
end

class Allocator
	def initialize jvm
		@jvm = jvm
		@classes = {}
	end

	def java_to_native_string reference
		method = JavaMethod.new('getBytes', '()[B')
		arrayref = @jvm.run_and_return(reference.jvmclass, method, [reference])
		arrayref.values.pack('c*')
	end

	def new_java_string value
		jvmclass = load_class('java/lang/String')
		stringref = new_java_object jvmclass
		arrayref = new_java_array load_class('[B'), [value.chars.size]
		value.unpack('c*').each_with_index { |s, i| arrayref.values[i] = s }
		@jvm.run(jvmclass, JavaMethod.new('<init>', '([B)V'), [stringref, arrayref])
		stringref
	end

	def new_java_array jvmclass, sizes
		JavaInstanceArray.new jvmclass, sizes
	end

	def new_java_object jvmclass
		reference = JavaInstance.new jvmclass
		initialize_fields_for reference, jvmclass
		reference
	end

	def initialize_fields_for reference, jvmclass
		static = reference.class_reference?
		jvmclass.fields
				.values
				.select { |f| static == !f.access_flags.static?.nil? }
				.map(&jvmclass.method(:load_java_field))
				.each { |f| @jvm.set_field(reference, jvmclass, f, f.default_value) }
		return if static || jvmclass.class_file.super_class.zero?
		initialize_fields_for(reference, load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)))
	end

	def load_class class_type
		if @classes.key? class_type
			@classes[class_type]
		else
			jvmclass = JavaClass.new(JavaInstance.new, class_type)
			@classes[class_type] = jvmclass
			unless jvmclass.array? || jvmclass.primitive?
				jvmclass.class_file = ClassLoader.new(class_type).load
				initialize_fields_for jvmclass.reference, jvmclass
				clinit = JavaMethod.new('<clinit>', '()V')
				@jvm.run(jvmclass, clinit, []) if jvmclass.methods.include?(clinit)
			end
			jvmclass
		end
	end
end

class JVM
	def initialize
		@resolver = Resolver.new self
		@allocator = Allocator.new self
		@scheduler = Scheduler.new self
	end

	def load_class class_type
		@allocator.load_class class_type
	end

	def frames
		@scheduler.frames
	end

	def check_array_index reference, index
		return if index >= 0 && index < reference.values.size
		raise JVMError, new_java_object_with_constructor(load_class('java/lang/ArrayIndexOutOfBoundsException'))
	end

	def run_and_return jvmclass, method, params
		@scheduler.run_and_return Frame.new(resolve_method(jvmclass, method), method, params)
	end

	def run jvmclass, method, params
		@scheduler.run Frame.new(resolve_method(jvmclass, method), method, params)
	end

	def new_java_object jvmclass
		@allocator.new_java_object jvmclass
	end

	def new_java_object_with_constructor jvmclass, method = JavaMethod.new('<init>', '()V'), params = []
		reference = @allocator.new_java_object jvmclass
		run_and_return jvmclass, method, [reference] + params
		reference
	end

	def new_java_array jvmclass, sizes
		@allocator.new_java_array jvmclass, sizes
	end

	def new_java_class name
		run_and_return(
				load_class('java/lang/Class'),
				JavaMethod.new('forName', '(Ljava/lang/String;)Ljava/lang/Class;'),
				[new_java_string(name)]
		)
	end

	def new_java_string value
		@allocator.new_java_string value
	end

	def java_to_native_string reference
		@allocator.java_to_native_string reference
	end

	def resolve_method jvmclass, method
		@resolver.resolve_method jvmclass, method
	end

	def resolve_special_method reference_jvmclass, method_jvmclass, method
		@resolver.resolve_special_method reference_jvmclass, method_jvmclass, method
	end

	def get_field reference, jvmclass, field
		reference.get_field(@resolver.resolve_field(jvmclass, field), field)
	end

	def get_static_field jvmclass, field
		jvmclass.reference.get_field(@resolver.resolve_field(jvmclass, field), field)
	end

	def set_field reference, jvmclass, field, value
		reference.set_field(@resolver.resolve_field(jvmclass, field), field, value)
	end

	def set_static_field jvmclass, field, value
		jvmclass.reference.set_field(@resolver.resolve_field(jvmclass, field), field, value)
	end

	def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		@resolver.type_equal_or_superclass?(jvmclass_a, jvmclass_b)
	end
end
