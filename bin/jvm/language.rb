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
			@jvmclass = jvmclass
			@fields = {}
		end

		def set_field field, value
			@fields[field_id(field)] = value
		end

		def get_field field
			@fields[field_id(field)]
		end

			private

		def field_id field
			"#{field.jvmclass}.#{field.name}"
		end
	end

	# An instance of a java array
	class JavaArrayInstance < JavaInstance
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

	# The instance of the class of a java object, array or primitive type
	class JavaClassInstance
		attr_reader :descriptor, :reference, :class_file, :fields, :methods

		def initialize reference, descriptor
			@descriptor = descriptor
			@reference = reference
			@fields = {}
			@methods = {}
		end

		def class_file= value
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
			@jvmclass.eql?(other.jvmclass) &&
					@name.eql?(other.name) &&
					@descriptor.eql?(other.descriptor)
		end

		def to_s
			"#{@jvmclass} #{@name} #{@descriptor}"
		end
	end
end
