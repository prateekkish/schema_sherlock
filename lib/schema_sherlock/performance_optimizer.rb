module SchemaSherlock
  # Centralized performance optimization for file and pattern processing
  class PerformanceOptimizer
    # File size thresholds for processing strategies
    SMALL_FILE_THRESHOLD = 64 * 1024     # 64KB
    LARGE_FILE_THRESHOLD = 1024 * 1024   # 1MB
    
    class << self
      # High-performance file reading with size-based optimization
      def read_file_optimized(file_path)
        return "" unless File.exist?(file_path) && File.readable?(file_path)
        
        file_size = File.size(file_path)
        return "" if file_size == 0
        
        if file_size < LARGE_FILE_THRESHOLD
          # Small/medium files: direct read
          File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace)
        else
          # Large files: chunked reading with buffer
          read_large_file_chunked(file_path)
        end
      rescue
        ""
      end
      
      # Fast pattern matching with pre-filtering
      def count_patterns_optimized(content, table_name, column_name)
        # Early exit if content is empty or too short
        return 0 if content.nil? || content.length < column_name.length
        
        # Quick pre-filter: check if column name exists at all
        content_lower = content.downcase
        column_lower = column_name.downcase
        
        # If column name doesn't appear anywhere, skip expensive matching
        return 0 unless content_lower.include?(column_lower)
        
        # Use optimized scanner
        OptimizedScanner.count_column_references_native(content, table_name, column_name)
      end
      
      # Parallel file processing with optimal thread count
      def process_files_parallel(file_paths, table_name, column_name)
        return 0 if file_paths.empty?
        
        # Limit threads to avoid overwhelming the system
        max_threads = [Concurrent.processor_count, file_paths.size, 8].min
        
        futures = []
        thread_pool = Concurrent::FixedThreadPool.new(max_threads)
        
        file_paths.each do |file_path|
          future = Concurrent::Future.execute(executor: thread_pool) do
            content = read_file_optimized(file_path)
            count_patterns_optimized(content, table_name, column_name)
          end
          futures << future
        end
        
        # Collect results efficiently
        total_count = futures.sum do |future|
          future.value || 0
        rescue
          0
        end
        
        thread_pool.shutdown
        thread_pool.wait_for_termination(5)
        
        total_count
      end
      
      # Smart file filtering to reduce I/O
      def filter_relevant_files(file_paths, column_name)
        # For very large sets, do a quick filename-based filter first
        if file_paths.size > 1000
          # Filter by filename patterns that are likely to contain the column
          association_name = column_name.gsub(/_id$/, '')
          relevant_patterns = [column_name, association_name, 'model', 'service', 'query']
          
          file_paths.select do |path|
            filename = File.basename(path, '.rb').downcase
            relevant_patterns.any? { |pattern| filename.include?(pattern) }
          end
        else
          file_paths
        end
      end
      
      private
      
      def read_large_file_chunked(file_path)
        content = String.new
        chunk_size = 64 * 1024  # 64KB chunks
        
        File.open(file_path, 'rb') do |file|
          # OS hint for sequential access
          file.advise(:sequential) if file.respond_to?(:advise)
          
          while chunk = file.read(chunk_size)
            content << chunk
          end
        end
        
        # Single UTF-8 conversion for entire content
        content.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
      end
    end
  end
end