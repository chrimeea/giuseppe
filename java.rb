#!/usr/bin/ruby
# frozen_string_literal: true

require './jvm'
require 'logger'

$logger = Logger.new($stdout)
$logger.level = Logger::ERROR
JVM.new.run_main ARGV.first
