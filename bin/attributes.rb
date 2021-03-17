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

class AttributeLoader
	def initialize parser, class_file
		@parser = parser
		@class_file = class_file
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
		a.attributes = load
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
			t.inner_class_access_flags = @parser.load_u2
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

	def load_one_attribute
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
		a
	end

	def load
		attribs = []
		@parser.load_u2.times do
			attribs << load_one_attribute
		end
		attribs
	end
end
