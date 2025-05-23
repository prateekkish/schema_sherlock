require 'strscan'

module SchemaSherlock
  class OptimizedScanner
    # Pre-compiled patterns stored as constants to avoid recompilation
    BOUNDARY_CHARS = /[\s\(\)\[\]\{\},;:'"]/
    
    class << self
      # Use StringScanner for efficient single-pass scanning
      def count_column_references(content, table_name, column_name)
        # Convert to downcase once for case-insensitive matching
        content_lower = content.downcase
        column_lower = column_name.downcase
        association_name = column_name.gsub(/_id$/, '').downcase
        
        count = 0
        scanner = StringScanner.new(content_lower)
        
        # Single pass through the content
        while scanner.scan_until(/\./)
          
          # Check for .where patterns
          if scanner.match?(/where\s*\(/)
            scanner.skip(/where\s*\(\s*/)
            if match_column_reference(scanner, column_lower)
              count += 1
              next
            end
          end
          
          # Check for .find_by patterns
          if scanner.match?(/find_by\s*\(/)
            scanner.skip(/find_by\s*\(\s*/)
            if match_column_reference(scanner, column_lower)
              count += 1
              next
            end
          end
          
          # Check for .joins and .includes with association
          if scanner.match?(/joins\s*\(/)
            scanner.skip(/joins\s*\(\s*/)
            if match_association_reference(scanner, association_name)
              count += 1
              next
            end
          elsif scanner.match?(/includes\s*\(/)
            scanner.skip(/includes\s*\(\s*/)
            if match_association_reference(scanner, association_name)
              count += 1
              next
            end
          end
          
          # Check for direct column access
          if scanner.match?(/#{Regexp.escape(column_lower)}\b/)
            scanner.skip(/#{Regexp.escape(column_lower)}\b/)
            count += 1
          end
        end
        
        count
      end
      
      # Native string operations version - even faster for simple patterns
      def count_column_references_native(content, table_name, column_name)
        content_lower = content.downcase
        column_lower = column_name.downcase
        association_name = column_name.gsub(/_id$/, '').downcase
        
        count = 0
        
        # Use native string operations for simple patterns
        # Count .where( patterns
        count += count_pattern_native(content_lower, ".where(", column_lower)
        count += count_pattern_native(content_lower, ".where (", column_lower)
        count += count_pattern_native(content_lower, ".find_by(", column_lower)
        count += count_pattern_native(content_lower, ".find_by (", column_lower)
        
        # Count joins/includes
        count += count_pattern_native(content_lower, ".joins(", association_name)
        count += count_pattern_native(content_lower, ".joins (", association_name)
        count += count_pattern_native(content_lower, ".includes(", association_name)
        count += count_pattern_native(content_lower, ".includes (", association_name)
        
        # Count direct access - use boundary checking
        count += count_direct_access(content_lower, ".#{column_lower}")
        
        count
      end
      
      private
      
      def match_column_reference(scanner, column_name)
        # Skip quotes if present
        scanner.skip(/['":]*/)
        
        # Check if column name matches
        if scanner.match?(/#{Regexp.escape(column_name)}/)
          scanner.skip(/#{Regexp.escape(column_name)}/)
          # Verify it's followed by appropriate characters
          scanner.match?(/['":]*\s*[=:]/)
        else
          false
        end
      end
      
      def match_association_reference(scanner, association_name)
        # Skip quotes if present
        scanner.skip(/['":]*/)
        
        # Check if association name matches
        if scanner.match?(/#{Regexp.escape(association_name)}/)
          scanner.skip(/#{Regexp.escape(association_name)}/)
          # Verify it's followed by appropriate characters
          scanner.match?(/['":]*\s*[\),]/)
        else
          false
        end
      end
      
      def count_pattern_native(content, prefix, target)
        count = 0
        index = 0
        
        while (pos = content.index(prefix, index))
          # Move past the prefix
          check_pos = pos + prefix.length
          
          # Skip whitespace and quotes
          while check_pos < content.length && " \t'\":".include?(content[check_pos])
            check_pos += 1
          end
          
          # Check if target matches at this position
          if content[check_pos, target.length] == target
            # Verify word boundary
            next_char_pos = check_pos + target.length
            if next_char_pos >= content.length || !('a'..'z').include?(content[next_char_pos])
              count += 1
            end
          end
          
          index = pos + 1
        end
        
        count
      end
      
      def count_direct_access(content, pattern)
        count = 0
        index = 0
        
        while (pos = content.index(pattern, index))
          # Check word boundary after pattern
          next_pos = pos + pattern.length
          if next_pos >= content.length || !('a'..'z').include?(content[next_pos])
            count += 1
          end
          index = pos + 1
        end
        
        count
      end
    end
  end
end