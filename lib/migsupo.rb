require_relative "migsupo/version"
require_relative "migsupo/configuration"
require_relative "migsupo/schema/column_definition"
require_relative "migsupo/schema/index_definition"
require_relative "migsupo/schema/table_definition"
require_relative "migsupo/schema/schema_definition"
require_relative "migsupo/parser/schemafile_parser"
require_relative "migsupo/loader/active_record_loader"
require_relative "migsupo/loader/schema_rb_loader"
require_relative "migsupo/differ/diff_calculator"
require_relative "migsupo/generator/migration_generator"

module Migsupo
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def calculate_diff(schemafile_path: nil, loader: nil)
      schemafile_path ||= configuration.schemafile_path
      loader          ||= configuration.loader

      desired = Parser::SchemafileParser.parse(schemafile_path)
      current = build_loader(loader).load_schema

      Differ::DiffCalculator.new(rename_hints: configuration.rename_hints)
                            .calculate(desired: desired, current: current)
    end

    def generate_migrations(diff, output_dir: nil, dry_run: false)
      output_dir ||= configuration.migrations_dir

      Generator::MigrationGenerator.new(rails_version: detect_rails_version)
                                   .generate(diff, output_dir: output_dir, dry_run: dry_run)
    end

    private

    def build_loader(loader)
      case loader.to_sym
      when :active_record
        Loader::ActiveRecordLoader.new(ignored_tables: configuration.ignored_tables)
      when :schema_rb
        Loader::SchemaRbLoader.new(
          schema_rb_path:  resolve_schema_rb_path,
          ignored_tables:  configuration.ignored_tables
        )
      else
        raise ArgumentError, "Unknown loader: #{loader}. Use :active_record or :schema_rb"
      end
    end

    def resolve_schema_rb_path
      if defined?(Rails)
        Rails.root.join("db", "schema.rb").to_s
      else
        "db/schema.rb"
      end
    end

    def detect_rails_version
      return configuration.migration_version if configuration.migration_version
      return nil unless defined?(Rails)

      major_minor = Rails::VERSION::STRING.split(".").first(2).join(".")
      major_minor
    end
  end
end

require_relative "migsupo/railtie" if defined?(Rails::Railtie)
