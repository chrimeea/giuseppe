# frozen_string_literal: true

module Giuseppe
	# Holds information about a java field or method as found in the class file
	class ClassField
		attr_accessor :access_flags, :name_index, :descriptor_index, :attributes
	end

	# Parses java fields and methods from a class file
	class FieldLoader
		def initialize parser, constant_pool
			@parser = parser
			@constant_pool = constant_pool
		end

		def load
			f = []
			@parser.load_u2.times do
				c = ClassField.new
				c.access_flags = AccessFlags.new @parser.load_u2
				c.name_index = @parser.load_u2
				c.descriptor_index = @parser.load_u2
				c.attributes = AttributeLoader.new(@parser, @constant_pool).load
				f << c
			end
			f
		end
	end
end
