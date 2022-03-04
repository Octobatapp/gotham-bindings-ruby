module Mirakl
  class MiraklClient
    # MiraklAPIError = Class.new(StandardError)
    #
    # BadRequestError = Class.new(MiraklAPIError)
    # UnauthorizedError = Class.new(MiraklAPIError)
    # ForbiddenError = Class.new(MiraklAPIError)
    # ApiRequestsQuotaReachedError = Class.new(MiraklAPIError)
    # NotFoundError = Class.new(MiraklAPIError)
    # MethodNotAllowedError = Class.new(MiraklAPIError)
    # NotAcceptableError = Class.new(MiraklAPIError)
    # GoneError = Class.new(MiraklAPIError)
    # UnsupportedMediaTypeError = Class.new(MiraklAPIError)
    # TooManyRequestsError = Class.new(MiraklAPIError)
    # ApiError = Class.new(MiraklAPIError)
    #
    #
    # HTTP_OK_CODE = 200
    # HTTP_CREATED_CODE = 201
    # HTTP_NO_CONTENT_CODE = 204
    #
    # HTTP_BAD_REQUEST_CODE = 400
    # HTTP_UNAUTHORIZED_CODE = 401
    # HTTP_FORBIDDEN_CODE = 403
    # HTTP_NOT_FOUND_CODE = 404
    # HTTP_METHOD_NOT_ALLOWED_CODE = 405
    # HTTP_NOT_ACCEPTABLE_CODE = 406
    # HTTP_GONE_CODE = 410
    # HTTP_UNSUPPORTED_MEDIA_TYPE_CODE = 415
    # HTTP_TOO_MANY_REQUESTS_CODE = 429


    attr_accessor :conn

    def initialize(conn = nil)
      self.conn = conn || self.class.default_conn
    end


    def self.active_client
      Thread.current[:mirakl_client] || default_client
    end

    def self.default_client
      Thread.current[:mirakl_default_client] ||=
        Mirakl::MiraklClient.new(default_conn)
    end

    # A default Faraday connection to be used when one isn't configured. This
    # object should never be mutated, and instead instantiating your own
    # connection and wrapping it in a Mirakl::MiraklClient object should be preferred.
    def self.default_conn
      # We're going to keep connections around so that we can take advantage
      # of connection re-use, so make sure that we have a separate connection
      # object per thread.
      Thread.current[:mirakl_client_default_conn] ||= begin
        conn = Faraday.new do |builder|
          builder.request :multipart, flat_encode: true
          # builder.use Faraday::Request::Multipart,
          builder.use Faraday::Request::UrlEncoded
          builder.use Faraday::Response::RaiseError

          # Net::HTTP::Persistent doesn't seem to do well on Windows or JRuby,
          # so fall back to default there.
          if Gem.win_platform? || RUBY_PLATFORM == "java"
            builder.adapter :net_http
          else
            builder.adapter :net_http_persistent
          end
        end


        # if Mirakl.verify_ssl_certs
        #   conn.ssl.verify = true
        #   conn.ssl.cert_store = Mirakl.ca_store
        # else
        #   conn.ssl.verify = false
        #
        #   unless @verify_ssl_warned
        #     @verify_ssl_warned = true
        #     warn("WARNING: Running without SSL cert verification. " \
        #       "You should never do this in production. " \
        #       "Execute `Mirakl.verify_ssl_certs = true` to enable " \
        #       "verification.")
        #   end
        # end

        conn
      end
    end

    # Executes the API call within the given block. Usage looks like:
    #
    #     client = MiraklClient.new
    #     obj, resp = client.request { ... }
    #
    def request
      @last_response = nil
      old_mirakl_client = Thread.current[:mirakl_client]
      Thread.current[:mirakl_client] = self

      begin
        res = yield
        [res, @last_response]
      ensure
        Thread.current[:mirakl_client] = old_mirakl_client
      end
    end


    def execute_request(method, path,
                        api_base: nil, api_key: nil, headers: {}, params: {})

      api_base ||= Mirakl.api_base
      api_key ||= Mirakl.api_key
      # params = Util.objects_to_ids(params)

      check_api_key!(api_key)

      body = nil
      query_params = nil
      case method.to_s.downcase.to_sym
      when :get, :head, :delete
        query_params = params
      else
        body = params
      end

      # This works around an edge case where we end up with both query
      # parameters in `query_params` and query parameters that are appended
      # onto the end of the given path. In this case, Faraday will silently
      # discard the URL's parameters which may break a request.
      #
      # Here we decode any parameters that were added onto the end of a path
      # and add them to `query_params` so that all parameters end up in one
      # place and all of them are correctly included in the final request.
      u = URI.parse(path)
      unless u.query.nil?
        query_params ||= {}
        query_params = Hash[URI.decode_www_form(u.query)].merge(query_params)

        # Reset the path minus any query parameters that were specified.
        path = u.path
      end

      headers = request_headers(api_key)
                .update(Util.normalize_headers(headers))

      Util.log_debug("HEADERS:",
                     headers: headers)


      params_encoder = FaradayMiraklEncoder.new
      url = api_url(path, api_base)

      if !body.nil?
        Util.log_debug("BODY:",
                     body: body,
                      bodyencoded: params_encoder.encode(body))
      end

      # stores information on the request we're about to make so that we don't
      # have to pass as many parameters around for logging.
      context = RequestLogContext.new
      context.api_key         = api_key
      context.body            = body ? params_encoder.encode(body) : nil
      # context.body            = body ? body : nil
      context.method          = method
      context.path            = path
      context.query_params    = if query_params
                                  params_encoder.encode(query_params)
                                end

      # note that both request body and query params will be passed through
      # `FaradayMiraklEncoder`
      http_resp = execute_request_with_rescues(api_base, context) do
        conn.run_request(method, url, body, headers) do |req|

          Util.log_debug("BODYSOUP:",
                         body: body)

          req.options.open_timeout = Mirakl.open_timeout
          req.options.params_encoder = params_encoder
          req.options.timeout = Mirakl.read_timeout
          req.params = query_params unless query_params.nil?
        end
      end

      begin
        resp = MiraklResponse.from_faraday_response(http_resp)
      rescue JSON::ParserError
        raise general_api_error(http_resp.status, http_resp.body)
      end

      # Allows MiraklClient#request to return a response object to a caller.
      @last_response = resp
      [resp, api_key]
    end

    private def general_api_error(status, body)
      APIError.new("Invalid response object from API: #{body.inspect} " \
                   "(HTTP response code was #{status})",
                   http_status: status, http_body: body)
    end



    # Used to workaround buggy behavior in Faraday: the library will try to
    # reshape anything that we pass to `req.params` with one of its default
    # encoders. I don't think this process is supposed to be lossy, but it is
    # -- in particular when we send our integer-indexed maps (i.e. arrays),
    # Faraday ends up stripping out the integer indexes.
    #
    # We work around the problem by implementing our own simplified encoder and
    # telling Faraday to use that.
    #
    # The class also performs simple caching so that we don't have to encode
    # parameters twice for every request (once to build the request and once
    # for logging).
    #
    # When initialized with `multipart: true`, the encoder just inspects the
    # hash instead to get a decent representation for logging. In the case of a
    # multipart request, Faraday won't use the result of this encoder.
    class FaradayMiraklEncoder
      def initialize
        @cache = {}
      end

      # This is quite subtle, but for a `multipart/form-data` request Faraday
      # will throw away the result of this encoder and build its body.
      def encode(hash)
        @cache.fetch(hash) do |k|
          @cache[k] = Util.encode_parameters(hash)
        end
      end

      # We should never need to do this so it's not implemented.
      def decode(_str)
        raise NotImplementedError,
              "#{self.class.name} does not implement #decode"
      end
    end


    private def check_api_key!(api_key)
      unless api_key
        raise AuthenticationError, "No API key provided. " \
          'Set your API key using "Mirakl.api_key = <API-KEY>". '
      end

      return unless api_key =~ /^\s/

      raise AuthenticationError, "Your API key is invalid, as it contains " \
        "whitespace. (HINT: You can double-check your API key from the " \
        "Mirakl web interface"
    end

    private def execute_request_with_rescues(api_base, context)
      begin
        log_request(context)
        resp = yield
        context = context.dup_from_response(resp)
        log_response(context, resp.status, resp.body)

      # We rescue all exceptions from a request so that we have an easy spot to
      # implement our retry logic across the board. We'll re-raise if it's a
      # type of exception that we didn't expect to handle.
      rescue StandardError => e
        # If we modify context we copy it into a new variable so as not to
        # taint the original on a retry.
        error_context = context

        if e.respond_to?(:response) && e.response
          error_context = context.dup_from_response(e.response)
          log_response(error_context,
                       e.response[:status], e.response[:body])
        else
          log_response_error(error_context, e)
        end

        # if self.class.should_retry?(e, num_retries)
        #   num_retries += 1
        #   sleep self.class.sleep_time(num_retries)
        #   retry
        # end

        case e
        when Faraday::ClientError
          if e.response
            handle_error_response(e.response, error_context)
          else
            handle_network_error(e, error_context, num_retries, api_base)
          end

        # Only handle errors when we know we can do so, and re-raise otherwise.
        # This should be pretty infrequent.
        else
          raise
        end
      end

      resp
    end


    private def handle_error_response(http_resp, context)
      begin
        resp = MiraklResponse.from_faraday_hash(http_resp)
        Util.log_debug("RESP:",
                       resp: resp.data)

        error_data = resp.data

        raise MiraklError, "Indeterminate error" unless error_data
      rescue JSON::ParserError
        raise general_api_error(http_resp[:status], http_resp[:body])
      end

      error = specific_api_error(resp, error_data, context)

      error.response = resp
      raise(error)
    end

    private def specific_api_error(resp, error_data, context)
      Util.log_error("Mirakl API error",
                     status: resp.http_status,
                     error_data: error_data)

      # The standard set of arguments that can be used to initialize most of
      # the exceptions.
      opts = {
        http_body: resp.http_body,
        http_headers: resp.http_headers,
        http_status: resp.http_status,
        json_body: resp.data,
      }

      case resp.http_status
      when 400, 404
        if resp.data.key?(:errors)
          InvalidRequestError.new(
            resp.data[:errors][0][:message], resp.data[:errors][0][:field],
            opts
          )
        else
          APIError.new(resp.data[:message], opts)
        end
      when 401
        AuthenticationError.new(resp.data[:message], opts)
      when 403
        PermissionError.new(resp.data[:message], opts)
      when 429
        RateLimitError.new(resp.data[:message], opts)
      else
        APIError.new(resp.data[:message], opts)
      end
    end


    private def handle_network_error(error, context, num_retries,
                                     api_base = nil)
      Util.log_error("Mirakl network error",
                     error_message: error.message)

      case error
      when Faraday::ConnectionFailed
        message = "Unexpected error communicating when trying to connect to " \
          "Mirakl. You may be seeing this message because your DNS is not " \
          "working.  To check, try running `host mirakl.com` from the " \
          "command line."

      when Faraday::SSLError
        message = "Could not establish a secure connection to Mirakl, you " \
          "may need to upgrade your OpenSSL version. To check, try running " \
          "`openssl s_client -connect api.mirakl.com:443` from the command " \
          "line."

      when Faraday::TimeoutError
        api_base ||= Mirakl.api_base
        message = "Could not connect to Mirakl (#{api_base}). " \
          "Please check your internet connection and try again."

      else
        message = "Unexpected error communicating with Mirakl."

      end

      raise APIConnectionError,
            message + "\n\n(Network error: #{error.message})"
    end

    private def request_headers(api_key)
      user_agent = "Mirakl/vX RubyBindings/#{Mirakl::VERSION}"

      headers = {
        "User-Agent" => user_agent,
        "Authorization" => "#{api_key}",
        "Content-Type" => "application/x-www-form-urlencoded",
      }

      headers
    end

    private def api_url(url = "", api_base = nil)
      (api_base || Mirakl.api_base) + url
    end


    private def log_request(context)
      Util.log_info("Request to Mirakl API",
                    method: context.method,
                    path: context.path)
      Util.log_debug("Request details",
                     body: context.body,
                     query_params: context.query_params)
    end

    private def log_response(context, status, body)
      Util.log_info("Response from Mirakl API",
                    method: context.method,
                    path: context.path,
                    status: status)
      Util.log_debug("Response details",
                     body: body)

      return unless context.request_id
    end

    private def log_response_error(context, error)
      Util.log_error("Request error",
                     error_message: error.message,
                     method: context.method,
                     path: context.path)
    end

    # RequestLogContext stores information about a request that's begin made so
    # that we can log certain information. It's useful because it means that we
    # don't have to pass around as many parameters.
    class RequestLogContext
      attr_accessor :body
      attr_accessor :api_key
      attr_accessor :method
      attr_accessor :path
      attr_accessor :query_params
      attr_accessor :request_id

      # The idea with this method is that we might want to update some of
      # context information because a response that we've received from the API
      # contains information that's more authoritative than what we started
      # with for a request. For example, we should trust whatever came back in
      # a `Mirakl-Version` header beyond what configuration information that we
      # might have had available.
      def dup_from_response(resp)
        return self if resp.nil?

        # Faraday's API is a little unusual. Normally it'll produce a response
        # object with a `headers` method, but on error what it puts into
        # `e.response` is an untyped `Hash`.
        headers = if resp.is_a?(Faraday::Response)
                    resp.headers
                  else
                    resp[:headers]
                  end

        context = dup
        context
      end
    end


  end
end
