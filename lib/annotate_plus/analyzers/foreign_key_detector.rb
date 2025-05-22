require_relative "base_analyzer"

module AnnotatePlus
  module Analyzers
    class ForeignKeyDetector < BaseAnalyzer
      def analyze
        @results = {
          missing_associations: find_missing_associations,
          orphaned_foreign_keys: find_orphaned_foreign_keys
        }
      end

      private

      def find_missing_associations
        foreign_key_columns.reject do |column|
          has_association_for_column?(column)
        end.map do |column|
          {
            column: column.name,
            suggested_association: suggest_association_name(column),
            type: :belongs_to
          }
        end
      end

      def find_orphaned_foreign_keys
        # Find foreign key columns that don't have corresponding tables
        foreign_key_columns.select do |column|
          referenced_table = infer_table_name(column)
          !table_exists?(referenced_table)
        end.map do |column|
          {
            column: column.name,
            inferred_table: infer_table_name(column),
            issue: "Referenced table does not exist"
          }
        end
      end

      def foreign_key_columns
        columns.select { |col| col.name.end_with?('_id') && col.name != 'id' }
      end

      def has_association_for_column?(column)
        association_name = column.name.gsub(/_id$/, '')
        associations.any? do |assoc| 
          assoc.name.to_s == association_name || 
          assoc.foreign_key == column.name
        end
      end

      def suggest_association_name(column)
        column.name.gsub(/_id$/, '')
      end

      def infer_table_name(column)
        association_name = suggest_association_name(column)
        association_name.pluralize
      end

      def table_exists?(table_name)
        ActiveRecord::Base.connection.table_exists?(table_name)
      end
    end
  end
end