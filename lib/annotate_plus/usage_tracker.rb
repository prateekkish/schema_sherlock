module AnnotatePlus
  class UsageTracker
    class << self
      def track_foreign_key_usage(model_class)
        return {} unless AnnotatePlus.configuration.min_usage_threshold

        scan_codebase_for_usage(model_class)
      end

      def track_association_usage(model_class)
        return {} unless AnnotatePlus.configuration.detect_unused_associations

        scan_codebase_for_association_usage(model_class)
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
        count = 0

        # Scan common Rails directories for usage patterns
        scan_directories.each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob("#{dir}/**/*.rb").each do |file|
            content = File.read(file)
            count += count_column_references(content, table_name, column_name)
          rescue => e
            # Skip files that can't be read
          end
        end

        count
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

      def scan_codebase_for_association_usage(model_class)
        usage_counts = {}
        associations = model_class.reflect_on_all_associations

        associations.each do |association|
          count = scan_for_association_usage(association.name.to_s)
          usage_counts[association.name.to_s] = count if count > 0
        end

        usage_counts
      end

      def scan_for_association_usage(association_name)
        count = 0

        # Scan common Rails directories for usage patterns
        scan_directories.each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob("#{dir}/**/*.rb").each do |file|
            content = File.read(file)
            count += count_association_references(content, association_name)
          rescue => e
            # Skip files that can't be read
          end
        end

        count
      end

      def count_association_references(content, association_name)
        count = 0

        # Count direct association access
        count += content.scan(/\.#{association_name}\b/i).length

        # Count association methods
        count += content.scan(/\.#{association_name}\./).length
        count += content.scan(/\.build_#{association_name}\b/i).length
        count += content.scan(/\.create_#{association_name}\b/i).length

        # Count joins and includes
        count += content.scan(/\.joins\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length
        count += content.scan(/\.includes\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length
        count += content.scan(/\.preload\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length
        count += content.scan(/\.eager_load\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length

        # Count nested associations in hashes/arrays
        count += content.scan(/['":]#{association_name}['"]?\s*[,\]\}]/i).length

        count
      end

      def count_column_references(content, table_name, column_name)
        count = 0

        # Count WHERE clauses using the foreign key
        count += content.scan(/\.where\s*\(\s*['":]?#{column_name}['":]?\s*[=:]/i).length
        count += content.scan(/\.find_by\s*\(\s*['":]?#{column_name}['":]?\s*[=:]/i).length

        # Count joins using the foreign key
        model_name = table_name.singularize
        association_name = column_name.gsub(/_id$/, '')
        count += content.scan(/\.joins\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length
        count += content.scan(/\.includes\s*\(\s*['":]?#{association_name}['":]?\s*\)/i).length

        # Count direct foreign key access
        count += content.scan(/\.#{column_name}\b/i).length

        count
      end
    end
  end
end