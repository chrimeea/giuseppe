# frozen_string_literal: true

require_relative 'classfile'

class ClassLoader
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

	def load_constant_pool
		constant_pool_count = @parser.load_u2 - 1
		tag = nil
		constant_pool_count.times do
			if [5, 6].include? tag
				@class_file.constant_pool << nil
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
				@class_file.constant_pool << v
			end
		end
	end

	def load_interfaces
		@parser.load_u2_array(@parser.load_u2)
	end

	def load_fields
		f = []
		@parser.load_u2.times do
			c = ClassField.new
			c.access_flags = AccessFlags.new(@parser.load_u2)
			c.name_index = @parser.load_u2
			c.descriptor_index = @parser.load_u2
			c.attributes = load_attributes
			f << c
		end
		f
	end

	def read_constantvalue_attribute
		a = ClassAttributeConstantValue.new
		a.constantvalue_index = @parser.load_u2
		a
	end

	def read_code_attribute
		a = ClassAttributeCode.new
		a.max_stack = @parser.load_u2
		a.max_locals = @parser.load_u2
		a.code = @parser.load_u1_array(@parser.load_u4)
		a.exception_table = []
		@parser.load_u2.times do
			t = ClassAttributeCode::Table.new
			t.start_pc = @parser.load_u2
			t.end_pc = @parser.load_u2
			t.handler_pc = @parser.load_u2
			t.catch_type = @parser.load_u2
			a.exception_table << t
		end
		a.attributes = load_attributes
		a
	end

	def read_exceptions_attribute
		a = ClassAttributeExceptions.new
		a.exception_index_table = @parser.load_u2_array(@parser.load_u2)
		a
	end

	def read_innerclasses_attribute
		a = ClassAttributeInnerClasses.new
		a.classes = []
		@parser.load_u2.times do
			t = ClassAttributeInnerClasses::Table.new
			t.inner_class_info_index = @parser.load_u2
			t.outer_class_info_index = @parser.load_u2
			t.inner_name_index = @parser.load_u2
			t.inner_class_access_flags = AccessFlags.new(@parser.load_u2)
			a.classes << t
		end
		a
	end

	def read_sourcefile_attribute
		a = ClassAttributeSourceFile.new
		a.sourcefile_index = @parser.load_u2
		a
	end

	def read_linenumber_attribute
		a = ClassAttributeLineNumber.new
		a.line_number_table = []
		@parser.load_u2.times do
			t = ClassAttributeLineNumber::Table.new
			t.start_pc = @parser.load_u2
			t.line_number = @parser.load_u2
			a.line_number_table << t
		end
		a
	end

	def read_localvariabletable_attribute
		a = ClassAttributeLocalVariableTable.new
		a.local_variable_table = []
		@parser.load_u2.times do
			t = ClassAttributeLocalVariableTable::Table
			t.start_pc = @parser.load_u2
			t.length = @parser.load_u2
			t.name_index = @parser.load_u2
			t.descriptor_index = @parser.load_u2
			t.index = @parser.load_u2
			a.local_variable_table << t
		end
		a
	end

	def load_attributes
		attribs = []
		@parser.load_u2.times do
			attribute_name_index = @parser.load_u2
			attribute_length = @parser.load_u4
			attribute_type = @class_file.constant_pool[attribute_name_index].value
			case attribute_type
			when 'ConstantValue'
				a = read_constantvalue_attribute
			when 'Code'
				a = read_code_attribute
			when 'Exceptions'
				a = read_exceptions_attribute
			when 'InnerClasses'
				a = read_innerclasses_attribute
			when 'Synthetic'
				a = ClassAttributeSyntetic.new
			when 'SourceFile'
				a = read_sourcefile_attribute
			when 'LineNumberTable'
				a = read_linenumber_attribute
			when 'LocalVariableTable'
				a = read_localvariabletable_attribute
			when 'Deprecated'
				a = ClassAttributeDeprecated.new
			else
				$logger.warn('classloader.rb') { "unknown attribute #{attribute_type}" }
				a = ClassAttribute.new
				a.info = @parser.load_u1_array(attribute_length)
			end
			a.attribute_name_index = attribute_name_index
			attribs << a
		end
		attribs
	end

	def load_file name
		$logger.info "Loading #{name}"
		@class_file = ClassFile.new
		@parser = BinaryParser.new IO.binread(name)
		@class_file.magic = @parser.load_u4
		@class_file.minor_version = @parser.load_u2
		@class_file.major_version = @parser.load_u2
		load_constant_pool
		@class_file.access_flags = AccessFlags.new(@parser.load_u2)
		@class_file.this_class = @parser.load_u2
		@class_file.super_class = @parser.load_u2
		@class_file.interfaces = load_interfaces
		@class_file.fields = load_fields
		@class_file.methods = load_fields
		@class_file.attributes = load_attributes
		@class_file
	end

	def class_path class_type
		"#{class_type}.class"
	end
end
