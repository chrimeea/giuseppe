class ClassField
	attr_accessor :access_flags, :name_index, :descriptor_index, :attributes

	def code
		i = attributes.index { |a| a.is_a? ClassAttributeCode }
		attributes[i] if i
	end
end

class FieldLoader
	def initialize parser, attribute_loader
		@parser = parser
		@attribute_loader = attribute_loader
	end

	def load
		f = []
		@parser.load_u2.times do
			c = ClassField.new
			c.access_flags = AccessFlags.new(@parser.load_u2)
			c.name_index = @parser.load_u2
			c.descriptor_index = @parser.load_u2
			c.attributes = @attribute_loader.load
			f << c
		end
		f
	end
end