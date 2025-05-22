require_relative "base_analyzer"
require_relative "../usage_tracker"

module AnnotatePlus
  module Analyzers
    class ForeignKeyDetector < BaseAnalyzer
      # Common integer types that can reference each other
      INTEGER_TYPES = %w[integer bigint].freeze
      # UUID types that can reference each other
      UUID_TYPES = %w[uuid].freeze
      # String types that might be used for UUIDs
      STRING_TYPES = %w[string text].freeze

      def analyze
        @results = {
          missing_associations: find_missing_associations,
          orphaned_foreign_keys: find_orphaned_foreign_keys,
          usage_stats: get_usage_stats
        }
      end

      private

      def find_missing_associations
        usage_stats = get_usage_stats
        min_threshold = AnnotatePlus.configuration.min_usage_threshold

        foreign_key_columns.reject do |column|
          has_association_for_column?(column)
        end.select do |column|
          # Only suggest if usage meets minimum threshold
          usage_count = usage_stats[column.name] || 0
          usage_count >= min_threshold
        end.map do |column|
          {
            column: column.name,
            suggested_association: suggest_association_name(column),
            type: :belongs_to,
            usage_count: usage_stats[column.name] || 0
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
        columns.select { |col| col.name.end_with?('_id') && col.name != 'id' && valid_foreign_key?(col) }
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

      def valid_foreign_key?(column)
        # Check if the column actually references an existing table's primary key
        referenced_table = infer_table_name(column)

        # First check if the table exists
        return false unless table_exists?(referenced_table)

        # Then check if the referenced table has a primary key that matches the column type
        begin
          referenced_model_class = referenced_table.classify.constantize
          primary_key_column = referenced_model_class.columns.find { |col| col.name == referenced_model_class.primary_key }

          # Compare column types to ensure they're compatible
          return false unless primary_key_column

          # Check if the types are compatible (both should be integer-like for _id columns)
          compatible_types?(column, primary_key_column)
        rescue NameError
          # If we can't find the model class, check if table has an 'id' column
          check_table_primary_key(referenced_table, column)
        end
      end

      private

      def compatible_types?(foreign_key_column, primary_key_column)
        fk_type = foreign_key_column.type.to_s
        pk_type = primary_key_column.type.to_s

        # Check for integer compatibility
        return true if INTEGER_TYPES.include?(fk_type) && INTEGER_TYPES.include?(pk_type)

        # Check for UUID compatibility
        return true if UUID_TYPES.include?(fk_type) && UUID_TYPES.include?(pk_type)

        # Check for string-based UUID compatibility (common when using string columns for UUIDs)
        return true if STRING_TYPES.include?(fk_type) && STRING_TYPES.include?(pk_type) &&
                      likely_uuid_column?(foreign_key_column, primary_key_column)

        # Cross-compatibility: string foreign key referencing UUID primary key (or vice versa)
        return true if (STRING_TYPES.include?(fk_type) && UUID_TYPES.include?(pk_type)) ||
                      (UUID_TYPES.include?(fk_type) && STRING_TYPES.include?(pk_type))

        false
      end

      def likely_uuid_column?(foreign_key_column, primary_key_column)
        # Check if string columns are likely to be UUIDs based on common patterns
        # This helps when applications use string columns to store UUIDs

        # Check column limits (UUIDs are typically 36 characters with dashes, 32 without)
        fk_limit = foreign_key_column.respond_to?(:limit) ? foreign_key_column.limit : nil
        pk_limit = primary_key_column.respond_to?(:limit) ? primary_key_column.limit : nil

        # Common UUID string lengths
        uuid_lengths = [32, 36]

        # If both columns have limits that match UUID lengths, likely UUIDs
        return true if fk_limit && pk_limit &&
                      uuid_lengths.include?(fk_limit) && uuid_lengths.include?(pk_limit)

        # Check column names for UUID patterns
        uuid_name_patterns = %w[uuid guid]
        fk_name_lower = foreign_key_column.name.downcase
        pk_name_lower = primary_key_column.name.downcase

        uuid_name_patterns.any? do |pattern|
          fk_name_lower.include?(pattern) || pk_name_lower.include?(pattern)
        end
      end

      def check_table_primary_key(table_name, foreign_key_column)
        # Fallback method when model class is not available
        # Check if the table has an 'id' column with compatible type
        begin
          connection = ActiveRecord::Base.connection
          primary_key_name = connection.primary_key(table_name)

          return false unless primary_key_name

          table_columns = connection.columns(table_name)
          primary_key_column = table_columns.find { |col| col.name == primary_key_name }

          return false unless primary_key_column

          compatible_types?(foreign_key_column, primary_key_column)
        rescue
          # If there's any error accessing the table structure, be conservative and return false
          false
        end
      end

      def get_usage_stats
        @usage_stats ||= UsageTracker.track_foreign_key_usage(@model_class)
      end
    end
  end
end