# frozen_string_literal: true

module Mirakl
  module Requests
    class DR11
      include Mirakl::ApiOperations::Request

      API_PATH = 'document-request/requests'

      def self.call(params = {}, opts = {})
        resp, opts = request(:get, API_PATH, params, opts)
        obj = MiraklObject.construct_from(resp.data, opts)

        obj
      end
    end
  end
end
