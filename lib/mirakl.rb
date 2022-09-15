# frozen_string_literal: true

# Mirakl Ruby bindings
require "cgi"
require "faraday"
require "json"
require "logger"
require "rbconfig"
require "set"
require "socket"
require "uri"

require "mirakl/version"

# API operations
require "mirakl/api_operations/request"

# Resources
require "mirakl/requests/dr11"
require "mirakl/requests/dr12"
require "mirakl/requests/dr74"
require "mirakl/requests/s07"
require "mirakl/requests/s20"

# API resource support classes
require "mirakl/util"
require "mirakl/errors"
require "mirakl/mirakl_response"
require "mirakl/mirakl_client"
require "mirakl/mirakl_object"



module Mirakl
  @api_base = 'https://octobat-dev.mirakl.net/api/'

  @open_timeout = 30
  @read_timeout = 80

  @log_level = nil
  @logger = nil

  class << self
    attr_accessor :api_key, :api_base, :open_timeout, :read_timeout
  end

  # map to the same values as the standard library's logger
  LEVEL_DEBUG = Logger::DEBUG
  LEVEL_ERROR = Logger::ERROR
  LEVEL_INFO = Logger::INFO

  # When set prompts the library to log some extra information to $stdout and
  # $stderr about what it's doing. For example, it'll produce information about
  # requests, responses, and errors that are received. Valid log levels are
  # `debug` and `info`, with `debug` being a little more verbose in places.
  #
  # Use of this configuration is only useful when `.logger` is _not_ set. When
  # it is, the decision what levels to print is entirely deferred to the logger.
  def self.log_level
    @log_level
  end

  def self.log_level=(val)
    # Backwards compatibility for values that we briefly allowed
    if val == "debug"
      val = LEVEL_DEBUG
    elsif val == "info"
      val = LEVEL_INFO
    end

    if !val.nil? && ![LEVEL_DEBUG, LEVEL_ERROR, LEVEL_INFO].include?(val)
      raise ArgumentError,
            "log_level should only be set to `nil`, `debug` or `info`"
    end
    @log_level = val
  end

  # Sets a logger to which logging output will be sent. The logger should
  # support the same interface as the `Logger` class that's part of Ruby's
  # standard library (hint, anything in `Rails.logger` will likely be
  # suitable).
  #
  # If `.logger` is set, the value of `.log_level` is ignored. The decision on
  # what levels to print is entirely deferred to the logger.
  def self.logger
    @logger
  end

  def self.logger=(val)
    @logger = val
  end

end

Mirakl.log_level = ENV["MIRAKL_LOG"] unless ENV["MIRAKL_LOG"].nil?
