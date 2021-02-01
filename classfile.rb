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

class ClassField

	attr_accessor :access_flags, :name_index, :descriptor_index, :attributes

	def code
		i = attributes.index { |a| a.is_a? ClassAttributeCode }
		attributes[i] if i
	end
end

class ClassAttribute

	attr_accessor :attribute_name_index, :info
end

class ClassAttributeConstantValue < ClassAttribute

	attr_accessor :constantvalue_index
end

class ClassAttributeCode < ClassAttribute

	attr_accessor :max_stack, :max_locals, :code, :exception_table, :attributes

	class Table

		attr_accessor :start_pc, :end_pc, :handler_pc, :catch_type
	end

	def line_number_for_pc(pc)
		a = @attributes.find { |attrib| attrib.is_a? ClassAttributeLineNumber }
		l = 0
		a.line_number_table.each do |t|
			break if t.start_pc > pc
			l = t.line_number
		end
		l
	end
end

class ClassAttributeExceptions < ClassAttribute

	attr_accessor :exception_index_table
end

class ClassAttributeInnerClasses < ClassAttribute

	attr_accessor :classes

	class Table

		attr_accessor :inner_class_info_index, :outer_class_info_index, :inner_name_index, :inner_class_access_flags
	end
end

class ClassAttributeSyntetic < ClassAttribute
end

class ClassAttributeSourceFile < ClassAttribute

	attr_accessor :sourcefile_index
end

class ClassAttributeLineNumber < ClassAttribute

	attr_accessor :line_number_table

	class Table

		attr_accessor :start_pc, :line_number
	end
end

class ClassAttributeLocalVariableTable < ClassAttribute

	attr_accessor :local_variable_table

	class Table

		attr_accessor :start_pc, :length, :name_index, :descriptor_index, :index
	end
end

class ClassAttributeDeprecated < ClassAttribute
end

class ConstantPoolConstant

	attr_accessor :tag
end

class ConstantPoolConstantIndex1Info < ConstantPoolConstant

	attr_accessor :index1

	def string?
		@tag == 8
	end

	def class?
		@tag == 7
	end
end

class ConstantPoolConstantIndex2Info < ConstantPoolConstantIndex1Info

	attr_accessor :index2
end

class ConstantPoolConstantValueInfo < ConstantPoolConstant

	attr_accessor :value
end

class AccessFlags

	def initialize access_flags
		@access_flags = access_flags
	end

	def public?
		(@access_flags & 0x0001).nonzero?
	end

	def private?
		(@access_flags & 0x0002).nonzero?
	end

	def protected?
		(@access_flags & 0x0004).nonzero?
	end

	def static?
		(@access_flags & 0x0008).nonzero?
	end

	def final?
		(@access_flags & 0x0010).nonzero?
	end

	def synchronized?
		(@access_flags & 0x0020).nonzero?
	end

	def volatile?
		(@access_flags & 0x0040).nonzero?
	end

	def transient?
		(@access_flags & 0x0080).nonzero?
	end

	def native?
		(@access_flags & 0x0100).nonzero?
	end

	def interface?
		(@access_flags & 0x0200).nonzero?
	end

	def abstract?
		(@access_flags & 0x0400).nonzero?
	end

	def strict?
		(@access_flags & 0x0800).nonzero?
	end

	def inspect
		@access_flags.to_s(2)
	end

	alias super? synchronized?
end

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

	def this_class_type
		get_attrib_name(@this_class)
	end

	def source_file
		a = @attributes.find { |a| a.is_a? ClassAttributeSourceFile }
		@constant_pool[a.sourcefile_index].value if a
	end

	def get_method method_name, method_type
		@methods.each do |m|
			if	@constant_pool[m.name_index].value == method_name &&
				@constant_pool[m.descriptor_index].value == method_type
				return m
			end
		end
		fail "Unknown method #{method_name}"
	end

	def get_field field_name, field_type
		@fields.each do |f|
			if	@constant_pool[f.name_index].value == field_name &&
				@constant_pool[f.descriptor_index].value == field_type
				return f
			end
		end
		fail "Unknown field #{field_name}"
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
