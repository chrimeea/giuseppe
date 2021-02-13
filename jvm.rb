# frozen_string_literal: true

require './classloader'
require './language'
require './native'

class Frame
	attr_reader :jvmclass, :stack, :locals, :code_attr, :exceptions, :method
	attr_accessor :pc

	def initialize jvm, jvmclass, method, params
		@jvm = jvm
		@jvmclass = jvmclass
		@code_attr = jvmclass.class_file.get_method(method.method_name,
				method.method_type).code
		if @code_attr
			@stack = []
			@exceptions = code_attr.exception_table
			p = params.reverse
			@locals = []
			@locals.push(p.pop) if params.size > method.args.size
			method.args.each do |a|
				if ['J', 'D'].include? a
					value = p.pop
					@locals.push value
					@locals.push value
				else
					@locals.push p.pop
				end
			end
		else
			@locals = params
		end
		@method = method
		@pc = 0
	end

	def native?
		@code_attr.code.nil?
	end

	def goto_if
		@pc +=	if yield
					BinaryParser.to_signed(
						BinaryParser.to_16bit_unsigned(
							@code_attr.code[@pc], @code_attr.code[@pc + 1]), 2) - 1
				else
					2
				end
	end

	def next_instruction
		@pc += 1
		@code_attr.code[@pc - 1]
	end

	def op_aconst value
		@stack.push value
	end

	def op_bipush
		@stack.push BinaryParser.to_signed(next_instruction, 1)
	end

	def op_ldc
		index = next_instruction
		attrib = @jvmclass.class_file.constant_pool[index]
		if attrib.is_a? ConstantPoolConstantValueInfo
			@stack.push attrib.value
		elsif attrib.is_a? ConstantPoolConstantIndex1Info
			value = @jvmclass.class_file.constant_pool[attrib.index1].value
			if attrib.string?
				reference = @jvm.new_java_string(value)
				method = JavaMethod.new('intern', '()Ljava/lang/String;')
				@stack.push @jvm.run_and_return(reference.jvmclass, method, [reference])
			else
				@stack.push @jvm.new_java_class(value)
			end
		else
			fail 'Illegal attribute type'
		end
	end

	def op_ldc2_wide
		index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		@stack.push @jvmclass.class_file.constant_pool[index].value
	end

	def op_iload index
		@stack.push @locals[index]
	end

	def op_lstore index
		@locals[index] = @locals[index + 1] = @stack.pop
	end

	def op_istore index
		@locals[index] = @stack.pop
	end

	def op_iaload
		index = @stack.pop
		arrayref = @stack.pop
		@jvm.check_array_index arrayref, index
		@stack.push arrayref.values[index]
	end

	def op_iastore
		value = @stack.pop
		index = @stack.pop
		arrayref = @stack.pop
		@jvm.check_array_index arrayref, index
		arrayref.values[index] = value
	end

	def op_dup
		@stack.push @stack.last
	end

	def op_iadd
		@stack.push(@stack.pop + @stack.pop)
	end

	def op_isub
		v2 = @stack.pop
		v1 = @stack.pop
		@stack.push v1 - v2
	end

	def op_imul
		@stack.push(@stack.pop * @stack.pop)
	end

	def op_idiv
		v2 = @stack.pop
		v1 = @stack.pop
		@stack.push v1 / v2
	end

	def op_ishl
		v2 = @stack.pop & 31
		v1 = @stack.pop
		@stack.push(v1 << v2)
	end

	def op_ishr
		v2 = @stack.pop & 31
		v1 = @stack.pop
		@stack.push(v1 >> v2)
	end

	def op_iand
		@stack.push(@stack.pop & @stack.pop)
	end

	def op_ior
		@stack.push(@stack.pop | @stack.pop)
	end

	def op_ixor
		@stack.push(@stack.pop ^ @stack.pop)
	end

	def op_iinc
		index = next_instruction
		value = next_instruction
		@locals[index] += BinaryParser.to_signed(value, 1)
	end

	def op_i2b
		@stack.push BinaryParser.to_signed(BinaryParser.trunc_to(@stack.pop, 1), 1)
	end

	def op_i2c
		@stack.push BinaryParser.trunc_to(@stack.pop, 1)
	end

	def op_i2s
		@stack.push BinaryParser.to_signed(BinaryParser.trunc_to(@stack.pop, 2), 2)
	end

	def op_getstatic
		field_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		details = @jvmclass.class_file.class_and_name_and_type(field_index)
		field = JavaField.new(details.field_name, details.field_type)
		@stack.push @jvm.get_static_field(@jvm.load_class(details.class_type), field)
	end

	def op_putstatic
		field_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		details = @jvmclass.class_file.class_and_name_and_type(field_index)
		field = JavaField.new(details.field_name, details.field_type)
		@jvm.set_static_field(@jvm.load_class(details.class_type), field, @stack.pop)
	end

	def op_getfield
		field_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		details = @jvmclass.class_file.class_and_name_and_type(field_index)
		reference = @stack.pop
		field = JavaField.new(details.field_name, details.field_type)
		@stack.push @jvm.get_field(reference, @jvm.load_class(details.class_type), field)
	end

	def op_putfield
		field_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		details = @jvmclass.class_file.class_and_name_and_type(field_index)
		value = @stack.pop
		reference = @stack.pop
		field = JavaField.new(details.field_name, details.field_type)
		@jvm.set_field(reference, @jvm.load_class(details.class_type), field, value)
	end

	def op_invoke opcode
		method_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		details = @jvmclass.class_file.class_and_name_and_type(method_index)
		method = JavaMethod.new(details.field_name, details.field_type)
		params = []
		args_count = method.args.size
		args_count.times { params.push @stack.pop }
		if opcode == 184
			jvmclass = @jvm.resolve_method(@jvm.load_class(details.class_type), method)
		else
			reference = @stack.pop
			params.push reference
			if opcode == 183
				jvmclass = @jvm.resolve_special_method(reference.jvmclass,
					@jvm.load_class(details.class_type), method)
			else
				jvmclass = @jvm.resolve_method(reference.jvmclass, method)
			end
		end
		if opcode == 185
			next_instruction
			next_instruction
		end
		@jvm.run jvmclass, method, params.reverse
	end

	def op_newobject
		class_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		@stack.push @jvm.new_java_object(@jvm.load_class(@jvmclass.class_file.get_attrib_name(class_index)))
	end

	def op_newarray
		count = stack.pop
		array_code = next_instruction
		array_type = [nil, nil, nil, nil, '[Z', '[C', '[F', '[D', '[B', '[S', '[I', '[J']
		@stack.push @jvm.new_java_array(@jvm.load_class(array_type[array_code]), [count])
	end

	def op_anewarray
		class_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		array_type = "[#{@jvmclass.class_file.get_attrib_name(class_index)}"
		count = @stack.pop
		@stack.push @jvm.new_java_array(@jvm.load_class(array_type), [count])
	end

	def op_arraylength
		array_reference = @stack.pop
		@stack.push array_reference.values.size
	end

	def op_athrow
		raise JVMError, @stack.pop
	end

	def op_checkcast
		class_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		reference = @stack.last
		if reference && !@jvm.type_equal_or_superclass?(reference.jvmclass, @jvm.load_class(@jvmclass.class_file.get_attrib_name(class_index)))
			raise JVMError, @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/ClassCastException'))
		end
	end

	def op_instanceof
		class_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		reference = @stack.pop
		if reference
			@stack.push(@jvm.type_equal_or_superclass?(reference.jvmclass,
				@jvm.load_class(@jvmclass.class_file.get_attrib_name(class_index))) ? 1 : 0)
		else
			@stack.push 0
		end
	end

	def op_multianewarray
		class_index = BinaryParser.to_16bit_unsigned(
			next_instruction,
			next_instruction
		)
		dimensions = next_instruction
		counts = []
		dimensions.times { counts << @stack.pop }
		@stack.push @jvm.new_java_array(
				@jvm.load_class(@jvmclass.class_file.get_attrib_name(class_index)),
				counts.reverse
		)
	end
end

class JVMError < StandardError
	attr_reader :exception

	def initialize exception
		@exception = exception
		super
	end
end

class Scheduler
	attr_reader :frames

	def initialize jvm
		@jvm = jvm
		@frames = []
	end

	def handle_exception frame, exception
		handler = resolve_exception_handler frame, exception
		raise JVMError, exception unless handler
		frame.stack.push exception
		frame.pc = handler.handler_pc
	end

	def resolve_exception_handler frame, exception
		frame.exceptions.each do |e|
			if frame.pc - 1 >= e.start_pc && frame.pc - 1 < e.end_pc &&
				(e.catch_type.zero? ||
				@jvm.type_equal_or_superclass?(exception.jvmclass,
					@jvm.load_class(frame.jvmclass.class_file.get_attrib_name(e.catch_type))))
				return e
			end
		end
	end

	def run frame
		result = run_and_return frame
		return unless frame.method.return_value?
		return result if @frames.last.native?
		@frames.last.stack.push(result)
	end

	def run_and_return frame
		@frames.push frame
		$logger.info('jvm.rb') do
			"#{@frames.size}, "\
			"#{frame.jvmclass.class_file.this_class_type}, "\
			"#{frame.method.method_name}, "\
			"PARAMS: #{frame.locals}"
		end
		if frame.code_attr
			loop_code frame
		else
			send frame.method.native_name(frame.jvmclass), @jvm, frame.locals
		end
	ensure
		@frames.pop
	end

	def loop_code frame
		while frame.pc < frame.code_attr.code.length
			begin
				opcode = frame.next_instruction
				case opcode
				when 0, 133, 134, 135, 137, 138, 141
				when 1
					frame.op_aconst nil
				when 2
					frame.op_aconst(-1)
				when 3, 9
					frame.op_aconst 0
				when 4, 10
					frame.op_aconst 1
				when 5
					frame.op_aconst 2
				when 6
					frame.op_aconst 3
				when 7
					frame.op_aconst 4
				when 8
					frame.op_aconst 5
				when 16
					frame.op_bipush
				when 18
					frame.op_ldc
				when 20
					frame.op_ldc2_wide
				when 21, 24, 25
					frame.op_iload frame.next_instruction
				when 55, 57
					frame.op_lstore frame.next_instruction
				when 26, 30, 34, 38, 42
					frame.op_iload 0
				when 27, 31, 35, 39, 43
					frame.op_iload 1
				when 28, 32, 36, 40, 44
					frame.op_iload 2
				when 29, 33, 37, 41, 45
					frame.op_iload 3
				when 46, 50, 51
					frame.op_iaload
				when 54, 56, 58
					frame.op_istore frame.next_instruction
				when 59, 67, 75
					frame.op_istore 0
				when 60, 68, 76
					frame.op_istore 1
				when 61, 69, 77
					frame.op_istore 2
				when 62, 70, 78
					frame.op_istore 3
				when 63, 71
					frame.op_lstore 0
				when 64, 72
					frame.op_lstore 1
				when 65, 73
					frame.op_lstore 2
				when 66, 74
					frame.op_lstore 3
				when 79, 83, 84
					frame.op_iastore
				when 87
					frame.stack.pop
				when 89
					frame.op_dup
				when 96
					frame.op_iadd
				when 100
					frame.op_isub
				when 104
					frame.op_imul
				when 108
					frame.op_idiv
				when 110
					frame.op_idiv
				when 120
					frame.op_ishl
				when 122
					frame.op_ishr
				when 126
					frame.op_iand
				when 128
					frame.op_ior
				when 130
					frame.op_ixor
				when 132
					frame.op_iinc
				when 145
					frame.op_i2b
				when 146
					frame.op_i2c
				when 147
					frame.op_i2s
				when 153
					frame.goto_if { frame.stack.pop.zero? }
				when 154
					frame.goto_if { frame.stack.pop.nonzero? }
				when 155
					frame.goto_if { frame.stack.pop.negative? }
				when 156
					frame.goto_if { frame.stack.pop >= 0 }
				when 157
					frame.goto_if { frame.stack.pop.positive? }
				when 158
					frame.goto_if { frame.stack.pop <= 0 }
				when 159
					frame.goto_if { frame.stack.pop == frame.stack.pop }
				when 160
					frame.goto_if { frame.stack.pop != frame.stack.pop }
				when 161
					frame.goto_if { frame.stack.pop > frame.stack.pop }
				when 162
					frame.goto_if { frame.stack.pop <= frame.stack.pop }
				when 163
					frame.goto_if { frame.stack.pop < frame.stack.pop }
				when 164
					frame.goto_if { frame.stack.pop >= frame.stack.pop }
				when 165
					frame.goto_if { frame.stack.pop == frame.stack.pop }
				when 166
					frame.goto_if { frame.stack.pop != frame.stack.pop }
				when 167
					frame.goto_if { true }
				when 172, 176
					return frame.stack.pop
				when 177
					break
				when 178
					frame.op_getstatic
				when 179
					frame.op_putstatic
				when 180
					frame.op_getfield
				when 181
					frame.op_putfield
				when 182, 183, 184, 185
					frame.op_invoke opcode
				when 187
					frame.op_newobject
				when 188
					frame.op_newarray
				when 189
					frame.op_anewarray
				when 190
					frame.op_arraylength
				when 191
					frame.op_athrow
				when 192
					frame.op_checkcast
				when 193
					frame.op_instanceof
				when 197
					frame.op_multianewarray
				when 198
					frame.goto_if { frame.stack.pop.nil? }
				when 199
					frame.goto_if { frame.stack.pop }
				else
					fail "Unsupported opcode #{opcode}"
				end
			rescue JVMError => e
				handle_exception frame, e.exception
			rescue ZeroDivisionError
				handle_exception frame, @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/ArithmeticException'))
			rescue NoMethodError => e
				if e.receiver
					raise e
				else
					handle_exception frame, @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/NullPointerException'))
				end
			end
		end
	end
end

class Resolver
	def initialize jvm
		@classes = {}
		@jvm = jvm
		@loader = ClassLoader.new
	end

	def load_class class_type
		if @classes.key? class_type
			@classes[class_type]
		else
			jvmclass = JavaClass.new class_type
			@classes[class_type] = jvmclass
			if !jvmclass.array?
				jvmclass.class_file = @loader.load_file(@loader.class_path(class_type))
				initialize_fields jvmclass.reference, jvmclass
				clinit = JavaMethod.new('<clinit>', '()V')
				@jvm.run(jvmclass, clinit, []) if jvmclass.method?(clinit)
			end
			jvmclass
		end
	end

	def initialize_fields reference, jvmclass
		static = reference.class_reference?
		jvmclass.class_file.fields.select { |f| static == !f.access_flags.static?.nil? }.each do |f|
			jvmfield = JavaField.new(
					jvmclass.class_file.constant_pool[f.name_index].value,
					jvmclass.class_file.constant_pool[f.descriptor_index].value
			)
			@jvm.set_field(reference, jvmclass, jvmfield, jvmfield.default_value)
		end
		return if static || jvmclass.class_file.super_class.zero?
		initialize_fields(reference, load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)))
	end

	def resolve_field jvmclass, field
		if jvmclass.resolved.key? field
			jvmclass.resolved[field]
		elsif jvmclass.field?(field)
			jvmclass.resolved[field] = jvmclass
		elsif jvmclass.class_file.super_class.nonzero?
			jvmclass.resolved[field] = resolve_field(load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)), field)
		else
			fail "Unknown field #{field.field_name}"
		end
	end

	def resolve_special_method reference_jvmclass, method_jvmclass, method
		if	reference_jvmclass.class_file.access_flags.super? &&
			method.method_name != '<init>' &&
			type_equal_or_superclass?(reference_jvmclass.class_type, method_jvmclass.class_type)
				resolve_method(load_class(reference_jvmclass.class_file.get_attrib_name(reference_jvmclass.class_file.super_class)), method)
		else
			method_jvmclass
		end
	end

	def resolve_method jvmclass, method
		if jvmclass.resolved.key? method
			jvmclass.resolved[method]
		elsif jvmclass.method?(method)
			jvmclass.resolved[method] = jvmclass
		elsif jvmclass.class_file.super_class.nonzero?
			jvmclass.resolved[method] = resolve_method(load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)), method)
		else
			fail "Unknown method #{method.method_name} #{method.method_type}"
		end
	end

	def type_equal_or_superclass?(jvmclass_a, jvmclass_b)
		return true if jvmclass_a.class_type == jvmclass_b.class_type
		if jvmclass_a.array?
			if jvmclass_b.array?
				type_equal_or_superclass?(class_type_a[1..-1], class_type_b[1..-1])
			else
				jvmclass_b == load_class('java/lang/Object')
			end
		else
			return true if	jvmclass_a.class_file.super_class.nonzero? &&
							type_equal_or_superclass?(
								load_class(jvmclass_a.class_file.get_attrib_name(jvmclass_a.class_file.super_class)),
								jvmclass_b
							)
			jvmclass_a.class_file.interfaces.each.any? do |i|
				return true if type_equal_or_superclass?(load_class(jvmclass_a.class_file.get_attrib_name(i)), jvmclass_b)
			end
		end
	end
end

class Allocator
	def initialize jvm
		@jvm = jvm
	end

	def java_to_native_string reference
		method = JavaMethod.new('getBytes', '()[B')
		arrayref = @jvm.run_and_return(reference.jvmclass, method, [reference])
		arrayref.values.pack('c*')
	end

	def new_java_string value
		jvmclass = @jvm.load_class('java/lang/String')
		stringref = new_java_object jvmclass
		arrayref = new_java_array @jvm.load_class('[B'), [value.chars.size]
		value.unpack('c*').each_with_index { |s, i| arrayref.values[i] = s }
		@jvm.run(jvmclass,
				JavaMethod.new('<init>', '([B)V'),
				[stringref, arrayref]
		)
		stringref
	end

	def new_java_class name
		@jvm.run_and_return(@jvm.load_class('java/lang/Class'),
				JavaMethod.new('forName', '(Ljava/lang/String;)Ljava/lang/Class;'),
				[new_java_string(name)]
		)
	end

	def new_java_array jvmclass, sizes
		JavaInstanceArray.new jvmclass, sizes
	end

	def new_java_object jvmclass
		JavaInstance.new jvmclass
	end

	def check_array_index reference, index
		return if index >= 0 && index < reference.values.size
		raise JVMError, @jvm.new_java_object_with_constructor(@jvm.load_class('java/lang/ArrayIndexOutOfBoundsException'))
	end
end

class JVM
	def initialize
		@resolver = Resolver.new self
		@allocator = Allocator.new self
		@scheduler = Scheduler.new self
	end

	def frames
		@scheduler.frames
	end

	def load_class class_type
		@resolver.load_class class_type
	end

	def check_array_index reference, index
		@allocator.check_array_index reference, index
	end

	def run_and_return jvmclass, method, params
		@scheduler.run_and_return Frame.new(self, resolve_method(jvmclass, method), method, params)
	end

	def run jvmclass, method, params
		@scheduler.run Frame.new(self, resolve_method(jvmclass, method), method, params)
	end

	def new_java_object jvmclass
		reference = @allocator.new_java_object jvmclass
		@resolver.initialize_fields reference, jvmclass
		reference
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
		@allocator.new_java_class name
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
