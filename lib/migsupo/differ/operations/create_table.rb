module Migsupo
  module Differ
    module Operations
      class CreateTable
        attr_reader :table

        def initialize(table)
          @table = table
          freeze
        end

        def table_name
          @table.name
        end

        def migration_type
          :create_table
        end

        def reversible?
          true
        end

        def to_s
          "create_table #{table_name}"
        end
      end
    end
  end
end
