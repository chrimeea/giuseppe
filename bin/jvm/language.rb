# frozen_string_literal: true

module Giuseppe
	# A type descriptor
	class TypeDescriptor
		def initialize descriptor
			raise TypeError unless descriptor.is_a? String
			@descriptor = descriptor
		end

		def self.from_internal class_name
			raise TypeError unless class_name.is_a? String
			class_name = "L#{class_name};" unless class_name.chr == '['
			TypeDescriptor.new class_name
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
			raise TypeError unless descriptor.is_a? String
			@descriptor = descriptor
			parse_type_descriptors
		end

		def to_s
			@descriptor
		end

		def eql? other
			raise TypeError unless other.is_a? MethodDescriptor
			@descriptor.eql? other.descriptor
		end

		def hash
			@descriptor.hash
		end

			private

		def parse_type_descriptors
			pattern = @descriptor.match(/^\(([^)]*)\)(.+)$/)
			@args = pattern[1].scan(/\[*(?:B|C|D|F|I|J|S|Z|(?:L[^;]+;))/).map { |t| TypeDescriptor.new(t) }
			@retval = TypeDescriptor.new(pattern[2])
		end

			protected

		attr_reader :descriptor
	end

	# An instance of a java object
	class JavaInstance
		attr_reader :jvmclass

		def initialize jvmclass = nil
			raise TypeError unless jvmclass.is_a?(JavaClassInstance) || jvmclass.nil?
			@jvmclass = jvmclass
			@fields = {}
		end

		def set_field field, value
			raise TypeError unless field.is_a? JavaFieldHandle
			@fields[field_id(field)] = value
		end

		def get_field field
			raise TypeError unless field.is_a? JavaFieldHandle
			@fields[field_id(field)]
		end

			private

		def field_id field
			raise TypeError unless field.is_a? JavaFieldHandle
			"#{field.jvmclass}.#{field.name}"
		end
	end

	# An instance of a java array
	class JavaArrayInstance < JavaInstance
		attr_reader :values

		def initialize jvmclass, counts
			raise TypeError unless jvmclass.is_a? JavaClassInstance
			raise TypeError unless counts.is_a? Array
			fail unless jvmclass.descriptor.array?
			fail unless jvmclass.descriptor.dimensions == counts.size
			super jvmclass
			@values = [nil] * counts.pop
			counts.reverse.each do |c|
				@values = Array.new(c) { |i| @values[i] }
			end
		end
	end

	# The instance of the class of a java object, array or primitive type
	class JavaClassInstance
		attr_reader :descriptor, :reference, :class_file, :fields, :methods

		def initialize reference, descriptor
			raise TypeError unless reference.is_a? JavaInstance
			raise TypeError unless descriptor.is_a? TypeDescriptor
			@descriptor = descriptor
			@reference = reference
			@fields = {}
			@methods = {}
		end

		def class_file= value
			raise TypeError unless value.is_a? ClassFile
			@class_file = value
			value.fields.each { |f| @fields[JavaFieldHandle.new(self, f.name, f.descriptor)] = f }
			value.methods.each { |m| @methods[JavaMethodHandle.new(self, m.name, m.descriptor)] = m }
		end

		def super_class
			return 'java/lang/Object' if @descriptor.primitive? || @descriptor.array?
			@class_file.super_class
		end

		def source_file
			return '' unless @class_file.attributes.key? ClassAttributeSourceFile
			@class_file.attributes[ClassAttributeSourceFile].first.sourcefile
		end

		def hash
			@descriptor.hash
		end

		def eql? other
			raise TypeError unless other.is_a? JavaClassInstance
			@descriptor.eql? other.descriptor
		end

		def to_s
			@descriptor.to_s
		end
	end

	# An unresolved java field as name and type
	class JavaFieldHandle
		attr_reader :name, :descriptor
		attr_accessor :jvmclass

		def initialize jvmclass, name, descriptor
			raise TypeError unless jvmclass.is_a? JavaClassInstance
			raise TypeError unless name.is_a? String
			raise TypeError unless descriptor.is_a? String
			@jvmclass = jvmclass
			@name = name
			@descriptor = TypeDescriptor.new descriptor
		end

		def declared?
			@jvmclass.fields.key? self
		end

		def hash
			"#{@jvmclass}|#{@name}".hash
		end

		def eql? other
			raise TypeError unless other.is_a? JavaFieldHandle
			@jvmclass.eql?(other.jvmclass) && @name.eql?(other.name)
		end

		def default_value
			return 0 if @descriptor.primitive?
		end

		def to_s
			"#{@jvmclass} #{@name} #{@descriptor}"
		end
	end

	# An unresolved java method as name and type
	class JavaMethodHandle
		attr_reader :name, :descriptor
		attr_accessor :jvmclass

		def initialize jvmclass, name = nil, descriptor = nil
			raise TypeError unless jvmclass.is_a? JavaClassInstance
			raise TypeError unless name.is_a?(String) || name.nil?
			raise TypeError unless descriptor.is_a?(String) || descriptor.nil?
			@jvmclass = jvmclass
			@name = name
			@descriptor = nil
			@descriptor = MethodDescriptor.new(descriptor) if descriptor
		end

		def declared?
			@jvmclass.methods.key? self
		end

		def attr
			@jvmclass.methods[self]
		end

		def hash
			"#{@jvmclass}|#{@name}|#{@descriptor}".hash
		end

		def eql? other
			raise TypeError unless other.is_a? JavaMethodHandle
			@jvmclass.eql?(other.jvmclass) &&
					@name.eql?(other.name) &&
					@descriptor.eql?(other.descriptor)
		end

		def to_s
			"#{@jvmclass} #{@name} #{@descriptor}"
		end
	end
end
