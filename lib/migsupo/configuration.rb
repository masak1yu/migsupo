module Migsupo
  class Configuration
    attr_accessor :schemafile_path
    attr_accessor :migrations_dir
    attr_accessor :loader
    attr_accessor :ignored_tables
    attr_accessor :rename_hints
    attr_accessor :migration_version

    def initialize
      @schemafile_path   = "Schemafile"
      @migrations_dir    = "db/migrate"
      @loader            = :active_record
      @ignored_tables    = %w[schema_migrations ar_internal_metadata]
      @rename_hints      = {}
      @migration_version = nil
    end
  end
end
