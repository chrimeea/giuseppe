require './classfile'

class ClassLoader

	def initialize
		@classes = {}
	end

	def load_constant_pool
		constant_pool_count = @parser.load_u2 - 1
		constant_pool_count.times do
			tag = @parser.load_u1
			case tag
			when 1
				v = ConstantPoolConstantValueInfo.new
				v.value = @parser.load_string(@parser.load_u2)
			when 3, 4
				v = ConstantPoolConstantValueInfo.new
				v.value = @parser.load_u4
				if (tag == 4)
					s = if (v.value >> 31) == 0 then 1 else -1 end
    				e = (v.value >> 23) & 0xff;
					m = if e == 0 then (v.value & 0x7fffff) << 1 else (v.value & 0x7fffff) | 0x800000 end
					v.value = s * m * 2 ^ (e - 150)
				end
			when 5, 6
				v = ConstantPoolConstantValueInfo.new
				high_bytes = @parser.load_u4
				low_bytes = @parser.load_u4
				v.value = (high_bytes << 32) + low_bytes
				if (tag == 6)
					s = if (v.value >> 63) == 0 then 1 else -1 end
					e = (v.value >> 52) & 0x7ff
					m = if e == 0 then (v.value & 0xfffffffffffff) << 1 else (v.value & 0xfffffffffffff) | 0x10000000000000 end
					v.value = s * m * 2 ^ (e - 1075)
				end
			when 7
				v = ConstantPoolConstantIndex1Info.new
				v.index1 = @parser.load_u2
			when 8
				v = ConstantPoolConstantIndex1Info.new
				v.index1 = @parser.load_u2
			when 9, 10, 11
				v = ConstantPoolConstantIndex2Info.new
				v.index1 = @parser.load_u2
				v.index2 = @parser.load_u2
			when 12
				v = ConstantPoolConstantIndex2Info.new
				v.index1 = @parser.load_u2
				v.index2 = @parser.load_u2
			end
			v.tag = tag
			@class_file.constant_pool << v
		end
	end

	def load_interfaces
		return @parser.load_u2_array(@parser.load_u2)
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
		return f
	end

	def load_attributes
		attribs = []
		@parser.load_u2.times do
			attribute_name_index = @parser.load_u2
			attribute_length = @parser.load_u4
			attribute_type = @class_file.constant_pool[attribute_name_index].value
			case attribute_type
			when 'ConstantValue'
				a = ClassAttributeConstantValue.new
				a.constantvalue_index = @parser.load_u2
			when 'Code'
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
			when 'Exceptions'
				a = ClassAttributeExceptions.new
				a.exception_index_table = @parser.load_u2_array(@parser.load_u2)
			when 'InnerClasses'
				a = ClassAttributeInnerClasses.new
				a.classes = []
				@parser.load_u2.times do
					t = ClassAttributeInnerClasses::Table
					t.inner_class_info_index = @parser.load_u2
					t.outer_class_info_index = @parser.load_u2
					t.inner_name_index = @parser.load_u2
					t.inner_class_access_flags = AccessFlags.new(@parser.load_u2)
					a.classes << t
				end
			when 'Synthetic'
				a = ClassAttributeSyntetic.new
			when 'SourceFile'
				a = ClassAttributeSourceFile.new
				a.sourcefile_index = @parser.load_u2
			when 'LineNumberTable'
				a = ClassAttributeLineNumber.new
				a.line_number_table = []
				@parser.load_u2.times do
					t = ClassAttributeLineNumber::Table.new
					t.start_pc = @parser.load_u2
					t.line_number = @parser.load_u2
					a.line_number_table << t
				end
			when 'LocalVariableTable'
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
			when 'Deprecated'
				a = ClassAttributeDeprecated.new
			else
				puts "Warning: unknown attribute #{attribute_type}"
				a = ClassAttribute.new
				a.info = @parser.load_u1_array(attribute_length)
			end
			a.attribute_name_index = attribute_name_index
			attribs << a
		end
		return attribs
	end

	def load_file name
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
		@classes[@class_file.this_class_type] = @class_file
		return @class_file
	end

	def class_path class_type
		class_type + '.class'
	end

	def is_loaded? class_type
		@classes.has_key? class_type
	end

	def load_class class_type
		if is_loaded? class_type
			return @classes[class_type]
		else
			return load_file(class_path(class_type))
		end
	end
end
