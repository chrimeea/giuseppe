#!/usr/bin/ruby

require './jvm'
require 'logger'

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
JVM.new.run_main ARGV.first
