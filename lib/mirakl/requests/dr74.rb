# frozen_string_literal: true

module Mirakl
  module Requests
    class DR74
      include Mirakl::ApiOperations::Request

      API_PATH = 'document-request/documents/upload'

      def self.call(params = {}, opts = {})

        raise ArgumentError, "files must be an array" if params[:files].nil? ||
          !params[:files].is_a?(Array)

        params[:files] = params[:files].map do |fp|
          unless fp.respond_to?(:read)
            raise ArgumentError, "each file must respond to `#read`"
          end

          Faraday::FilePart.new(fp, 'application/pdf', File.basename(fp))
        end

        # params[:files] = params[:files][0]

        raise ArgumentError, "documents_input must be a Hash" if params[:documents_input].nil? ||
          !params[:documents_input].is_a?(Hash)

        params[:documents_input] = Faraday::ParamPart.new(params[:documents_input].to_json, 'application/json')

        puts params.inspect

        opts = {
          content_type: "multipart/form-data",
        }.merge(Util.normalize_opts(opts))

        resp, opts = request(:post, API_PATH, params, opts)
        obj = MiraklObject.construct_from(resp.data, opts)

        obj
      end


    end
  end
end
