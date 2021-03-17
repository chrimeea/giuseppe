class ConstantPoolConstant
	attr_reader :tag

	def initialize tag
		@tag = tag
	end
end

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

class ConstantPoolConstantIndex2Info < ConstantPoolConstantIndex1Info
	attr_reader :index2

	def initialize tag, index1, index2
		super tag, index1
		@index2 = index2
	end
end

class ConstantPoolConstantValueInfo < ConstantPoolConstant
	attr_reader :value

	def initialize tag, value
		super tag
		@value = value
	end
end

class ConstantPoolLoader
	def initialize parser
		@parser = parser
	end

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

	def load
		pool = [nil]
		constant_pool_count = @parser.load_u2 - 1
		tag = nil
		constant_pool_count.times do
			if [5, 6].include? tag
				pool << nil
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
				pool << v
			end
		end
		pool
	end
end