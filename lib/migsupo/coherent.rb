require_relative "parser/schemafile_parser"
require_relative "loader/active_record_loader"
require_relative "differ/diff_calculator"
require_relative "generator/schemafile_dumper"

module Migsupo
  # For the case where the DB was changed by hand and that state is now the
  # truth. Coherent brings the Schemafile and the migration history up to the
  # DB without touching a single column.
  module Coherent
    module_function

    # desired/current are swapped on purpose: the migration has to move the
    # declared state up to what the DB already looks like.
    # ponytail: rename_hints point the other way here, so they are dropped -
    # a hand-renamed column comes out as remove + add.
    def diff(schemafile_path: nil)
      schemafile_path ||= Migsupo.configuration.schemafile_path
      declared = Parser::SchemafileParser.parse(schemafile_path)

      Differ::DiffCalculator.new.calculate(desired: actual_schema, current: declared)
    end

    def dump_schemafile(path: nil)
      path ||= Migsupo.configuration.schemafile_path
      File.write(path, Generator::SchemafileDumper.new.dump(actual_schema))
      path
    end

    # Writes history only - no DDL is executed. Returns the versions inserted.
    def mark_applied(versions)
      applied = applied_versions
      inserted = versions.map(&:to_s) - applied

      table = connection.quote_table_name("schema_migrations")
      inserted.each do |version|
        connection.execute("INSERT INTO #{table} (version) VALUES (#{connection.quote(version)})")
      end
      inserted
    end

    def applied_versions
      connection.select_values(
        "SELECT version FROM #{connection.quote_table_name('schema_migrations')}"
      ).map(&:to_s)
    end

    # [version, filename] for every migration file not yet in schema_migrations.
    def pending(migrations_dir = nil)
      migrations_dir ||= Migsupo.configuration.migrations_dir
      applied = applied_versions

      migration_files(migrations_dir).reject { |version, _| applied.include?(version) }
    end

    def migration_files(migrations_dir)
      Dir.glob(File.join(migrations_dir, "*.rb")).sort.filter_map do |path|
        version = File.basename(path)[/\A\d+/]
        [version, File.basename(path)] if version
      end
    end

    def actual_schema
      Loader::ActiveRecordLoader.new(ignored_tables: Migsupo.configuration.ignored_tables).load_schema
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
