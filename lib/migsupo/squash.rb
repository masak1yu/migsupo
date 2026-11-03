require_relative "parser/schemafile_parser"
require_relative "generator/migration_builder"
require_relative "differ/operations/create_table"
require_relative "coherent"

module Migsupo
  # Collapses the whole migration history into a single Init migration built
  # from the Schemafile, then rewrites schema_migrations to match - no DDL.
  module Squash
    module_function

    # Built from the Schemafile, not the DB: the DB loader drops primary key
    # options (id: :uuid etc.), the Schemafile keeps them.
    def build(schemafile_path: nil, rails_version: nil)
      schemafile_path ||= Migsupo.configuration.schemafile_path
      schema = Parser::SchemafileParser.parse(schemafile_path)
      ops    = schema.tables.values.map { |table| Differ::Operations::CreateTable.new(table) }

      Generator::MigrationBuilder.new(rails_version: rails_version).build(ops, class_name: "Init")
    end

    # Deletes every migration file and writes <timestamp>_init.rb. Returns its path.
    def write(content, migrations_dir: nil)
      migrations_dir ||= Migsupo.configuration.migrations_dir
      Dir.glob(File.join(migrations_dir, "*.rb")).each { |path| File.delete(path) }

      path = File.join(migrations_dir, "#{Time.now.strftime('%Y%m%d%H%M%S')}_init.rb")
      File.write(path, content)
      path
    end

    # Replaces all history with the single version. Atomic so a failure
    # cannot leave schema_migrations empty.
    def rewrite_history(version)
      connection = Coherent.connection
      table = connection.quote_table_name("schema_migrations")

      connection.transaction do
        connection.execute("DELETE FROM #{table}")
        connection.execute("INSERT INTO #{table} (version) VALUES (#{connection.quote(version.to_s)})")
      end
    end
  end
end
