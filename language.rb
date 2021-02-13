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
	attr_reader :class_type, :reference, :resolved
	attr_accessor :class_file

	def initialize class_type
		@class_type = class_type
		@reference = JavaInstance.new
		@resolved = {}
	end

	def method? method
		@class_file.get_method(method.method_name, method.method_type)
	rescue RuntimeError
		nil
	end

	def field? field
		@class_file.get_field(field.field_name, field.field_type)
	rescue RuntimeError
		nil
	end

	def element_type
		t = @class_type.gsub('[', '')
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

	def default_value
		case @field_type
		when 'B', 'C', 'D', 'F', 'I', 'J', 'S'
			0
		when 'Z'
			false
		end
	end
end

class JavaMethod
	attr_reader :method_name, :method_type, :args, :attrib, :retval

	def initialize method_name, method_type
		@method_name = method_name
		@method_type = method_type
		parse_type_descriptors
	end

	def parse_type_descriptors
		pattern = @method_type.match(/^\(([^\)]*)\)(.+)$/)
		descriptors = pattern[1]
		i = 0
		@args = []
		while i < descriptors.size
			case descriptors[i]
			when 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z'
				@args << descriptors[i]
			when 'L'
				i += 1
				j = descriptors.index(';', i)
				@args << descriptors[i...j]
				i = j
			when '['
				j = i
				j += 1 while descriptors[j] == '['
				@args << descriptors[i..j]
				i = j
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
