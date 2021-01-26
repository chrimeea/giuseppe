require './classloader'
require './native'

class Frame

	attr_reader :jvmclass, :stack, :locals, :code_attr, :exceptions, :pc, :method

	def initialize jvmclass, method, params
		@jvmclass = jvmclass
		@code_attr = jvmclass.class_file.get_method(method.method_name,
			method.method_type).get_code
		if @code_attr
			@stack = []
			@exceptions = code_attr.exception_table
			p = params.reverse
			@locals = []
			@locals.push(p.pop) if params.size > method.args.size
			method.args.each do |a|
				if a == 'J' or a == 'D'
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

	def is_native?
		@code_attr.code.nil?
	end

	def goto_if
		if yield
			@pc += BinaryParser.to_16bit_signed(@code_attr.code[@pc], @code_attr.code[@pc + 1]) - 1
		else
			@pc += 2
		end
	end

	def next_instruction
		@pc += 1
		@code_attr.code[@pc - 1]
	end

end

class JavaInstance

	attr_reader :class_type

	def initialize class_type = nil
		@class_type = class_type
		@fields = {}
	end

	def field_id jvmclass, field
		"#{jvmclass.class_file.this_class_type}.#{field.field_name}"
	end

	def set_field jvmclass, field, value
		@fields[field_id(jvmclass, field)] = value
	end

	def get_field jvmclass, field
		@fields[field_id(jvmclass, field)]
	end

	def is_class_reference?
		@class_type.nil?
	end
end

class JavaInstanceArray < JavaInstance

	attr_reader :values

	def initialize class_type, counts
		fail unless class_type.chr == '['
		fail unless class_type.count('[') == counts.size
		@values = [nil] * counts.pop
		counts.reverse.each do |c|
			@values = Array.new(c) { |i| @values[i] }
		end
		super class_type
	end

	def element_type
		t = @class_type.gsub('[', '')
		if t[0] == 'L'
			return t[1..-2]
		else
			return t
		end
	end
end

class JVMError < StandardError

	attr_reader :exception

	def initialize exception
		@exception = exception
		super
	end
end

class JVMClass

	attr_reader :class_file, :reference, :resolved

	def initialize class_file
		@class_file = class_file
		@reference = JavaInstance.new
		@resolved = {}
	end

	def has_method? method
		begin
			@class_file.get_method(method.method_name, method.method_type)
			return true
		rescue
			return false
		end
	end

	def has_field? field
		begin
			@class_file.get_field(field.field_name, field.field_type)
			return true
		rescue
			return false
		end
	end
end

class JVMField

	attr_reader :field_name, :field_type

	def initialize field_name, field_type
		@field_name = field_name
		@field_type = field_type
	end

	def default_value
		case @field_type
		when 'B', 'C', 'D', 'F', 'I', 'J', 'S'
			return 0
		when 'Z'
			return false
		else
			return nil
		end
	end
end

class JVMMethod

	attr_reader :method_name, :method_type, :args, :attrib, :retval

	def initialize method_name, method_type
		@method_name = method_name
		@method_type = method_type
		parse_type_descriptors
	end

	def parse_type_descriptors
		pattern = @method_type.match(/^\(([^\)]*)\)(.+)$/)
		descriptors = pattern[1]
		i = 0
		@args = []
		while i < descriptors.size
			case descriptors[i]
			when 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z'
				@args << descriptors[i]
			when 'L'
				i += 1
				j = descriptors.index(';', i)
				@args << descriptors[i...j]
				i = j
			when '['
				j = i
				while descriptors[j] == '['
					j += 1
				end
				@args << descriptors[i..j]
				i = j
			end
			i += 1
		end
		@retval = pattern[2]
	end

	def has_return_value?
		@retval != 'V'
	end

	def native_name jvmclass
		n = jvmclass.class_file.get_attrib_name(jvmclass.class_file.this_class).gsub('/', '_')
		i = n.rindex('_')
		if i
			n[i] = '_jni_'
			n[0] = n[0].upcase
		else
			n = 'Jni_' + n
		end
		n.gsub('$', '_') + '_' + @method_name
	end
end

class JVM

	attr_reader :frames

	def initialize
		@loader = ClassLoader.new
		@frames = []
		@classes = {}
	end

	def load_class class_type
		if @classes.has_key? class_type
			return @classes[class_type]
		else
			jvmclass = JVMClass.new(@loader.load_file(@loader.class_path(class_type)))
			initialize_fields jvmclass.reference, jvmclass
			@classes[class_type] = jvmclass
			clinit = JVMMethod.new('<clinit>', '()V')
			run Frame.new(jvmclass, clinit, []) if jvmclass.has_method?(clinit)
			return jvmclass
		end
	end

	def run_main class_type
		begin
			arrayref = JavaInstanceArray.new('[Ljava/lang/String;', [ARGV.size - 1])
			ARGV[1..-1].each_with_index { |s, i| arrayref.values[i] = new_java_string(s) }
			run Frame.new(load_class(class_type), JVMMethod.new('main', '([Ljava/lang/String;)V'), [arrayref])
		rescue JVMError => e
			method = JVMMethod.new('printStackTrace', '()V')
			run Frame.new(resolve_method(load_class(e.exception.class_type), method),
				method,
				[e.exception])
		end
	end

	def resolve_field jvmclass, field
		if jvmclass.resolved.has_key? field
			return jvmclass.resolved[field]
		elsif jvmclass.has_field?(field)
			return jvmclass
		elsif jvmclass.class_file.super_class.nonzero?
			return resolve_field(load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)), field)
		else
			fail "Unknown field #{field.field_name}"
		end
	end

	def resolve_special_method reference_jvmclass, method_jvmclass, method
		if reference_jvmclass.class_file.access_flags.is_super? and
			method.method_name != '<init>' and
			is_type_equal_or_superclass?(reference_jvmclass.class_file.this_class_type, method_jvmclass.class_file.this_class_type)
			return resolve_method(load_class(reference_jvmclass.class_file.get_attrib_name(reference_jvmclass.class_file.super_class)), method)
		else
			return method_jvmclass
		end
	end

	def resolve_method jvmclass, method
		if jvmclass.resolved.has_key? method
			return jvmclass.resolved[method]
		elsif jvmclass.has_method?(method)
			return jvmclass
		elsif jvmclass.class_file.super_class.nonzero?
			return resolve_method(load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)), method)
		else
			fail "Unknown method #{method.method_name} #{method.method_type}"
		end
	end

	def initialize_fields reference, jvmclass
		static = reference.is_class_reference?
		jvmclass.class_file.fields.select { |f| static == !!f.access_flags.is_static? }.each do |f|
			jvmfield = JVMField.new(
				jvmclass.class_file.constant_pool[f.name_index].value,
				jvmclass.class_file.constant_pool[f.descriptor_index].value)
			reference.set_field(jvmclass, jvmfield, jvmfield.default_value)
		end
		if static == false and jvmclass.class_file.super_class.nonzero?
			initialize_fields(reference,
				load_class(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class)))
		end
	end

	def to_native_string reference
		method = JVMMethod.new('getBytes', '()[B')
		arrayref = run_and_return Frame.new(resolve_method(load_class(reference.class_type), method),
			method,
			[reference])
		arrayref.values.pack('c*')
	end

	def new_java_string value
		class_type = 'java/lang/String'
		stringref = new_java_object class_type
		arrayref = JavaInstanceArray.new('[B', [value.chars.size])
		value.unpack('c*').each_with_index { |s, i| arrayref.values[i] = s }
		run Frame.new(load_class(class_type),
			JVMMethod.new('<init>', '([B)V'), [stringref, arrayref])
		return stringref
	end

	def new_java_class value
		run_and_return Frame.new(load_class('java/lang/Class'),
			JVMMethod.new('forName', '(Ljava/lang/String;)Ljava/lang/Class;'),
			[new_java_string(value)])
	end

	def new_java_object class_type
		jvmclass = load_class class_type
		reference = JavaInstance.new(class_type)
		initialize_fields reference, jvmclass
		return reference
	end

	def handle_exception frame, exception
		handler = resolve_exception_handler frame, exception
		if handler
			frame.stack = exception
			frame.pc = handler.handler_pc
		else
			raise JVMError, exception
		end
	end

	def resolve_exception_handler frame, exception
		frame.exceptions.each do |e|
			if frame.pc - 1 >= e.start_pc and frame.pc - 1 < e.end_pc and
				(e.catch_type == 0 or
				is_type_equal_or_superclass?(exception.class_type,
					frame.jvmclass.class_file.get_attrib_name(e.catch_type)))
				return e
			end
		end
		return nil
	end

	def is_type_equal_or_superclass?(class_type_a, class_type_b)
		if class_type_a == class_type_b
			return true
		elsif class_type_a.chr == '['
			if class_type_b.chr == '['
				return is_type_equal_or_superclass(class_type_a[1..-1], class_type_b[1..-1])
			else
				return class_type_b == 'java/lang/Object'
			end
		else
			jvmclass = load_class class_type_a
			return true if jvmclass.class_file.super_class.nonzero? and
				is_type_equal_or_superclass?(jvmclass.class_file.get_attrib_name(jvmclass.class_file.super_class), class_type_b)
			jvmclass.class_file.interfaces.each.any? do |i|
				return true if is_type_equal_or_superclass?(jvmclass.class_file.get_attrib_name(i), class_type_b)
			end
			return false
		end
	end

	def run frame
		result = run_and_return frame
		if frame.method.has_return_value?
			if @frames.last.is_native?
				return result
			else
				@frames.last.stack.push(result)
			end
		end
	end

	def run_and_return frame
		begin
			@frames.push frame
			$logger.info('jvm.rb') { "#{@frames.size}, #{frame.jvmclass.class_file.this_class_type}, #{frame.method.method_name}, PARAMS: #{frame.locals}" }
			if frame.code_attr
				while frame.pc < frame.code_attr.code.length
					begin
						opcode = frame.next_instruction
						case opcode
						when 0
						when 1
							frame.stack.push nil
						when 2
							frame.stack.push -1
						when 3, 9
							frame.stack.push 0
						when 4, 10
							frame.stack.push 1
						when 5
							frame.stack.push 2
						when 6
							frame.stack.push 3
						when 7
							frame.stack.push 4
						when 8
							frame.stack.push 5
						when 16
							frame.stack.push BinaryParser.to_8bit_signed(frame.next_instruction)
						when 18
							index = frame.next_instruction
							attrib = frame.jvmclass.class_file.constant_pool[index]
							if attrib.is_a? ConstantPoolConstantValueInfo
								frame.stack.push attrib.value
							elsif attrib.is_a? ConstantPoolConstantIndex1Info
								value = frame.jvmclass.class_file.constant_pool[attrib.index1].value
								if attrib.is_string?
									reference = new_java_string(value)
									method = JVMMethod.new('intern', '()Ljava/lang/String;')
									frame.stack.push run_and_return(Frame.new(resolve_method(load_class(reference.class_type), method),
										method,
										[reference]))
								else
									frame.stack.push new_java_class(value)
								end
							else
								fail 'Illegal attribute type'
							end
						when 20
							index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							frame.stack.push frame.jvmclass.class_file.constant_pool[index].value
						when 21, 25
							frame.stack.push frame.locals[frame.next_instruction]
						when 26, 30, 34, 38, 42
							frame.stack.push frame.locals[0]
						when 27, 31, 35, 39, 43
							frame.stack.push frame.locals[1]
						when 28, 32, 36, 40, 44
							frame.stack.push frame.locals[2]
						when 29, 33, 37, 41, 45
							frame.stack.push frame.locals[3]
						when 50
							index = frame.stack.pop
							arrayref = frame.stack.pop
							frame.stack.push arrayref.values[index]
						when 51
							index = frame.stack.pop
							arrayref = frame.stack.pop
							frame.stack.push BinaryParser.to_8bit_signed(arrayref.values[index])
						when 54, 56, 58
							frame.locals[frame.next_instruction] = frame.stack.pop
						when 55, 57
							index = frame.next_instruction
							frame.locals[index], frame.locals[index + 1] =
								BinaryParser.to_8bit(frame.stack.pop)
						when 59, 67, 75
							frame.locals[0] = frame.stack.pop
						when 60, 68, 76
							frame.locals[1] = frame.stack.pop
						when 61, 69, 77
							frame.locals[2] = frame.stack.pop
						when 62, 70, 78
							frame.locals[3] = frame.stack.pop
						when 63, 71
							frame.locals[0] = frame.locals[1] = frame.stack.pop
						when 64, 72
							frame.locals[1] = frame.locals[2] = frame.stack.pop
						when 65, 73
							frame.locals[2] = frame.locals[3] = frame.stack.pop
						when 66, 74
							frame.locals[3] = frame.locals[4] = frame.stack.pop
						when 79, 83, 84
							value = frame.stack.pop
							index = frame.stack.pop
							arrayref = frame.stack.pop
							arrayref.values[index] = value
						when 87
							frame.stack.pop
						when 89
							frame.stack.push frame.stack.last
						when 96
							frame.stack.push(frame.stack.pop + frame.stack.pop)
						when 100
							v2 = frame.stack.pop
							v1 = frame.stack.pop
							frame.stack.push v1 - v2
						when 104
							frame.stack.push(frame.stack.pop * frame.stack.pop)
						when 108
							v2 = frame.stack.pop
							v1 = frame.stack.pop
							frame.stack.push v1 / v2
						when 120
							v2 = frame.stack.pop & 31
							v1 = frame.stack.pop
							frame.stack.push(v1 << v2)
						when 122
							v2 = frame.stack.pop & 31
							v1 = frame.stack.pop
							frame.stack.push(v1 >> v2)
						when 126
							frame.stack.push(frame.stack.pop & frame.stack.pop)
						when 128
							frame.stack.push(frame.stack.pop | frame.stack.pop)
						when 130
							frame.stack.push(frame.stack.pop ^ frame.stack.pop)
						when 132
							frame.locals[frame.next_instruction] += BinaryParser.to_8bit_signed(frame.next_instruction)
						when 146
							q, r = BinaryParser.to_8bit frame.stack.pop
							frame.stack.push r
						when 153
							frame.goto_if { frame.stack.pop.zero? }
						when 154
							frame.goto_if { frame.stack.pop.nonzero? }
						when 155
							frame.goto_if { frame.stack.pop < 0 }
						when 156
							frame.goto_if { frame.stack.pop >= 0 }
						when 157
							frame.goto_if { frame.stack.pop > 0 }
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
							field_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							details = frame.jvmclass.class_file.class_and_name_and_type(field_index)
							jvmclass = load_class(details.class_type)
							field = JVMField.new(details.field_name, details.field_type)
							frame.stack.push jvmclass.reference.get_field(resolve_field(jvmclass, field), field)
						when 179
							field_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							details = frame.jvmclass.class_file.class_and_name_and_type(field_index)
							jvmclass = load_class(details.class_type)
							field = JVMField.new(details.field_name, details.field_type)
							jvmclass.reference.set_field(resolve_field(jvmclass, field), field, frame.stack.pop)
						when 180
							field_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							details = frame.jvmclass.class_file.class_and_name_and_type(field_index)
							reference = frame.stack.pop
							field = JVMField.new(details.field_name, details.field_type)
							frame.stack.push reference.get_field(resolve_field(load_class(details.class_type), field), field)
						when 181
							field_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							details = frame.jvmclass.class_file.class_and_name_and_type(field_index)
							value = frame.stack.pop
							reference = frame.stack.pop
							field = JVMField.new(details.field_name, details.field_type)
							reference.set_field(resolve_field(load_class(details.class_type), field), field, value)
						when 182, 183, 184, 185
							method_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							details = frame.jvmclass.class_file.class_and_name_and_type(method_index)
							method = JVMMethod.new(details.field_name, details.field_type)
							params = []
							args_count = method.args.size
							args_count.times { params.push frame.stack.pop }
							if opcode == 184
								jvmclass = resolve_method(load_class(details.class_type), method)
							else
								reference = frame.stack.pop
								params.push reference
								if opcode == 183
									jvmclass = resolve_special_method(load_class(reference.class_type),
										load_class(details.class_type), method)
								else
									jvmclass = resolve_method(load_class(reference.class_type), method)
								end
							end
							if opcode == 185
								frame.next_instruction
								frame.next_instruction
							end
							run Frame.new(jvmclass, method, params.reverse)
						when 187
							class_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							frame.stack.push new_java_object(frame.jvmclass.class_file.get_attrib_name(class_index))
						when 188
							count = frame.stack.pop
							array_code = frame.next_instruction
							array_type = [nil, nil, nil, nil, '[Z', '[C', '[F', '[D', '[B', '[S', '[I', '[J']
							frame.stack.push JavaInstanceArray.new(array_type[array_code], [count])
						when 189
							class_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							array_type = "[#{frame.jvmclass.class_file.get_attrib_name(class_index)}"
							count = frame.stack.pop
							frame.stack.push JavaInstanceArray.new(array_type, [count])
						when 190
							array_reference = frame.stack.pop
							frame.stack.push array_reference.values.size
						when 191
							raise JVMError, frame.stack.pop
						when 192
							class_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							reference = frame.stack.last
							if reference and not is_type_equal_or_superclass?(reference.class_type, frame.jvmclass.class_file.get_attrib_name(class_index))
								exception = new_java_object 'java/lang/ClassCastException'
								run_and_return Frame.new(load_class(exception.class_type), JVMMethod.new('<init>', '()V'))
								raise JVMError, exception
							end
						when 193
							class_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							reference = frame.stack.pop
							if reference
								frame.stack.push(is_type_equal_or_superclass?(reference.class_type,
									frame.jvmclass.class_file.get_attrib_name(class_index)) ? 1 : 0)
							else
								frame.stack.push 0
							end
						when 197
							class_index = BinaryParser.to_16bit_unsigned(frame.next_instruction,
								frame.next_instruction)
							dimensions = frame.next_instruction
							counts = []
							dimensions.times { counts << frame.stack.pop }
							frame.stack.push JavaInstanceArray.new(frame.jvmclass.class_file.get_attrib_name(class_index),
								counts.reverse)
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
						handle_exception frame, new_java_object('java/lang/ArithmeticException')
					rescue NoMethodError => e
						if e.receiver
							raise e
						else
							handle_exception frame, new_java_object('java/lang/NullPointerException')
						end
					end
				end
			else
				send frame.method.native_name(frame.jvmclass), self, frame.locals
			end
		ensure
			@frames.pop
		end
	end
end
