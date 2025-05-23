require_relative 'performance_optimizer'

module SchemaSherlock
  # Lookup using the binary index
  class IndexedUsageTracker
    class << self
      def count_column_references_with_index(index, table_name, column_name)
        return 0 unless index && index[:column_references]

        # Get files that potentially reference this column
        relevant_files = index[:column_references][column_name] || []
        return 0 if relevant_files.empty?

        # Use performance optimizer for parallel processing
        PerformanceOptimizer.process_files_parallel(relevant_files, table_name, column_name)
      end
    end
  end
end