#!/usr/bin/ruby
# frozen_string_literal: true

require_relative 'jvm/jvm'
require 'logger'

module Giuseppe
	# A java program
	class JavaProgram
		def initialize jvm
			@jvm = jvm
		end

		def run_main class_type, args
			@jvm.run(
					JavaMethodHandle.new(@jvm.java_class(class_type), 'main', '([Ljava/lang/String;)V'),
					[java_array_with_args(args)]
			)
		rescue JVMError => e
			@jvm.run(
					JavaMethodHandle.new(e.exception.jvmclass, 'printStackTrace', '()V'),
					[e.exception]
			)
		rescue RuntimeError => e
			puts e.message
		end

			private

		def java_array_with_args args
			arrayref = @jvm.new_java_array @jvm.java_class('[Ljava/lang/String;'), [args.size]
			args.each_with_index { |s, i| arrayref.values[i] = @jvm.new_java_string(s) }
			arrayref
		end
	end
end

$logger = Logger.new($stdout)
$logger.level = Logger::ERROR
$logger.info "Ruby #{RUBY_VERSION} - Running Giuseppe JVM 1.6_1.0 interpreter by Cristian Mocanu"
Giuseppe::JavaProgram.new(Giuseppe::JVM.new).run_main ARGV.first, ARGV[1..-1]
