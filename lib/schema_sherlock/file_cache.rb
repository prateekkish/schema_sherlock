require 'concurrent'

module SchemaSherlock
  class FileCache
    class << self
      def initialize_cache
        @file_contents_cache = {}
        @scan_stats = { files_scanned: 0, files_failed: 0, total_size: 0 }
      end

      def clear_cache
        @file_contents_cache&.clear
        @scan_stats = { files_scanned: 0, files_failed: 0, total_size: 0 }
      end

      def preload_all_files(max_threads: 4)
        initialize_cache if @file_contents_cache.nil?

        files_to_scan = gather_all_files
        return { files_scanned: 0, files_failed: 0, total_size: 0 } if files_to_scan.empty?

        if max_threads > 1
          preload_files_parallel(files_to_scan, max_threads)
        else
          preload_files_sequential(files_to_scan)
        end

        @scan_stats.dup
      end

      def get_file_content(file_path)
        initialize_cache if @file_contents_cache.nil?

        # Return cached content if available
        return @file_contents_cache[file_path] if @file_contents_cache.key?(file_path)

        # If not cached, read and cache it
        content = read_file_safely(file_path)
        @file_contents_cache[file_path] = content if content
        content
      end

      def cached_files_count
        @file_contents_cache&.size || 0
      end

      def cache_stats
        {
          cached_files: @file_contents_cache&.size || 0,
          scan_stats: @scan_stats || { files_scanned: 0, files_failed: 0, total_size: 0 }
        }
      end

      def scan_for_pattern_in_all_files(pattern, table_name: nil, column_name: nil)
        initialize_cache if @file_contents_cache.nil?

        total_matches = 0

        @file_contents_cache.each do |file_path, content|
          next unless content

          if block_given?
            # Allow custom matching logic
            matches = yield(content, file_path, table_name, column_name)
          else
            # Default regex matching
            matches = content.scan(pattern).length
          end

          total_matches += matches
        end

        total_matches
      end

      private

      def preload_files_parallel(files_to_scan, max_threads)
        # Use concurrent processing for file reading
        thread_pool = Concurrent::FixedThreadPool.new(max_threads)
        futures = []

        files_to_scan.each do |file_path|
          future = Concurrent::Future.execute(executor: thread_pool) do
            read_file_safely(file_path)
          end
          futures << [file_path, future]
        end

        # Collect results
        futures.each do |file_path, future|
          begin
            content = future.value(10) # 10 second timeout per file
            if content
              @file_contents_cache[file_path] = content
              @scan_stats[:files_scanned] += 1
              @scan_stats[:total_size] += content.bytesize
            else
              @scan_stats[:files_failed] += 1
            end
          rescue Concurrent::TimeoutError, StandardError
            @scan_stats[:files_failed] += 1
          end
        end

        thread_pool.shutdown
        thread_pool.wait_for_termination(30)
      end

      def preload_files_sequential(files_to_scan)
        # Fallback to sequential processing
        files_to_scan.each do |file_path|
          content = read_file_safely(file_path)
          if content
            @file_contents_cache[file_path] = content
            @scan_stats[:files_scanned] += 1
            @scan_stats[:total_size] += content.bytesize
          else
            @scan_stats[:files_failed] += 1
          end
        end
      end

      def gather_all_files
        return [] unless defined?(Rails) && Rails.root

        directories = scan_directories
        all_files = []

        directories.each do |dir|
          next unless Dir.exist?(dir)

          pattern = File.join(dir, '**', '*.rb')
          files = Dir.glob(pattern)
          all_files.concat(files)
        end

        # Remove duplicates and filter out files we might not want to scan
        all_files.uniq.reject { |file| should_skip_file?(file) }
      end

      def scan_directories
        return [] unless defined?(Rails) && Rails.root

        [
          Rails.root.join('app', 'controllers'),
          Rails.root.join('app', 'models'),
          Rails.root.join('app', 'services'),
          Rails.root.join('app', 'jobs'),
          Rails.root.join('app', 'workers'),
          Rails.root.join('app', 'queries'),
          Rails.root.join('lib')
        ].map(&:to_s)
      end

      def should_skip_file?(file_path)
        # Skip files that are unlikely to contain foreign key references
        filename = File.basename(file_path)

        # Skip test files, migrations, and other non-relevant files
        return true if filename.match?(/(_spec|_test|\.spec|\.test)\.rb$/)
        return true if file_path.include?('/spec/')
        return true if file_path.include?('/test/')
        return true if file_path.include?('/migrate/')
        return true if file_path.include?('/db/migrate/')

        # Skip very large files (likely generated or data files)
        return true if File.size(file_path) > 1_048_576 # 1MB

        false
      rescue StandardError
        true # Skip files we can't access
      end

      def read_file_safely(file_path)
        return nil unless File.readable?(file_path)

        content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace)

        # Validation - skip binary files or files with null bytes
        return nil if content.include?("\x00")

        content
      rescue StandardError
        nil
      end
    end
  end
end