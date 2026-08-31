require_relative "migration_builder"

module Migsupo
  module Generator
    # Renders a SchemaDefinition back out as Schemafile DSL.
    # Only what migsupo models (tables / columns / indexes) is emitted, so the
    # output always round-trips through SchemafileParser.
    class SchemafileDumper
      def initialize
        @builder = MigrationBuilder.new
      end

      def dump(schema)
        "#{schema.tables.values.map { |table| @builder.build_table(table) }.join("\n\n")}\n"
      end
    end
  end
end
