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

class JavaClass
	attr_reader :class_type, :reference, :resolved, :class_file, :fields,
			:methods, :source_file, :super_class, :access_flags

	def initialize reference, class_type
		@class_type = class_type
		@reference = reference
		@resolved = {}
		@fields = []
		@methods = {}
		@interfaes = []
	end

	def class_file= value
		@class_file = value
		set_source_file
		set_super_class
		@access_flags = AccessFlags.new @class_file.access_flags
		value.fields.each do |f|
			field = load_java_field f
			@fields << field
			@resolved[field] = self
		end
		value.methods.each do |m|
			method = JavaMethod.new(value.constant_pool[m.name_index].value, value.constant_pool[m.descriptor_index].value)
			@methods[method] = m
			@resolved[method] = self
		end
		@interfaces = value.interfaces.map { |i| @class_file.get_attrib_name i }
	end

	def load_java_field field_attrib
		field = JavaField.new(
				@class_file.constant_pool[field_attrib.name_index].value,
				@class_file.constant_pool[field_attrib.descriptor_index].value
		)
		field.access_flags = AccessFlags.new field_attrib.access_flags
		field
	end

	def set_super_class
		return if @class_file.super_class.zero?
		@super_class = @class_file.get_attrib_name @class_file.super_class
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
	attr_accessor :access_flags

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
