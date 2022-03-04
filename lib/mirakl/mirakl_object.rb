# frozen_string_literal: true

module Mirakl
  class MiraklObject
    include Enumerable

    # def initialize(id = nil, opts = {})
    #   id, @retrieve_params = Util.normalize_id(id)
    #   @opts = Util.normalize_opts(opts)
    #   @original_values = {}
    #   @values = {}
    #   # This really belongs in APIResource, but not putting it there allows us
    #   # to have a unified inspect method
    #   @unsaved_values = Set.new
    #   @transient_values = Set.new
    #   @values[:id] = id if id
    # end

    def initialize
      @values = {}
    end

    def data
      @values
    end



    def self.construct_from(values, opts = {})
      values = Mirakl::Util.symbolize_names(values)

      # work around protected #initialize_from for now
      new().send(:initialize_from, values, opts)
    end


    protected def initialize_from(values, opts, partial = false)
      @opts = Util.normalize_opts(opts)

      values.each do |k, v|
        @values[k] = Util.convert_to_mirakl_object(v, @opts)
      end

      self
    end

  end
end
