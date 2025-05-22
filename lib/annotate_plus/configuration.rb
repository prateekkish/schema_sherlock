module AnnotatePlus
  class Configuration
    attr_accessor :analyze_query_logs,
                  :suggest_indexes,
                  :detect_unused_associations,
                  :annotation_position,
                  :exclude_models,
                  :min_usage_threshold

    def initialize
      @analyze_query_logs = false
      @suggest_indexes = true
      @detect_unused_associations = true
      @annotation_position = :top
      @exclude_models = ['ActiveRecord::Base']
      @min_usage_threshold = 3
    end
  end
end