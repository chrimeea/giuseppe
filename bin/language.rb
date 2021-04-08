# frozen_string_literal: true

module Giuseppe
	# A type descriptor
	class TypeDescriptor
		def initialize descriptor
			@descriptor = descriptor
		end

		def self.from_internal class_type
			class_type = "L#{class_type};" unless class_type.chr == '['
			TypeDescriptor.new class_type
		end

		def primitive?
			%w[B C D F I J S Z].include? @descriptor
		end

		def wide_primitive?
			%w[J D].include? @descriptor
		end

		def element_type
			TypeDescriptor.new @descriptor.delete('[')
		end

		def void?
			@descriptor == 'V'
		end

		def array?
			@descriptor.chr == '['
		end

		def dimensions
			@descriptor.count '['
		end

		def class_name
			if @descriptor[0] == 'L' then @descriptor[1..-2] else @descriptor end
		end

		def to_s
			@descriptor
		end

		def eql? other
			@descriptor.eql? other.descriptor
		end

		def hash
			@descriptor.hash
		end

			protected

		attr_reader :descriptor
	end

	# A method type descriptor containing arguments and return value
	class MethodDescriptor
		attr_reader :args, :retval

		def initialize descriptor
			@descriptor = descriptor
			parse_type_descriptors
		end

		def to_s
			@descriptor
		end

		def eql? other
			@descriptor.eql? other.descriptor
		end

		def hash
			@descriptor.hash
		end

			private

		def parse_type_descriptors
			pattern = @descriptor.match(/^\(([^)]*)\)(.+)$/)
			descriptors = pattern[1]
			i = 0
			@args = []
			a = ''
			while i < descriptors.size
				case descriptors[i]
				when 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z'
					@args << TypeDescriptor.new(a + descriptors[i])
					a = ''
				when 'L'
					j = descriptors.index(';', i)
					@args << TypeDescriptor.new(a + descriptors[i..j])
					i = j
					a = ''
				when '['
					j = i
					j += 1 while descriptors[j] == '['
					a += descriptors[i...j]
					i = j - 1
				end
				i += 1
			end
			@retval = TypeDescriptor.new(pattern[2])
		end

			protected

		attr_reader :descriptor
	end

	# An instance of a java object
	class JavaInstance
		attr_reader :jvmclass

		def initialize jvmclass = nil
			@jvmclass = jvmclass
			@fields = {}
		end

		def set_field field, value
			@fields[field_id(field)] = value
		end

		def get_field field
			@fields[field_id(field)]
		end

		def class_reference?
			@jvmclass.nil?
		end

			private

		def field_id field
			"#{field.jvmclass}.#{field.field_name}"
		end
	end

	# An instance of a java array
	class JavaInstanceArray < JavaInstance
		attr_reader :values

		def initialize jvmclass, counts
			fail unless jvmclass.descriptor.array?
			fail unless jvmclass.descriptor.dimensions == counts.size
			super jvmclass
			@values = [nil] * counts.pop
			counts.reverse.each do |c|
				@values = Array.new(c) { |i| @values[i] }
			end
		end
	end

	# The class of a java object, array or primitve type
	class JavaClass
		attr_reader :descriptor, :reference, :class_file, :fields, :methods

		def initialize reference, descriptor
			@descriptor = descriptor
			@reference = reference
			@fields = {}
			@methods = {}
			@interfaces = []
		end

		def class_file= value
			@class_file = value
			value.fields.each do |f|
				field = JavaField.new(
						self,
						@class_file.constant_pool[f.name_index].value,
						@class_file.constant_pool[f.descriptor_index].value
				)
				@fields[field] = f
			end
			value.methods.each do |m|
				method = JavaMethod.new(
						self,
						value.constant_pool[m.name_index].value,
						value.constant_pool[m.descriptor_index].value
				)
				@methods[method] = m
			end
			@interfaces = value.interfaces.map { |i| @class_file.constant_pool.get_attrib_value i }
		end

		def super_class
			return 'java/lang/Object' if descriptor.primitive? || descriptor.array?
			return if @class_file.super_class.zero?
			@class_file.constant_pool.get_attrib_value @class_file.super_class
		end

		def source_file
			a = @class_file.attributes[ClassAttributeSourceFile]
			return '' unless a
			@class_file.constant_pool[a.first.sourcefile_index].value
		end

		def hash
			@descriptor.hash
		end

		def eql? other
			@descriptor.eql? other.descriptor
		end

		def to_s
			@descriptor
		end
	end

	# An unresolved java field as name and type
	class JavaField
		attr_reader :field_name, :descriptor
		attr_accessor :jvmclass

		def initialize jvmclass, field_name, descriptor
			@jvmclass = jvmclass
			@field_name = field_name
			@descriptor = TypeDescriptor.new descriptor
		end

		def hash
			"#{@jvmclass}|#{@field_name}".hash
		end

		def eql? other
			@jvmclass.eql?(other.jvmclass) && @field_name.eql?(other.field_name)
		end

		def default_value
			return 0 if @descriptor.primitive?
		end

		def to_s
			@field_name
		end
	end

	# An unresolved java method as name and type
	class JavaMethod
		attr_reader :method_name, :descriptor
		attr_accessor :jvmclass

		def initialize jvmclass, method_name = nil, descriptor = nil
			@jvmclass = jvmclass
			@method_name = method_name
			@descriptor = MethodDescriptor.new(descriptor) if descriptor
		end

		def hash
			"#{@jvmclass}|#{@method_name}|#{@descriptor}".hash
		end

		def eql? other
			@jvmclass.eql?(other.jvmclass) &&
					@method_name.eql?(other.method_name) &&
					@descriptor.eql?(other.descriptor)
		end

		def to_s
			"#{@jvmclass} #{@method_name} #{@descriptor}"
		end
	end
end
