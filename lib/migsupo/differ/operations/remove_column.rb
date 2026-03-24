module Migsupo
  module Differ
    module Operations
      class RemoveColumn
        attr_reader :table_name, :column

        def initialize(table_name:, column:)
          @table_name = table_name.to_s
          @column     = column
          freeze
        end

        def column_name
          @column.name
        end

        def migration_type
          :remove_column
        end

        def reversible?
          true
        end

        def to_s
          "remove_column #{table_name}.#{column_name}"
        end
      end
    end
  end
end
