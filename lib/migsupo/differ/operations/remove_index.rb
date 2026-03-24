module Migsupo
  module Differ
    module Operations
      class RemoveIndex
        attr_reader :table_name, :index

        def initialize(table_name:, index:)
          @table_name = table_name.to_s
          @index      = index
          freeze
        end

        def migration_type
          :remove_index
        end

        def reversible?
          true
        end

        def to_s
          "remove_index #{table_name} [#{index.columns.join(', ')}]"
        end
      end
    end
  end
end
