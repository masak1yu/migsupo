module Migsupo
  module Generator
    module Naming
      module_function

      def class_name(operations)
        types   = operations.map(&:migration_type).uniq
        tables  = operations.map(&:table_name).uniq

        if tables.size > 1
          "SchemaChanges"
        elsif types == [:create_table]
          "Create#{camelize(tables.first)}"
        elsif types == [:drop_table]
          "Drop#{camelize(tables.first)}"
        elsif types.all? { |t| t == :add_column }
          "AddColumnsTo#{camelize(tables.first)}"
        elsif types.all? { |t| t == :remove_column }
          "RemoveColumnsFrom#{camelize(tables.first)}"
        elsif types.all? { |t| t == :add_index }
          "AddIndexesTo#{camelize(tables.first)}"
        elsif types.all? { |t| t == :remove_index }
          "RemoveIndexesFrom#{camelize(tables.first)}"
        else
          "Modify#{camelize(tables.first)}"
        end
      end

      def file_name(timestamp:, class_name:)
        "#{timestamp}_#{underscore(class_name)}.rb"
      end

      def camelize(str)
        str.to_s.split("_").map(&:capitalize).join
      end

      def underscore(str)
        str.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
      end
    end
  end
end
