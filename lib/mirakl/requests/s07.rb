# frozen_string_literal: true

module Mirakl
  module Requests
    class S07
      include Mirakl::ApiOperations::Request

      API_PATH = 'shops'

      def self.call(params = {}, opts = {})
        resp, opts = request(:put, API_PATH, params, opts)
        obj = MiraklObject.construct_from(resp.data, opts)

        obj
      end
    end
  end
end
