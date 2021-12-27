# frozen_string_literal: true

require 'forwardable'

module Giuseppe
	# A list of attributes indexed by class
	class ClassAttributeList
		extend Forwardable

		def_delegators :@attribs, :each, :map, :[], :key?

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
			attribute_name = constant_pool[parser.load_u2]&.value
			attribute_length = parser.load_u4
			case attribute_name
			when 'ConstantValue'
				a = ClassAttributeConstantValue.new.load(parser, constant_pool)
			when 'Code'
				a = ClassAttributeCode.new.load(parser, constant_pool)
			when 'Exceptions'
				a = ClassAttributeExceptions.new.load(parser, constant_pool)
			when 'InnerClasses'
				a = ClassAttributeInnerClasses.new.load(parser, constant_pool)
			when 'Synthetic'
				a = ClassAttributeSyntetic.new
			when 'SourceFile'
				a = ClassAttributeSourceFile.new.load(parser, constant_pool)
			when 'LineNumberTable'
				a = ClassAttributeLineNumber.new.load(parser)
			when 'LocalVariableTable'
				a = ClassAttributeLocalVariableTable.new.load(parser, constant_pool)
			when 'Deprecated'
				a = ClassAttributeDeprecated.new
			else
				$logger.warn('attributes.rb') { "unknown attribute #{attribute_name}" }
				a = ClassAttribute.new
				a.info = parser.load_u1_array(attribute_length)
			end
			a.attribute_name = attribute_name
			a
		end
	end

	# Base class for all attributes
	class ClassAttribute
		attr_accessor :attribute_name, :info
	end

	# Constant value attribute
	class ClassAttributeConstantValue < ClassAttribute
		attr_accessor :constantvalue

		def load parser, constant_pool
			@constantvalue = constant_pool[parser.load_u2]&.value
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
				t.catch_type = constant_pool.get_attrib_value(parser.load_u2)
				@exception_table << t
			end
			@attributes = ClassAttributeList.new.load(parser, constant_pool)
			self
		end
	end

	# Exceptions attribute
	class ClassAttributeExceptions < ClassAttribute
		attr_accessor :exception_table

		def load parser, constant_pool
			@exception_table = parser.load_u2_array(parser.load_u2).map { |i| constant_pool.get_attrib_value(i) }
			self
		end
	end

	# Inner classes attribute
	class ClassAttributeInnerClasses < ClassAttribute
		attr_accessor :classes

		class Table
			attr_accessor :inner_class_info, :outer_class_info, :inner_name, :inner_class_access_flags
		end

		def load parser, constant_pool
			@classes = []
			parser.load_u2.times do
				t = ClassAttributeInnerClasses::Table.new
				t.inner_class_info = constant_pool.get_attrib_value(parser.load_u2)
				t.outer_class_info = constant_pool.get_attrib_value(parser.load_u2)
				t.inner_name = constant_pool[parser.load_u2]&.value
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
		attr_accessor :sourcefile

		def load parser, constant_pool
			@sourcefile = constant_pool[parser.load_u2]&.value
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
			attr_accessor :start_pc, :length, :name, :descriptor, :index
		end

		def load parser, constant_pool
			@local_variable_table = []
			parser.load_u2.times do
				t = ClassAttributeLocalVariableTable::Table
				t.start_pc = parser.load_u2
				t.length = parser.load_u2
				t.name = constant_pool[parser.load_u2]&.value
				t.descriptor = constant_pool[parser.load_u2]&.value
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
