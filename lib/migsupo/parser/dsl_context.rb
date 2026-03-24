require_relative "table_dsl_context"
require_relative "../schema/index_definition"
require_relative "../schema/schema_definition"

module Migsupo
  module Parser
    class DslContext
      def initialize
        @tables  = {}
        @indexes = []
      end

      def create_table(name, **options, &block)
        ctx = TableDslContext.new(name, options)
        ctx.instance_eval(&block) if block
        table_def = ctx.to_table_definition

        # merge standalone indexes into the table definition later via SchemaDefinition
        @tables[name.to_s] = table_def
      end

      def add_index(table_name, columns, **options)
        @indexes << Schema::IndexDefinition.new(
          table_name: table_name.to_s,
          columns:    Array(columns).map(&:to_s),
          name:       options.delete(:name),
          options:    options
        )
      end

      def to_schema_definition
        tables = @tables.transform_values do |table_def|
          standalone = @indexes.select { |i| i.table_name == table_def.name }
          next table_def if standalone.empty?

          merged_indexes = (table_def.indexes + standalone).uniq(&:name)
          Schema::TableDefinition.new(
            name:    table_def.name,
            columns: table_def.columns,
            indexes: merged_indexes,
            options: table_def.options
          )
        end

        Schema::SchemaDefinition.new(tables: tables)
      end
    end
  end
end
