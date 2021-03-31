# frozen_string_literal: true

# Base class for constants in the constant pool
class ConstantPoolConstant
	attr_reader :tag

	def initialize tag
		@tag = tag
	end
end

# Constant with one index field
class ConstantPoolConstantIndex1Info < ConstantPoolConstant
	attr_reader :index1

	def initialize tag, index1
		super tag
		@index1 = index1
	end

	def string?
		@tag == 8
	end

	def class?
		@tag == 7
	end
end

# Constant with two index fields
class ConstantPoolConstantIndex2Info < ConstantPoolConstantIndex1Info
	attr_reader :index2

	def initialize tag, index1, index2
		super tag, index1
		@index2 = index2
	end
end

# Value constant
class ConstantPoolConstantValueInfo < ConstantPoolConstant
	attr_reader :value

	def initialize tag, value
		super tag
		@value = value
	end
end

class ConstantPool
	def initialize
		@pool = [nil]
	end

	def [] index
		@pool[index]
	end

	def << value
		@pool << value
	end

	def get_attrib_value index
		@pool[@pool[index].index1].value
	end

	def class_and_name_and_type index
		attrib = @pool[index]
		class_type = get_attrib_value(attrib.index1)
		attrib = @pool[attrib.index2]
		field_name = @pool[attrib.index1].value
		field_type = @pool[attrib.index2].value
		Struct.new(:class_type, :field_name, :field_type).new(class_type, field_name, field_type)
	end
end

# Parses the constant pool from a class file
class ConstantPoolLoader
	def initialize parser
		@parser = parser
		@pool = ConstantPool.new
	end

	def load
		constant_pool_count = @parser.load_u2 - 1
		tag = nil
		constant_pool_count.times do
			if [5, 6].include? tag
				@pool << nil
				tag = nil
			else
				tag = @parser.load_u1
				case tag
				when 1
					v = read_constant_utf8 tag
				when 3, 4
					v = read_constant_int_or_float tag
				when 5, 6
					v = read_constant_long_or_double tag
				when 7, 8
					v = read_constant_string tag
				when 9, 10, 11, 12
					v = read_constant_name_and_type tag
				end
				@pool << v
			end
		end
		@pool
	end

		private

	def read_constant_utf8 tag
		ConstantPoolConstantValueInfo.new tag, @parser.load_string(@parser.load_u2)
	end

	def read_constant_int_or_float tag
		value = @parser.load_u4
		if tag == 4
			s = if (value >> 31).zero? then 1 else -1 end
			e = (value >> 23) & 0xff
			m = if e.zero? then (value & 0x7fffff) << 1 else (value & 0x7fffff) | 0x800000 end
			value = (s * m * 2**(e - 150)).to_f
		else
			value = BinaryParser.to_signed(value, 4)
		end
		ConstantPoolConstantValueInfo.new tag, value
	end

	def read_constant_long_or_double tag
		high_bytes = @parser.load_u4
		low_bytes = @parser.load_u4
		value = (high_bytes << 32) + low_bytes
		if tag == 6
			s = if (value >> 63).zero? then 1 else -1 end
			e = (value >> 52) & 0x7ff
			m = if e.zero? then (value & 0xfffffffffffff) << 1 else (value & 0xfffffffffffff) | 0x10000000000000 end
			value = (s * m * 2**(e - 1075)).to_f
		else
			value = BinaryParser.to_signed(value, 8)
		end
		ConstantPoolConstantValueInfo.new tag, value
	end

	def read_constant_string tag
		ConstantPoolConstantIndex1Info.new tag, @parser.load_u2
	end

	def read_constant_name_and_type tag
		ConstantPoolConstantIndex2Info.new tag, @parser.load_u2, @parser.load_u2
	end
end
