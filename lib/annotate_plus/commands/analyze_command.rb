require_relative "base_command"
require_relative "../analyzers/foreign_key_detector"

module AnnotatePlus
  module Commands
    class AnalyzeCommand < BaseCommand
      desc "analyze [MODEL]", "Analyze models for missing associations and optimization opportunities"
      option :interactive, type: :boolean, default: false, desc: "Run in interactive mode"
      option :output, type: :string, desc: "Output file for analysis results"
      option :min_usage, type: :numeric, desc: "Minimum usage threshold for suggestions (overrides config)"

      def analyze(model_name = nil)
        load_rails_environment

        # Override configuration if min_usage option provided
        if options[:min_usage]
          original_threshold = AnnotatePlus.configuration.min_usage_threshold
          AnnotatePlus.configuration.min_usage_threshold = options[:min_usage]
        end

        models = model_name ? [find_model(model_name)] : all_models

        puts "Analyzing #{models.length} model(s)..."

        results = {}

        models.each do |model|
          puts "  Analyzing #{model.name}..."
          analysis = analyze_model(model)

          # Only include models with issues in results
          if has_issues?(analysis)
            results[model.name] = analysis
          end
        end

        display_results(results, models.length)
        save_results(results) if options[:output]
      rescue AnnotatePlus::Error => e
        say e.message, :red
        exit 1
      ensure
        # Restore original threshold if it was overridden
        if options[:min_usage] && defined?(original_threshold)
          AnnotatePlus.configuration.min_usage_threshold = original_threshold
        end
      end

      private

      def analyze_model(model)
        {
          foreign_key_analysis: run_foreign_key_analysis(model)
        }
      end

      def run_foreign_key_analysis(model)
        analyzer = AnnotatePlus::Analyzers::ForeignKeyDetector.new(model)
        analyzer.analyze
        analyzer.results
      end

      def has_issues?(analysis)
        foreign_key_analysis = analysis[:foreign_key_analysis]
        missing = foreign_key_analysis[:missing_associations]
        orphaned = foreign_key_analysis[:orphaned_foreign_keys]

        missing.any? || orphaned.any?
      end

      def display_results(results, total_models)
        puts "\n" + "="*50
        puts "Annotate Plus Analysis Report"
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
        end

        puts "\n" + "="*50
        puts "SUMMARY"
        puts "="*50
        puts "Models Analyzed: #{total_models}"
        puts "Models with Issues: #{results.length}"
        puts "Models without Issues: #{total_models - results.length}"
        puts "Usage Threshold: #{AnnotatePlus.configuration.min_usage_threshold} occurrences"
      end

      def save_results(results)
        File.write(options[:output], results.to_json)
        puts "\nResults saved to #{options[:output]}"
      end
    end
  end
end