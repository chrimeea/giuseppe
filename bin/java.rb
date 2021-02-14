#!/usr/bin/ruby
# frozen_string_literal: true

require_relative 'jvm'
require 'logger'

def run_main jvm, class_type
	arrayref = jvm.new_java_array jvm.load_class('[Ljava/lang/String;'), [ARGV.size - 1]
	ARGV[1..-1].each_with_index { |s, i| arrayref.values[i] = jvm.new_java_string(s) }
	jvm.run jvm.load_class(class_type), JavaMethod.new('main', '([Ljava/lang/String;)V'), [arrayref]
rescue JVMError => e
	method = JavaMethod.new('printStackTrace', '()V')
	jvm.run e.exception.jvmclass, method, [e.exception]
end

$logger = Logger.new($stdout)
$logger.level = Logger::ERROR
run_main JVM.new, ARGV.first
