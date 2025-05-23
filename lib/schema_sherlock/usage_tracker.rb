require_relative 'file_cache'
require_relative 'optimized_scanner'
require_relative 'binary_index'
require_relative 'indexed_usage_tracker'
require_relative 'performance_optimizer'

module SchemaSherlock
  class UsageTracker
    class << self
      attr_accessor :binary_index

      def track_foreign_key_usage(model_class)
        return {} unless SchemaSherlock.configuration.min_usage_threshold

        scan_codebase_for_usage(model_class)
      end


      private

      def scan_codebase_for_usage(model_class)
        usage_counts = {}
        table_name = model_class.table_name

        foreign_key_columns(model_class).each do |column|
          count = scan_for_column_usage(table_name, column.name)
          usage_counts[column.name] = count if count > 0
        end

        usage_counts
      end

      def foreign_key_columns(model_class)
        model_class.columns.select { |col| col.name.end_with?('_id') && col.name != 'id' }
      end

      def scan_for_column_usage(table_name, column_name)
        # Use binary index if available for fastest lookup
        if binary_index
          IndexedUsageTracker.count_column_references_with_index(binary_index, table_name, column_name)
        else
          # Use performance-optimized scanning
          scan_with_performance_optimizer(table_name, column_name)
        end
      end

      def scan_with_performance_optimizer(table_name, column_name)
        all_files = get_relevant_files
        filtered_files = PerformanceOptimizer.filter_relevant_files(all_files, column_name)

        PerformanceOptimizer.process_files_parallel(filtered_files, table_name, column_name)
      end

      def get_relevant_files
        files = []
        scan_directories.each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob(File.join(dir, "**/*.rb")).each do |file|
            next if should_skip_file?(file)
            files << file
          end
        end
        files
      end

      def should_skip_file?(file)
        file.include?('/spec/') ||
        file.include?('/test/') ||
        file.include?('/vendor/') ||
        file.include?('/node_modules/') ||
        File.size(file) > 50 * 1024 * 1024  # Skip files larger than 50MB
      end

      def scan_directories
        return [] unless defined?(Rails) && Rails.root

        [
          Rails.root.join('app', 'controllers'),
          Rails.root.join('app', 'models'),
          Rails.root.join('app', 'services'),
          Rails.root.join('app', 'jobs'),
          Rails.root.join('lib')
        ].map(&:to_s)
      end


      def count_column_references(content, table_name, column_name)
        OptimizedScanner.count_column_references_native(content, table_name, column_name)
      end
    end
  end
end