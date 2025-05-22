module SchemaSherlock
  module ModelLoader
    class << self
      def all_models
        ensure_rails_loaded!
        load_application_models

        ActiveRecord::Base.descendants.select do |klass|
          includable_model?(klass)
        end
      end

      def find_model(name)
        ensure_rails_loaded!

        klass = name.safe_constantize || name.camelize.safe_constantize

        unless klass
          raise SchemaSherlock::Error, "Could not find model: #{name}"
        end

        unless klass < ActiveRecord::Base
          raise SchemaSherlock::Error, "#{name} is not an ActiveRecord model"
        end

        unless klass.table_exists?
          raise SchemaSherlock::Error, "Table for #{name} does not exist"
        end

        klass
      end

      private

      def ensure_rails_loaded!
        unless defined?(Rails) && Rails.application
          raise SchemaSherlock::Error, "Rails application not loaded"
        end
      end

      def load_application_models
        # Use Rails standard eager loading
        Rails.application.eager_load!

        # Also try to load models from common directories
        %w[app/models app/models/concerns].each do |dir|
          path = Rails.root.join(dir)
          next unless path.exist?

          Dir.glob(path.join("**/*.rb")).each do |file|
            require_dependency file
          rescue LoadError, NameError
            # Skip files that can't be loaded
          end
        end
      end

      def includable_model?(klass)
        return false unless klass.name
        return false if klass.abstract_class?
        return false if klass.name.start_with?("HABTM_")
        return false unless klass.table_exists?
        return false if excluded_model?(klass)

        true
      rescue => e
        # Skip models that raise errors
        false
      end

      def excluded_model?(klass)
        SchemaSherlock.configuration.exclude_models.include?(klass.name)
      end
    end
  end
end