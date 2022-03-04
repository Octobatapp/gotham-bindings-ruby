#!/usr/bin/env ruby

# frozen_string_literal: true

require "irb"
require "irb/completion"

require "#{::File.dirname(__FILE__)}/../lib/mirakl"

# Config IRB to enable --simple-prompt and auto indent
IRB.conf[:PROMPT_MODE] = :SIMPLE
IRB.conf[:AUTO_INDENT] = true

puts "Loaded gem 'mirakl'"

IRB.start
