module SchemaSherlock
  class Configuration
    attr_accessor :exclude_models,
                  :min_usage_threshold

    def initialize
      @exclude_models = ['ActiveRecord::Base']
      @min_usage_threshold = 3
    end
  end
end