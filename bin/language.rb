class JavaInstance
	attr_reader :jvmclass

	def initialize jvmclass = nil
		@jvmclass = jvmclass
		@fields = {}
	end

	def field_id jvmclass, field
		"#{jvmclass.class_type}.#{field.field_name}"
	end

	def set_field jvmclass, field, value
		@fields[field_id(jvmclass, field)] = value
	end

	def get_field jvmclass, field
		@fields[field_id(jvmclass, field)]
	end

	def class_reference?
		@jvmclass.nil?
	end
end

class JavaInstanceArray < JavaInstance
	attr_reader :values

	def initialize jvmclass, counts
		fail unless jvmclass.array?
		fail unless jvmclass.dimensions == counts.size
		@values = [nil] * counts.pop
		counts.reverse.each do |c|
			@values = Array.new(c) { |i| @values[i] }
		end
		super jvmclass
	end
end

class JavaClass
	attr_reader :class_type, :reference, :resolved, :class_file, :fields,
			:methods, :source_file

	def initialize reference, class_type
		@class_type = class_type
		@reference = reference
		@resolved = {}
		@fields = {}
		@methods = {}
		@interfaces = []
	end

	def class_file= value
		@class_file = value
		set_source_file
		value.fields.each do |f|
			field = JavaField.new(
					@class_file.constant_pool[f.name_index].value,
					@class_file.constant_pool[f.descriptor_index].value
			)
			@fields[field] = f
			@resolved[field] = self
		end
		value.methods.each do |m|
			method = JavaMethod.new(value.constant_pool[m.name_index].value, value.constant_pool[m.descriptor_index].value)
			@methods[method] = m
			@resolved[method] = self
		end
		@interfaces = value.interfaces.map { |i| @class_file.get_attrib_name i }
	end

	def super_class
		return 'java/lang/Object' if primitive? || array?
		return if @class_file.super_class.zero?
		@class_file.get_attrib_name @class_file.super_class
	end

	def set_source_file
		a = @class_file.attributes.find { |attrib| attrib.is_a? ClassAttributeSourceFile }
		@source_file = @class_file.constant_pool[a.sourcefile_index].value if a
	end

	def primitive?
		%w[B C D F I J S Z].include? @class_type
	end

	def element_type
		t = @class_type.delete('[')
		if t[0] == 'L'
			t[1..-2]
		else
			t
		end
	end

	def array?
		@class_type.chr == '['
	end

	def dimensions
		@class_type.count '['
	end
end

class JavaField
	attr_reader :field_name, :field_type

	def initialize field_name, field_type
		@field_name = field_name
		@field_type = field_type
	end

	def hash
		"#{field_name}|#{field_type}".hash
	end

	def eql? other
		field_name.eql? other.field_name
	end

	def default_value
		return 0 if %w[B C D F I J S Z].include? @field_type
	end
end

class JavaMethod
	attr_reader :method_name, :method_type, :args, :attrib, :retval

	def initialize method_name, method_type
		@method_name = method_name
		@method_type = method_type
		parse_type_descriptors
	end

	def hash
		"#{method_name}|#{method_type}".hash
	end

	def eql? other
		method_name.eql?(other.method_name) && method_type.eql?(other.method_type)
	end

	def parse_type_descriptors
		pattern = @method_type.match(/^\(([^)]*)\)(.+)$/)
		descriptors = pattern[1]
		i = 0
		@args = []
		a = ''
		while i < descriptors.size
			case descriptors[i]
			when 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z'
				@args << a + descriptors[i]
				a = ''
			when 'L'
				j = descriptors.index(';', i)
				@args << a + descriptors[i..j]
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
		@retval = pattern[2]
	end

	def return_value?
		@retval != 'V'
	end

	def native_name jvmclass
		n = jvmclass.class_type.gsub('/', '_')
		i = n.rindex('_')
		if i
			n[i] = '_jni_'
			n[0] = n[0].upcase
		else
			n = "Jni_#{n}"
		end
		"#{n.gsub('$', '_')}_#{@method_name}"
	end
end
