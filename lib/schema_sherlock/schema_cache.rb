module SchemaSherlock
  class SchemaCache
    class << self
      def initialize_cache
        @table_exists_cache = {}
        @columns_cache = {}
        @indexes_cache = {}
        @primary_keys_cache = {}
      end

      def clear_cache
        @table_exists_cache&.clear
        @columns_cache&.clear
        @indexes_cache&.clear
        @primary_keys_cache&.clear
      end

      def connection
        ActiveRecord::Base.connection
      end

      def preload_all_metadata
        initialize_cache if @table_exists_cache.nil?
        
        # Preload all tables existence
        all_tables = connection.tables
        all_tables.each { |table| @table_exists_cache[table] = true }
        
        # Preload columns, indexes, and primary keys for all tables
        all_tables.each do |table|
          @columns_cache[table] = connection.columns(table)
          @indexes_cache[table] = connection.indexes(table)
          @primary_keys_cache[table] = connection.primary_key(table)
        end
        
        # Return stats for debugging
        {
          tables_cached: @table_exists_cache.size,
          columns_cached: @columns_cache.size,
          indexes_cached: @indexes_cache.size,
          primary_keys_cached: @primary_keys_cache.size
        }
      end

      def table_exists?(table_name)
        initialize_cache if @table_exists_cache.nil?
        
        # Check cache first
        return @table_exists_cache[table_name] if @table_exists_cache.key?(table_name)
        
        # If not in cache, check database and cache result
        exists = connection.table_exists?(table_name)
        @table_exists_cache[table_name] = exists
        exists
      end

      def columns(table_name)
        initialize_cache if @columns_cache.nil?
        
        # Check cache first
        return @columns_cache[table_name] if @columns_cache.key?(table_name)
        
        # If not in cache, fetch from database and cache result
        return nil unless table_exists?(table_name)
        
        columns = connection.columns(table_name)
        @columns_cache[table_name] = columns
        columns
      end

      def indexes(table_name)
        initialize_cache if @indexes_cache.nil?
        
        # Check cache first
        return @indexes_cache[table_name] if @indexes_cache.key?(table_name)
        
        # If not in cache, fetch from database and cache result
        return [] unless table_exists?(table_name)
        
        indexes = connection.indexes(table_name)
        @indexes_cache[table_name] = indexes
        indexes
      end

      def primary_key(table_name)
        initialize_cache if @primary_keys_cache.nil?
        
        # Check cache first
        return @primary_keys_cache[table_name] if @primary_keys_cache.key?(table_name)
        
        # If not in cache, fetch from database and cache result
        return nil unless table_exists?(table_name)
        
        primary_key = connection.primary_key(table_name)
        @primary_keys_cache[table_name] = primary_key
        primary_key
      end

      # Helper method to get column by name
      def column(table_name, column_name)
        table_columns = columns(table_name)
        return nil unless table_columns
        
        table_columns.find { |col| col.name == column_name }
      end

      # Get cache statistics
      def cache_stats
        {
          table_exists_cache_size: @table_exists_cache&.size || 0,
          columns_cache_size: @columns_cache&.size || 0,
          indexes_cache_size: @indexes_cache&.size || 0,
          primary_keys_cache_size: @primary_keys_cache&.size || 0
        }
      end
    end
  end
end