require_relative "../schema/column_definition"
require_relative "../schema/index_definition"
require_relative "../schema/table_definition"
require_relative "../schema/schema_definition"

module Migsupo
  module Loader
    class ActiveRecordLoader
      def initialize(ignored_tables: [])
        @ignored_tables = ignored_tables
      end

      def load_schema
        tables = {}

        connection.tables.each do |table_name|
          next if @ignored_tables.include?(table_name)

          columns = load_columns(table_name)
          indexes = load_indexes(table_name)
          options = load_table_options(table_name)

          tables[table_name] = Schema::TableDefinition.new(
            name:    table_name,
            columns: columns,
            indexes: indexes,
            options: options
          )
        end

        Schema::SchemaDefinition.new(tables: tables)
      end

      private

      def connection
        ActiveRecord::Base.connection
      end

      def load_columns(table_name)
        connection.columns(table_name).filter_map do |col|
          next if col.name == "id" && primary_key_column?(table_name, col)

          Schema::ColumnDefinition.new(
            name:    col.name,
            type:    col.type,
            options: column_options(col)
          )
        end
      end

      def column_options(col)
        opts = {}
        opts[:null]      = col.null          unless col.null == true
        opts[:default]   = col.default       unless col.default.nil?
        opts[:limit]     = col.limit         if col.limit
        opts[:precision] = col.precision     if col.precision
        opts[:scale]     = col.scale         if col.scale
        opts[:comment]   = col.comment       if col.respond_to?(:comment) && col.comment
        opts
      end

      def primary_key_column?(table_name, col)
        pk = connection.primary_key(table_name)
        pk == col.name
      end

      def load_indexes(table_name)
        connection.indexes(table_name).map do |idx|
          Schema::IndexDefinition.new(
            table_name: table_name,
            columns:    idx.columns,
            name:       idx.name,
            options:    index_options(idx)
          )
        end
      end

      def index_options(idx)
        opts = {}
        opts[:unique] = true if idx.unique
        opts[:where]  = idx.where   if idx.where
        opts[:using]  = idx.using   if idx.using && idx.using.to_sym != :btree
        opts
      end

      def load_table_options(table_name)
        opts = {}
        if connection.respond_to?(:table_comment)
          comment = connection.table_comment(table_name)
          opts[:comment] = comment if comment
        end
        opts
      end
    end
  end
end
