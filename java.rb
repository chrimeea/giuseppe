#!/usr/bin/ruby

require './jvm'
require 'logger'

$logger = Logger.new(STDOUT)
JVM.new.run_main ARGV.first
