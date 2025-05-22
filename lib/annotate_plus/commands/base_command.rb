require "thor"
require_relative "../model_loader"

module AnnotatePlus
  module Commands
    class BaseCommand < Thor
      protected

      def load_rails_environment
        unless defined?(Rails)
          # Try to load Rails if not already loaded
          config_path = File.expand_path("config/environment.rb", Dir.pwd)
          if File.exist?(config_path)
            require config_path
          else
            raise AnnotatePlus::Error, "Rails environment not found. Make sure you're running this from a Rails application root."
          end
        end
      rescue LoadError => e
        raise AnnotatePlus::Error, "Could not load Rails environment: #{e.message}"
      end

      def all_models
        ModelLoader.all_models
      end

      def find_model(name)
        ModelLoader.find_model(name)
      end
    end
  end
end