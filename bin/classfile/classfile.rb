# frozen_string_literal: true

require_relative 'parser'
require_relative 'constantpool'
require_relative 'attributes'
require_relative 'fields'

module Giuseppe
	# Convenience methods to interpret access flags
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

	# Holds all values read from a class file
	class ClassFile
		attr_accessor :constant_pool, :interfaces, :attributes,
						:fields, :methods, :magic, :minor_version, :major_version,
						:this_class, :super_class, :access_flags

		def initialize
			@constant_pool = ConstantPool.new
			@interfaces = InterfaceList.new
			@attributes = ClassAttributeList.new
			@fields = ClassFieldList.new
			@methods = ClassFieldList.new
		end

		def load parser
			@magic = parser.load_u4
			fail "Invalid magic number #{@magic.to_s(16)}" unless @magic == 0xCAFEBABE
			@minor_version = parser.load_u2
			@major_version = parser.load_u2
			fail "Invalid major version #{@major_version}" unless @major_version == 50
			@constant_pool.load(parser)
			@access_flags = AccessFlags.new parser.load_u2
			@this_class = parser.load_u2
			@super_class = @constant_pool.get_attrib_value(parser.load_u2)
			@interfaces.load(parser, @constant_pool)
			@fields.load(parser, @constant_pool)
			@methods.load(parser, @constant_pool)
			@attributes.load(parser, @constant_pool)
			self
		end
	end

	# Loads a class file from disk
	class ClassFileLoader

		def initialize class_type
			@class_type = class_type
		end

		def load content = IO.binread(class_path(@class_type))
			$logger.info('classfile.rb') { "Loading #{@class_type}" }
			ClassFile.new.load(BinaryParser.new(content))
		end

			private

		def class_path class_type
			"#{class_type}.class"
		end
	end
end
