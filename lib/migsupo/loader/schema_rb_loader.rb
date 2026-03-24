require_relative "../parser/dsl_context"

module Migsupo
  module Loader
    # Loads the current schema state from db/schema.rb without a live DB connection.
    # db/schema.rb uses the same create_table DSL as Schemafile, so we reuse DslContext.
    class SchemaRbLoader
      def initialize(schema_rb_path:, ignored_tables: [])
        @schema_rb_path = schema_rb_path
        @ignored_tables = ignored_tables
      end

      def load_schema
        source  = File.read(@schema_rb_path)
        context = Parser::DslContext.new
        context.instance_eval(source, @schema_rb_path, 1)
        schema  = context.to_schema_definition

        filtered_tables = schema.tables.reject { |name, _| @ignored_tables.include?(name) }
        Schema::SchemaDefinition.new(tables: filtered_tables)
      end
    end
  end
end
