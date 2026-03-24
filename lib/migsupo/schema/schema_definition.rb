module Migsupo
  module Schema
    class SchemaDefinition
      attr_reader :tables

      def initialize(tables: {})
        @tables = tables.freeze
        freeze
      end

      def table(table_name)
        @tables[table_name.to_s]
      end

      def to_h
        { tables: tables.transform_values(&:to_h) }
      end
    end
  end
end
