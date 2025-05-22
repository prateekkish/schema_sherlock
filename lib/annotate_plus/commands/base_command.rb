require "thor"

module AnnotatePlus
  module Commands
    class BaseCommand < Thor
      protected

      def load_rails_environment
        config_path = File.expand_path("config/environment.rb", Dir.pwd)
        if File.exist?(config_path)
          require config_path
        else
          puts "Rails environment not found. Make sure you're running this from a Rails application root."
          exit 1
        end
      rescue LoadError => e
        puts "Could not load Rails environment: #{e.message}"
        puts "Rails environment not found. Make sure you're running this from a Rails application root."
        exit 1
      end

      def all_models
        Rails.application.eager_load!
        ApplicationRecord.descendants.reject do |model|
          AnnotatePlus.configuration.exclude_models.include?(model.name)
        end
      end

      def find_model(name)
        model = name.constantize
        unless model < ApplicationRecord
          puts "#{name} is not an ActiveRecord model"
          exit 1
        end
        model
      rescue NameError
        puts "Model #{name} not found"
        exit 1
      end
    end
  end
end