# frozen_string_literal: true

require_relative 'parser'
require_relative 'constantpool'
require_relative 'attributes'
require_relative 'fields'

class ClassFile
	attr_accessor	:constant_pool, :interfaces, :attributes,
					:fields, :methods, :magic, :minor_version, :major_version,
					:this_class, :super_class, :access_flags

	def initialize
		@constant_pool = [nil]
		@interfaces = []
		@attributes = []
		@fields = []
		@methods = []
	end

	def get_attrib_name index
		@constant_pool[@constant_pool[index].index1].value
	end

	def class_and_name_and_type index
		attrib = @constant_pool[index]
		class_type = get_attrib_name(attrib.index1)
		attrib = @constant_pool[attrib.index2]
		field_name = @constant_pool[attrib.index1].value
		field_type = @constant_pool[attrib.index2].value
		Struct.new(:class_type, :field_name, :field_type).new(class_type, field_name, field_type)
	end
end

class ClassLoader
	def initialize class_type
		@name = class_path class_type
		@class_file = ClassFile.new
		@parser = BinaryParser.new IO.binread(@name)
		@attribute_loader = AttributeLoader.new(@parser, @class_file)
		@field_loader = FieldLoader.new(@parser, @attribute_loader)
		@pool_loader = ConstantPoolLoader.new(@parser)
	end

	def load_interfaces
		@parser.load_u2_array(@parser.load_u2)
	end

	def load
		$logger.info "Loading #{@name}"
		@class_file.magic = @parser.load_u4
		@class_file.minor_version = @parser.load_u2
		@class_file.major_version = @parser.load_u2
		@class_file.constant_pool = @pool_loader.load
		@class_file.access_flags = @parser.load_u2
		@class_file.this_class = @parser.load_u2
		@class_file.super_class = @parser.load_u2
		@class_file.interfaces = load_interfaces
		@class_file.fields = @field_loader.load
		@class_file.methods = @field_loader.load
		@class_file.attributes = @attribute_loader.load
		@class_file
	end

	def class_path class_type
		"#{class_type}.class"
	end
end
