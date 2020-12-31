require './classloader'

class Frame

	attr_reader :stack, :locals, :code, :class_file, :exceptions
	attr_accessor :pc

	def initialize method, params
		@stack = []
		code_attr = method.attrib.get_code
		@code = code_attr.code
		@exceptions = code_attr.exception_table
		@locals = params
		@class_file = method.class_file
		@pc = 0
	end
end

class Instance

	attr_reader :class_file

	def initialize class_file
		@class_file = class_file
		@fields = {}
	end

	def set_field field, value
		@fields[field.id] = value
	end

	def get_field field
		@fields[field.id]
	end
end

class InstanceArray < Instance

	attr_reader :values

	def initialize class_type, count
		@values = Array.new(count)
		super class_type
	end
end

class JVMError < StandardError

	attr_reader :exception

	def initialize exception
		@exception = exception
		super
	end

	def to_s
		@exception.class_file.this_class_type
	end
end

class JVMField

	attr_reader :class_file, :field_name, :field_type, :id

	def initialize class_file, field_name, field_type
		@class_file = class_file
		@field_name = field_name
		@field_type = field_type
		@id = "#{class_file.this_class_type}.#{field_name}"
	end
end

class JVMMethod

	attr_reader :class_file, :method_name, :method_type, :args, :attrib

	def initialize class_file, method_name, method_type
		@class_file = class_file
		@method_name = method_name
		@method_type = method_type
		@attrib = class_file.get_method(method_name, method_type)
		parse_type_descriptors method_type.match(/^\(([^\)]*)\).*$/)[1]
	end

	def parse_type_descriptors descriptors
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
	end
end

class JVM

	def initialize
		@loader = ClassLoader.new
	end

	def run_main class_type
		begin
			class_file = @loader.load_class class_type
			arrayref = InstanceArray.new('[Ljava/lang/String;', ARGV.size - 1)
			ARGV[1..-1].each { |s| arrayref.values << new_string(s) }
			run Frame.new(JVMMethod.new(class_file, 'main', '([Ljava/lang/String;)V'), [arrayref])
		rescue JVMError => e
			puts e
		end
	end

	def resolve_method class_file, method_class_file, method_name, method_type
		if class_file.access_flags.is_super? and
			method_name != '<init>' and
			is_type_equal_or_superclass?(class_file.this_class_type, method_class_file.this_class_type)
			begin
				return JVMMethod.new(class_file, method_name, method_type)
			rescue
				if class_file.super_class.nonzero?
					return resolve_method(@loader.load_class(class_file.get_attrib_name(class_file.super_class)),
						method_class_file, method_name, method_type)
				else
					fail "Unknown method #{method_name}"
				end
			end
		else
			return JVMMethod.new(method_class_file, method_name, method_type)
		end
	end

	def initialize_fields reference, class_type
		class_file = @loader.load_class class_type
		class_file.fields.each do |f|
			case class_file.constant_pool[f.descriptor_index].value
			when 'B', 'C', 'D', 'F', 'I', 'J', 'S'
				v = 0
			when 'Z'
				v = false
			else
				v = nil
			end
			reference.set_field(JVMField.new(class_file,
				class_file.constant_pool[f.name_index].value,
				class_file.constant_pool[f.descriptor_index].value), v)
		end
		if class_file.super_class.nonzero?
			initialize_fields(reference, class_file.get_attrib_name(class_file.super_class))
		end
	end

	def new_string value
		stringref = new_object 'java/lang/String'
		arrayref = InstanceArray.new('[B', ARGV.size - 1)
		arrayref.values << value.unpack('c*')
		run Frame.new(JVMMethod.new(stringref.class_file, '<init>', '([B)V'), [stringref, arrayref])
		return stringref
	end

	def new_object class_type
		class_initialized = @loader.is_loaded?(class_type)
		reference = Instance.new(@loader.load_class(class_type))
		if class_initialized == false
			clinit = JVMMethod.new(reference.class_file, '<clinit>', '()V')
			run Frame.new(clinit, []) if (clinit.attrib)
		end rescue
		initialize_fields reference, class_type
		return reference
	end

	def handle_exception frame, exception
		frame.pc -= 1
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
			if frame.pc >= e.start_pc and frame.pc < e.end_pc and
				(e.catch_type == 0 or
				is_type_equal_or_superclass?(exception.class_type,
					frame.class_file.get_attrib_name(e.catch_type)))
				return e
			end
		end
		return nil
	end

	def is_type_equal_or_superclass?(class_type_a, class_type_b)
		if class_type_a == class_type_b
			return true
		else
			class_file = @loader.load_class class_type_a
			if class_file.super_class.nonzero? and
				is_type_equal_or_superclass?(class_file.get_attrib_name(class_file.super_class), class_type_b)
				return true
			end
			return false
		end
	end

	def run frame
		if frame.code
			while frame.pc < frame.code.length
				begin
					opcode = frame.code[frame.pc]
					frame.pc += 1
					case opcode
					when 0
					when 1
						frame.stack.push nil
					when 2
						frame.stack.push -1
					when 3
						frame.stack.push 0
					when 4
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
						frame.stack.push frame.code[frame.pc]
						frame.pc += 1
					when 18
						index = frame.code[frame.pc]
						attrib = frame.class_file.constant_pool[index]
						if attrib.is_a? ConstantPoolConstantValueInfo
							frame.stack.push attrib.value
						elsif attrib.is_a? ConstantPoolConstantIndex1Info
							if attrib.is_string?
								frame.stack.push new_string(frame.class_file.constant_pool[attrib.index1].value)
							else
								frame.stack.push new_object 'java/lang/Class'
							end
						else
							fail 'Illegal attribute type'
						end
						frame.pc += 1
					when 26, 42
						frame.stack.push frame.locals[0]
					when 27, 43
						frame.stack.push frame.locals[1]
					when 28, 44
						frame.stack.push frame.locals[2]
					when 29, 45
						frame.stack.push frame.locals[3]
					when 50
						index = frame.stack.pop
						arrayref = frame.stack.pop
						frame.stack.push arrayref[index]
					when 59, 75
						frame.locals[0] = frame.stack.pop
					when 60, 76
						frame.locals[1] = frame.stack.pop
					when 61, 77
						frame.locals[2] = frame.stack.pop
					when 62, 78
						frame.locals[3] = frame.stack.pop
					when 83
						value = frame.stack.pop
						index = frame.stack.pop
						arrayref = frame.stack.pop
						arrayref[index] = value
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
					when 159
						if frame.stack.pop == frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 160
						if frame.stack.pop != frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 161
						if frame.stack.pop > frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 162
						if frame.stack.pop <= frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 163
						if frame.stack.pop < frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 164
						if frame.stack.pop >= frame.stack.pop
							frame.pc += BinaryParser.to_16bit_signed(frame.code[frame.pc],
								frame.code[frame.pc + 1]) - 1
						else
							frame.pc += 2
						end
					when 177
						break
					when 180
						field_index = BinaryParser.to_16bit_unsigned(frame.code[frame.pc],
							frame.code[frame.pc + 1])
						details = frame.class_file.class_and_name_and_type(field_index)
						reference = frame.stack.pop
						frame.stack.push reference.get_field(JVMField.new(@loader.load_class(details.class_type),
							details.field_name, details.field_type))
						frame.pc += 2
					when 181
						field_index = BinaryParser.to_16bit_unsigned(frame.code[frame.pc],
							frame.code[frame.pc + 1])
						details = frame.class_file.class_and_name_and_type(field_index)
						value = frame.stack.pop
						reference = frame.stack.pop
						reference.set_field(JVMField.new(@loader.load_class(details.class_type),
							details.field_name, details.field_type), value)
						frame.pc += 2
					when 182, 183, 184
						method_index = BinaryParser.to_16bit_unsigned(frame.code[frame.pc],
							frame.code[frame.pc + 1])
						details = frame.class_file.class_and_name_and_type(method_index)
						method = resolve_method(frame.class_file,
							@loader.load_class(details.class_type),
							details.field_name, details.field_type)
						params = []
						(method.args.size + 1).times { params.push frame.stack.pop }
						run Frame.new(method, params.reverse)
						frame.pc += 2
					when 187
						class_index = BinaryParser.to_16bit_unsigned(frame.code[frame.pc],
							frame.code[frame.pc + 1])
						frame.stack.push new_object(frame.class_file.get_attrib_name(class_index))
						frame.pc += 2
					when 188
						count = frame.stack.pop
						array_type = frame.code[frame.pc]
						frame.stack.push InstanceArray.new(array_type, count)
						frame.pc += 1
					when 190
						array_reference = frame.stack.pop
						frame.stack.push array_reference.values.size
					when 191
						raise JVMError, frame.stack.pop
					else
						fail "Unsupported opcode #{opcode}"
					end
				rescue JVMError => e
					handle_exception frame, e.exception
				rescue NoMethodError => e
					if e.receiver
						raise e
					else
						handle_exception frame, new_object('java/lang/NullPointerException')
					end
				end
			end
		end
	end
end
