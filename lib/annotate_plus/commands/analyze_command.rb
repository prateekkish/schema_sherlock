require_relative "base_command"
require_relative "../analyzers/foreign_key_detector"

module AnnotatePlus
  module Commands
    class AnalyzeCommand < BaseCommand
      desc "analyze [MODEL]", "Analyze models for missing associations and optimization opportunities"
      option :interactive, type: :boolean, default: false, desc: "Run in interactive mode"
      option :output, type: :string, desc: "Output file for analysis results"

      def analyze(model_name = nil)
        load_rails_environment

        models = model_name ? [find_model(model_name)] : all_models
        
        puts "Analyzing #{models.length} model(s)..."
        
        results = {}
        
        models.each do |model|
          puts "  Analyzing #{model.name}..."
          results[model.name] = analyze_model(model)
        end

        display_results(results)
        save_results(results) if options[:output]
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

      def display_results(results)
        puts "\n" + "="*50
        puts "Annotate Plus Analysis Report"
        puts "="*50

        results.each do |model_name, analysis|
          puts "\n#{model_name}:"
          
          missing = analysis[:foreign_key_analysis][:missing_associations]
          if missing.any?
            puts "  Missing Associations:"
            missing.each do |assoc|
              puts "    belongs_to :#{assoc[:suggested_association]} # #{assoc[:column]} foreign key exists"
            end
          end

          orphaned = analysis[:foreign_key_analysis][:orphaned_foreign_keys]
          if orphaned.any?
            puts "  Orphaned Foreign Keys:"
            orphaned.each do |key|
              puts "    #{key[:column]} -> #{key[:issue]}"
            end
          end

          if missing.empty? && orphaned.empty?
            puts "  No issues found"
          end
        end
      end

      def save_results(results)
        File.write(options[:output], results.to_json)
        puts "\nResults saved to #{options[:output]}"
      end
    end
  end
end