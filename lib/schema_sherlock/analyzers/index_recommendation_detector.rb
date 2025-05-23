require_relative "base_analyzer"
require_relative "../schema_cache"

module SchemaSherlock
  module Analyzers
    class IndexRecommendationDetector < BaseAnalyzer
      def analyze
        @results = {
          missing_foreign_key_indexes: find_missing_foreign_key_indexes,
        }
      end

      private

      def find_missing_foreign_key_indexes
        foreign_key_columns.reject do |column|
          has_index_on_column?(column.name)
        end.map do |column|
          {
            column: column.name,
            table: table_name,
            migration: "add_index :#{table_name}, :#{column.name}",
            reason: "Foreign key without index"
          }
        end
      end

      def foreign_key_columns
        @foreign_key_columns ||= columns.select { |col| col.name.end_with?('_id') && col.name != 'id' }
      end

      def has_index_on_column?(column_name)
        existing_indexes.any? do |index|
          index_columns = Array(index.columns)
          index_columns.include?(column_name) && index_columns.size == 1
        end
      end

      def existing_indexes
        @existing_indexes ||= SchemaCache.indexes(table_name)
      end
    end
  end
end