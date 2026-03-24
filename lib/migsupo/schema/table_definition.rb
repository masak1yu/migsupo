module Migsupo
  module Schema
    class TableDefinition
      attr_reader :name, :columns, :indexes, :options

      def initialize(name:, columns: [], indexes: [], options: {})
        @name    = name.to_s
        @columns = columns.freeze
        @indexes = indexes.freeze
        @options = options.transform_keys(&:to_sym).freeze

        @columns_by_name = columns.each_with_object({}) { |c, h| h[c.name] = c }.freeze
        @indexes_by_name = indexes.each_with_object({}) { |i, h| h[i.name] = i }.freeze

        freeze
      end

      def column(col_name)
        @columns_by_name[col_name.to_s]
      end

      def index(idx_name)
        @indexes_by_name[idx_name.to_s]
      end

      def to_h
        { name: name, columns: columns.map(&:to_h), indexes: indexes.map(&:to_h), options: options }
      end
    end
  end
end
