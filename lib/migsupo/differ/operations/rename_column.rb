module Migsupo
  module Differ
    module Operations
      class RenameColumn
        attr_reader :table_name, :old_name, :new_name

        def initialize(table_name:, old_name:, new_name:)
          @table_name = table_name.to_s
          @old_name   = old_name.to_s
          @new_name   = new_name.to_s
          freeze
        end

        def migration_type
          :rename_column
        end

        def reversible?
          true
        end

        def to_s
          "rename_column #{table_name}.#{old_name} -> #{new_name}"
        end
      end
    end
  end
end
