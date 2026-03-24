module Migsupo
  module Differ
    module Operations
      class ChangeColumn
        attr_reader :table_name, :new_column, :old_column

        def initialize(table_name:, new_column:, old_column:)
          @table_name = table_name.to_s
          @new_column = new_column
          @old_column = old_column
          freeze
        end

        def column_name
          @new_column.name
        end

        def migration_type
          :change_column
        end

        # change_column is irreversible in Rails unless we provide explicit up/down
        def reversible?
          false
        end

        def to_s
          "change_column #{table_name}.#{column_name} (#{old_column.type} -> #{new_column.type})"
        end
      end
    end
  end
end
