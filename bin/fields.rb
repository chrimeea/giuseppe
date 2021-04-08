# frozen_string_literal: true

module Giuseppe
	# Holds information about a java field or method as found in the class file
	class ClassField
		attr_accessor :access_flags, :name_index, :descriptor_index, :attributes
	end

	# Parses java fields and methods from a class file
	class FieldLoader
		def initialize parser, attribute_loader
			@parser = parser
			@attribute_loader = attribute_loader
		end

		def load
			f = []
			@parser.load_u2.times do
				c = ClassField.new
				c.access_flags = AccessFlags.new @parser.load_u2
				c.name_index = @parser.load_u2
				c.descriptor_index = @parser.load_u2
				c.attributes = @attribute_loader.load
				f << c
			end
			f
		end
	end
end
