module Migsupo
  module Differ
    module Operations
      class AddColumn
        attr_reader :table_name, :column

        def initialize(table_name:, column:)
          @table_name = table_name.to_s
          @column     = column
          freeze
        end

        def migration_type
          :add_column
        end

        def reversible?
          true
        end

        def to_s
          "add_column #{table_name}.#{column.name} (#{column.type})"
        end
      end
    end
  end
end
