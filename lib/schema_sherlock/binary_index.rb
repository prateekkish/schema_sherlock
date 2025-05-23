require 'msgpack'
require 'digest'

module SchemaSherlock
  class BinaryIndex
    INDEX_VERSION = "1.0"
    INDEX_FILE = "tmp/.schema_sherlock_index"

    class << self
      def load_or_build(root_path)
        index_path = File.join(root_path, INDEX_FILE)

        if File.exist?(index_path) && index_valid?(index_path, root_path)
          load_index(index_path)
        else
          build_and_save_index(root_path, index_path)
        end
      end

      def load_index(path)
        data = File.binread(path)
        MessagePack.unpack(data, symbolize_keys: true)
      rescue => e
        Rails.logger.warn("Failed to load index: #{e.message}") if defined?(Rails)
        nil
      end

      def build_and_save_index(root_path, index_path)
        index = build_index(root_path)

        # Binary serialization
        packed_data = MessagePack.pack(index)
        File.binwrite(index_path, packed_data)

        index
      rescue => e
        Rails.logger.warn("Failed to save index: #{e.message}") if defined?(Rails)
        index
      end

      private

      def index_valid?(index_path, root_path)
        return false unless File.exist?(index_path)

        index = load_index(index_path)
        return false unless index && index[:version] == INDEX_VERSION

        # Check if any files have been modified since index was built
        index_time = File.mtime(index_path)

        # If any Ruby file is newer than index, rebuild
        Dir.glob(File.join(root_path, "**/*.rb")).any? do |file|
          File.mtime(file) > index_time
        end == false
      end

      def build_index(root_path)
        index = {
          version: INDEX_VERSION,
          created_at: Time.now.to_i,
          files: {},
          column_references: {},
          file_checksums: {}
        }

        # Build file index with checksums
        Dir.glob(File.join(root_path, "**/*.rb")).each do |file|
          next if should_skip_file?(file)

          content = File.read(file, encoding: 'UTF-8', invalid: :replace, undef: :replace)
          checksum = Digest::MD5.hexdigest(content)

          index[:files][file] = {
            size: File.size(file),
            mtime: File.mtime(file).to_i,
            checksum: checksum
          }

          # Pre-scan for common patterns and cache results
          pre_scan_content(content, file, index)
        end

        index
      end

      def pre_scan_content(content, file, index)
        # Pre-scan for column references
        content.scan(/\.(\w+)_id\b/) do |match|
          column = "#{match[0]}_id"
          index[:column_references][column] ||= []
          index[:column_references][column] << file
        end

        # Pre-scan for associations
        content.scan(/\.(?:joins|includes)\s*\(\s*['":]?(\w+)/) do |match|
          association = match[0]
          column = "#{association}_id"
          index[:column_references][column] ||= []
          index[:column_references][column] << file
        end
      end

      def should_skip_file?(file)
        file.include?('/spec/') ||
        file.include?('/test/') ||
        file.include?('/vendor/') ||
        file.include?('/node_modules/')
      end
    end
  end

end