# frozen_string_literal: true

require 'forwardable'

module Giuseppe
	# Holds information about a java field or method as found in the class file
	class ClassField
		attr_reader :access_flags, :name, :descriptor, :attributes

		def load parser, constant_pool
			@access_flags = AccessFlags.new parser.load_u2
			@name = constant_pool[parser.load_u2]&.value
			@descriptor = constant_pool[parser.load_u2]&.value
			@attributes = ClassAttributeList.new.load(parser, constant_pool)
			self
		end
	end

	# A list of java fields or methods
	class ClassFieldList
		extend Forwardable

		def_delegators :@fields, :each, :map, :[]

		def initialize
			@fields = []
		end

		def load parser, constant_pool
			@fields = (1..(parser.load_u2)).map { ClassField.new.load(parser, constant_pool) }
			self
		end
	end

	# A list of interface name references in the constant pool
	class InterfaceList
		extend Forwardable

		def_delegators :@interfaces, :each, :map, :[]

		def initialize
			@interfaces = []
		end

		def load parser, constant_pool
			@interfaces = parser.load_u2_array(parser.load_u2).map { |i| constant_pool.get_attrib_value i }
			self
		end
	end
end
