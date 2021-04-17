# frozen_string_literal: true

require 'forwardable'

module Giuseppe
	# A list of attributes indexed by class
	class ClassAttributeList
		extend Forwardable

		def_delegators :@attribs, :each, :[]

		def initialize
			@attribs = {}
		end

		def load parser, constant_pool
			parser.load_u2.times do
				a = load_attrib(parser, constant_pool)
				if @attribs.key? a.class
					@attribs[a.class] << a
				else
					@attribs[a.class] = [a]
				end
			end
			self
		end

			private

		def load_attrib parser, constant_pool
			attribute_name_index = parser.load_u2
			attribute_length = parser.load_u4
			attribute_type = constant_pool[attribute_name_index].value
			case attribute_type
			when 'ConstantValue'
				a = ClassAttributeConstantValue.new.load(parser)
			when 'Code'
				a = ClassAttributeCode.new.load(parser, constant_pool)
			when 'Exceptions'
				a = ClassAttributeExceptions.new.load(parser)
			when 'InnerClasses'
				a = ClassAttributeInnerClasses.new.load(parser)
			when 'Synthetic'
				a = ClassAttributeSyntetic.new
			when 'SourceFile'
				a = ClassAttributeSourceFile.new.load(parser)
			when 'LineNumberTable'
				a = ClassAttributeLineNumber.new.load(parser)
			when 'LocalVariableTable'
				a = ClassAttributeLocalVariableTable.new.load(parser)
			when 'Deprecated'
				a = ClassAttributeDeprecated.new
			else
				$logger.warn('attributes.rb') { "unknown attribute #{attribute_type}" }
				a = ClassAttribute.new
				a.info = parser.load_u1_array(attribute_length)
			end
			a.attribute_name_index = attribute_name_index
			a
		end
	end

	# Base class for all attributes
	class ClassAttribute
		attr_accessor :attribute_name_index, :info
	end

	# Constant value attribute
	class ClassAttributeConstantValue < ClassAttribute
		attr_accessor :constantvalue_index

		def load parser
			@constantvalue_index = parser.load_u2
			self
		end
	end

	# Code attribute
	class ClassAttributeCode < ClassAttribute
		attr_accessor :max_stack, :max_locals, :code, :exception_table, :attributes

		class Table
			attr_accessor :start_pc, :end_pc, :handler_pc, :catch_type
		end

		def line_number_for pc
			a = @attributes[ClassAttributeLineNumber]&.first
			return 0 unless a
			i = a.line_number_table.index { |t| t.start_pc > pc } || 0
			a.line_number_table[i - 1].line_number
		end

		def exception_handlers_for pc
			@exception_table.select { |e| pc >= e.start_pc && pc < e.end_pc }
		end

		def load parser, constant_pool
			@max_stack = parser.load_u2
			@max_locals = parser.load_u2
			@code = parser.load_u1_array(parser.load_u4)
			@exception_table = []
			parser.load_u2.times do
				t = ClassAttributeCode::Table.new
				t.start_pc = parser.load_u2
				t.end_pc = parser.load_u2
				t.handler_pc = parser.load_u2
				t.catch_type = parser.load_u2
				@exception_table << t
			end
			@attributes = ClassAttributeList.new.load(parser, constant_pool)
			self
		end
	end

	# Exceptions attribute
	class ClassAttributeExceptions < ClassAttribute
		attr_accessor :exception_index_table

		def load parser
			@exception_index_table = parser.load_u2_array(parser.load_u2)
			self
		end
	end

	# Inner classes attribute
	class ClassAttributeInnerClasses < ClassAttribute
		attr_accessor :classes

		class Table
			attr_accessor :inner_class_info_index, :outer_class_info_index, :inner_name_index, :inner_class_access_flags
		end

		def load parser
			@classes = []
			parser.load_u2.times do
				t = ClassAttributeInnerClasses::Table.new
				t.inner_class_info_index = parser.load_u2
				t.outer_class_info_index = parser.load_u2
				t.inner_name_index = parser.load_u2
				t.inner_class_access_flags = AccessFlags.new parser.load_u2
				@classes << t
			end
			self
		end
	end

	# Syntetic attribute
	class ClassAttributeSyntetic < ClassAttribute
	end

	# Source file attribute
	class ClassAttributeSourceFile < ClassAttribute
		attr_accessor :sourcefile_index

		def load parser
			@sourcefile_index = parser.load_u2
			self
		end
	end

	# Line number attribute
	class ClassAttributeLineNumber < ClassAttribute
		attr_accessor :line_number_table

		class Table
			attr_accessor :start_pc, :line_number
		end

		def load parser
			@line_number_table = []
			parser.load_u2.times do
				t = ClassAttributeLineNumber::Table.new
				t.start_pc = parser.load_u2
				t.line_number = parser.load_u2
				@line_number_table << t
			end
			self
		end
	end

	# Local variable table attribute
	class ClassAttributeLocalVariableTable < ClassAttribute
		attr_accessor :local_variable_table

		class Table
			attr_accessor :start_pc, :length, :name_index, :descriptor_index, :index
		end

		def load parser
			@local_variable_table = []
			parser.load_u2.times do
				t = ClassAttributeLocalVariableTable::Table
				t.start_pc = parser.load_u2
				t.length = parser.load_u2
				t.name_index = parser.load_u2
				t.descriptor_index = parser.load_u2
				t.index = parser.load_u2
				@local_variable_table << t
			end
			self
		end
	end

	# Deprecated attribute
	class ClassAttributeDeprecated < ClassAttribute
	end
end
