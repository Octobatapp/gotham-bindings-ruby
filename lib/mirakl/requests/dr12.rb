# frozen_string_literal: true

module Mirakl
  module Requests
    class DR12
      include Mirakl::ApiOperations::Request

      def self.call(params = {}, opts = {})
        if params[:document_request_id].blank?
          raise ArgumentError,
            "You must fill the `document_request_id` parameter to call the DR12 API endpoint"
        end

        document_request_id = params.delete(:document_request_id)
        api_path = "document-request/#{document_request_id}/lines"

        resp, opts = request(:get, api_path, params, opts)
        obj = MiraklObject.construct_from(resp.data, opts)

        obj
      end
    end
  end
end
