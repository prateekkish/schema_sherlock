module AnnotatePlus
  module Analyzers
    class BaseAnalyzer
      attr_reader :model_class, :results

      def initialize(model_class)
        @model_class = model_class
        @results = {}
      end

      def analyze
        raise NotImplementedError, "Subclasses must implement #analyze"
      end

      private

      def model_name
        @model_class.name
      end

      def table_name
        @model_class.table_name
      end

      def columns
        @model_class.columns
      end

      def associations
        @model_class.reflect_on_all_associations
      end
    end
  end
end