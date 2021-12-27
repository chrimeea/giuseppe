# frozen_string_literal: true

module Giuseppe
	# Parses encoded bytecode from a class file
	class BinaryParser
		def initialize contents
			@i = 0
			@contents = contents
		end

		def load_u1
			u1 = @contents.byteslice(@i, 1).unpack1 'C'
			@i += 1
			u1
		end

		def load_u1_array length
			a = @contents.byteslice(@i, length).unpack 'C*'
			@i += length
			a
		end

		def load_u2
			u2 = @contents.byteslice(@i, 2).unpack1 'S>'
			@i += 2
			u2
		end

		def load_u2_array length
			a = @contents.byteslice(@i, 2 * length).unpack 'S>*'
			@i += 2 * length
			a
		end

		def load_u4
			u4 = @contents.byteslice(@i, 4).unpack1 'L>'
			@i += 4
			u4
		end

		def load_string length
			s = @contents.byteslice(@i, length).unpack1 'a*'
			@i += length
			s
		end

		def self.to_16bit_unsigned(byte1, byte2)
			(byte1 << 8) | byte2
		end

		def self.trunc_to(value, count)
			value.modulo 2**(8 * count)
		end

		def self.to_signed(value, count)
			n = 2**(8 * count)
			sign = value & (n / 2)
			value -= n if sign.nonzero?
			value
		end
	end
end
