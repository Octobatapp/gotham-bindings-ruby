# frozen_string_literal: true

module Mirakl
  module Requests
    class DR12
      include Mirakl::ApiOperations::Request

      def self.call(document_request_id, params = {}, opts = {})
        if document_request_id.blank?
          raise ArgumentError,
            "You must fill the `document_request_id` value to call the DR12 API endpoint"
        end

        api_path = "document-request/#{document_request_id}/lines"

        resp, opts = request(:get, api_path, params, opts)
        obj = MiraklObject.construct_from(resp.data, opts)

        obj
      end
    end
  end
end
