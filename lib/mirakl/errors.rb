module Mirakl
  class MiraklError < StandardError
    attr_reader :message

    # Response contains a MiraklError object that has some basic information
    # about the response that conveyed the error.
    attr_accessor :response

    attr_reader :code
    attr_reader :http_body
    attr_reader :http_headers
    attr_reader :http_status
    attr_reader :json_body # equivalent to #data

    # Initializes a StripeError.
    def initialize(message = nil, http_status: nil, http_body: nil,
                   json_body: nil, http_headers: nil, code: nil)
      @message = message
      @http_status = http_status
      @http_body = http_body
      @http_headers = http_headers || {}
      @json_body = json_body
      @code = code
    end

    def to_s
      status_string = @http_status.nil? ? "" : "(Status #{@http_status}) "
      "#{status_string}#{@message}"
    end
  end

  # AuthenticationError is raised when invalid credentials are used to connect
  # to Mirakl's servers.
  class AuthenticationError < MiraklError
  end

  class APIError < MiraklError
  end

  # BadRequestError is raised when a request is initiated with invalid
  # parameters.
  class InvalidRequestError < MiraklError
    def initialize(message, param, http_status: nil, http_body: nil,
                   json_body: nil, http_headers: nil, code: nil)
      super(message, http_status: http_status, http_body: http_body,
                     json_body: json_body, http_headers: http_headers,
                     code: code)
      @param = param
    end
  end

  UnauthorizedError = Class.new(MiraklError)
  ForbiddenError = Class.new(MiraklError)
  ApiRequestsQuotaReachedError = Class.new(MiraklError)
  NotFoundError = Class.new(MiraklError)
  MethodNotAllowedError = Class.new(MiraklError)
  NotAcceptableError = Class.new(MiraklError)
  GoneError = Class.new(MiraklError)
  UnsupportedMediaTypeError = Class.new(MiraklError)
  TooManyRequestsError = Class.new(MiraklError)

end
