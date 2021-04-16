# frozen_string_literal: true

module Giuseppe
	# Holds information about a java field or method as found in the class file
	class ClassField
		attr_reader :access_flags, :name_index, :descriptor_index, :attributes

		def load parser, constant_pool
			@access_flags = AccessFlags.new parser.load_u2
			@name_index = parser.load_u2
			@descriptor_index = parser.load_u2
			@attributes = ClassAttribute.load_attribs(parser, constant_pool)
			self
		end

		def self.load_fields parser, constant_pool
			(1..(parser.load_u2)).map { ClassField.new.load(parser, constant_pool) }
		end
	end
end
