require_relative "base_command"
require_relative "../analyzers/foreign_key_detector"
require_relative "../analyzers/index_recommendation_detector"
require_relative "../schema_cache"
require_relative "../file_cache"
require_relative "../binary_index"

module SchemaSherlock
  module Commands
    class AnalyzeCommand < BaseCommand
      desc "analyze [MODEL]", "Analyze models for missing associations and optimization opportunities"
      option :output, type: :string, desc: "Output file for analysis results"
      option :min_usage, type: :numeric, desc: "Minimum usage threshold for suggestions (overrides config)"
      option :use_index, type: :boolean, default: true, desc: "Use binary index for faster analysis (if available)"

      def analyze(model_name = nil)
        load_rails_environment

        # Override configuration if min_usage option provided
        if options[:min_usage]
          original_threshold = SchemaSherlock.configuration.min_usage_threshold
          SchemaSherlock.configuration.min_usage_threshold = options[:min_usage]
        end

        models = model_name ? [find_model(model_name)] : all_models

        puts "Analyzing #{models.length} model(s)..."
        
        # Try to load binary index for faster analysis
        @binary_index = nil
        if options[:use_index] && defined?(Rails) && Rails.root
          puts "Loading binary index..."
          @binary_index = BinaryIndex.load_or_build(Rails.root.to_s)
          if @binary_index
            puts "  Index loaded with #{@binary_index[:files].size} files indexed"
          end
        end
        
        # Preload metadata cache for performance
        puts "Preloading database metadata..."
        cache_stats = SchemaCache.preload_all_metadata
        puts "  Cached: #{cache_stats[:tables_cached]} tables, #{cache_stats[:columns_cached]} column sets, #{cache_stats[:indexes_cached]} index sets"
        
        # Preload file cache for performance (only if usage tracking is enabled and no index available)
        if SchemaSherlock.configuration.min_usage_threshold && SchemaSherlock.configuration.min_usage_threshold > 0
          if @binary_index
            puts "Using binary index for file analysis (skipping file cache preload)"
          else
            puts "Preloading file cache..."
            file_stats = FileCache.preload_all_files
            puts "  Cached: #{file_stats[:files_scanned]} files (#{(file_stats[:total_size] / 1024.0 / 1024.0).round(2)} MB), #{file_stats[:files_failed]} failed"
          end
        end

        results = {}

        models.each do |model|
          puts "  Analyzing #{model.name}..."
          
          # Set binary index for usage tracker
          UsageTracker.binary_index = @binary_index
          
          analysis = analyze_model(model)

          # Only include models with issues in results
          if has_issues?(analysis)
            results[model.name] = analysis
          end
        end

        display_results(results, models.length)
        save_results(results) if options[:output]
      rescue SchemaSherlock::Error => e
        say e.message, :red
        exit 1
      ensure
        # Clear caches to free memory
        SchemaCache.clear_cache
        FileCache.clear_cache
        
        # Restore original threshold if it was overridden
        if options[:min_usage] && defined?(original_threshold)
          SchemaSherlock.configuration.min_usage_threshold = original_threshold
        end
      end

      private

      def analyze_model(model)
        {
          foreign_key_analysis: run_foreign_key_analysis(model),
          index_analysis: run_index_analysis(model)
        }
      end

      def run_foreign_key_analysis(model)
        analyzer = SchemaSherlock::Analyzers::ForeignKeyDetector.new(model)
        analyzer.analyze
        analyzer.results
      end

      def run_index_analysis(model)
        analyzer = SchemaSherlock::Analyzers::IndexRecommendationDetector.new(model)
        analyzer.analyze
        analyzer.results
      end

      def has_issues?(analysis)
        foreign_key_analysis = analysis[:foreign_key_analysis]
        missing = foreign_key_analysis[:missing_associations]
        orphaned = foreign_key_analysis[:orphaned_foreign_keys]

        index_analysis = analysis[:index_analysis]
        missing_indexes = index_analysis[:missing_foreign_key_indexes]

        missing.any? || orphaned.any? || missing_indexes.any?
      end

      def display_results(results, total_models)
        puts "\n" + "="*50
        puts "Schema Sherlock Investigation Report"
        puts "="*50

        results.each do |model_name, analysis|
          puts "\n#{model_name}:"

          missing = analysis[:foreign_key_analysis][:missing_associations]
          if missing.any?
            puts "  Missing Associations:"
            missing.each do |assoc|
              usage_info = assoc[:usage_count] ? " (used #{assoc[:usage_count]} times)" : ""
              puts "    belongs_to :#{assoc[:suggested_association]} # #{assoc[:column]} foreign key exists#{usage_info}"
            end
          end

          orphaned = analysis[:foreign_key_analysis][:orphaned_foreign_keys]
          if orphaned.any?
            puts "  Orphaned Foreign Keys:"
            orphaned.each do |key|
              puts "    #{key[:column]} -> #{key[:issue]}"
            end
          end

          missing_indexes = analysis[:index_analysis][:missing_foreign_key_indexes]
          if missing_indexes.any?
            puts "  Missing Indexes:"
            missing_indexes.each do |idx|
              puts "    #{idx[:migration]} # #{idx[:reason]}"
            end
          end
        end

        puts "\n" + "="*50
        puts "SUMMARY"
        puts "="*50
        puts "Models Analyzed: #{total_models}"
        puts "Models with Issues: #{results.length}"
        puts "Models without Issues: #{total_models - results.length}"
        puts "Usage Threshold: #{SchemaSherlock.configuration.min_usage_threshold} occurrences"
      end

      def save_results(results)
        File.write(options[:output], results.to_json)
        puts "\nResults saved to #{options[:output]}"
      end
    end
  end
end