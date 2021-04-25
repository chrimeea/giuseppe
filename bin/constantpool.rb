# frozen_string_literal: true

require 'forwardable'

module Giuseppe
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

		def initialize tag, index1 = nil
			super tag
			@index1 = index1
		end

		def string?
			@tag == 8
		end

		def class?
			@tag == 7
		end

		def load parser
			@index1 = parser.load_u2
			self
		end
	end

	# Constant with two index fields
	class ConstantPoolConstantIndex2Info < ConstantPoolConstantIndex1Info
		attr_reader :index2

		def initialize tag, index1 = nil, index2 = nil
			super tag, index1
			@index2 = index2
		end

		def field?
			@tag == 9
		end

		def method?
			@tag == 10
		end

		def interface?
			@tag == 11
		end

		def load parser
			@index1 = parser.load_u2
			@index2 = parser.load_u2
			self
		end
	end

	# Value constant
	class ConstantPoolConstantValueInfo < ConstantPoolConstant
		attr_reader :value

		def initialize tag, value = nil
			super tag
			@value = value
		end

		def load parser
			case @tag
			when 1
				@value = read_constant_utf8 parser
			when 3
				@value = read_constant_int parser
			when 4
				@value = read_constant_float parser
			when 5
				@value = read_constant_long parser
			when 6
				@value = read_constant_double parser
			end
			self
		end

		def read_constant_utf8 parser
			parser.load_string(parser.load_u2)
		end

		def read_constant_int parser
			BinaryParser.to_signed(parser.load_u4, 4)
		end

		def read_constant_float parser
			value = parser.load_u4
			s = if (value >> 31).zero? then 1 else -1 end
			e = (value >> 23) & 0xff
			m = if e.zero? then (value & 0x7fffff) << 1 else (value & 0x7fffff) | 0x800000 end
			(s * m * 2**(e - 150)).to_f
		end

		def read_constant_long parser
			high_bytes = parser.load_u4
			low_bytes = parser.load_u4
			value = (high_bytes << 32) + low_bytes
			BinaryParser.to_signed(value, 8)
		end

		def read_constant_double parser
			high_bytes = parser.load_u4
			low_bytes = parser.load_u4
			value = (high_bytes << 32) + low_bytes
			s = if (value >> 63).zero? then 1 else -1 end
			e = (value >> 52) & 0x7ff
			m = if e.zero? then (value & 0xfffffffffffff) << 1 else (value & 0xfffffffffffff) | 0x10000000000000 end
			(s * m * 2**(e - 1075)).to_f
		end
	end

	# Holds all the class file constant literals
	class ConstantPool
		extend Forwardable

		def_delegators :@pool, :[], :<<

		def initialize
			@pool = [nil]
		end

		def get_attrib_value index
			if index.zero? then nil else @pool[@pool[index].index1].value end
		end

		def class_and_name_and_type index
			attrib = @pool[index]
			class_type = get_attrib_value(attrib.index1)
			attrib = @pool[attrib.index2]
			field_name = @pool[attrib.index1]&.value
			field_type = @pool[attrib.index2]&.value
			Struct.new(:class_type, :field_name, :field_type).new(class_type, field_name, field_type)
		end

		def load parser
			constant_pool_count = parser.load_u2 - 1
			tag = nil
			constant_pool_count.times do
				if [5, 6].include? tag
					@pool << nil
					tag = nil
				else
					tag = parser.load_u1
					case tag
					when 1, 3, 4, 5, 6
						v = ConstantPoolConstantValueInfo.new(tag).load(parser)
					when 7, 8
						v = ConstantPoolConstantIndex1Info.new(tag).load(parser)
					when 9, 10, 11, 12
						v = ConstantPoolConstantIndex2Info.new(tag).load(parser)
					else
						$logger.warn('constantpool.rb') { "unknown constant type #{tag}" }
					end
					@pool << v
				end
			end
			self
		end
	end
end
