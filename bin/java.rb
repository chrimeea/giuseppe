#!/usr/bin/ruby
# frozen_string_literal: true

require_relative 'jvm'
require 'logger'

class Program
	def initialize jvm
		@jvm = jvm
	end

	def run class_type
		@jvm.run @jvm.load_class(class_type), JavaMethod.new('main', '([Ljava/lang/String;)V'), [java_array_with_args]
	rescue JVMError => e
		@jvm.run e.exception.jvmclass, JavaMethod.new('printStackTrace', '()V'), [e.exception]
	end

		private

	def java_array_with_args
		arrayref = @jvm.new_java_array @jvm.load_class('[Ljava/lang/String;'), [ARGV.size - 1]
		ARGV[1..-1].each_with_index { |s, i| arrayref.values[i] = @jvm.new_java_string(s) }
		arrayref
	end
end

$logger = Logger.new($stdout)
$logger.level = Logger::ERROR
$logger.info "Ruby #{RUBY_VERSION} - Running Giuseppe JVM 1.6_1.0 interpreter by Cristian Mocanu"
Program.new(JVM.new).run ARGV.first
