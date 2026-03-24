namespace :db do
  namespace :generate_migration do
    desc "Show diff between Schemafile and current DB schema without generating files"
    task diff: :environment do
      diff = Migsupo.calculate_diff(
        schemafile_path: ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path),
        loader:          ENV.fetch("LOADER", Migsupo.configuration.loader.to_s).to_sym
      )
      puts diff.to_s
    end

    desc "Exit with code 1 if Schemafile and current DB schema are not in sync"
    task check: :environment do
      diff = Migsupo.calculate_diff(
        schemafile_path: ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path),
        loader:          ENV.fetch("LOADER", Migsupo.configuration.loader.to_s).to_sym
      )
      if diff.empty?
        puts "Schema is in sync."
      else
        puts "Schema is out of sync:"
        puts diff.to_s
        exit 1
      end
    end
  end

  desc "Generate Rails migration files from diff between Schemafile and current DB schema"
  task generate_migration: :environment do
    schemafile_path = ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path)
    output_dir      = ENV.fetch("OUTPUT_DIR", Migsupo.configuration.migrations_dir)
    loader          = ENV.fetch("LOADER", Migsupo.configuration.loader.to_s).to_sym
    dry_run         = ENV["DRY_RUN"] == "true"
    verbose         = ENV["VERBOSE"] == "true"

    diff = Migsupo.calculate_diff(schemafile_path: schemafile_path, loader: loader)

    if diff.empty?
      puts "No changes detected. No migration files generated."
      next
    end

    if verbose
      puts "Detected changes:"
      puts diff.to_s
      puts
    end

    files = Migsupo.generate_migrations(diff, output_dir: output_dir, dry_run: dry_run)

    unless dry_run
      puts "Generated #{files.size} migration file(s):"
      files.each { |f| puts "  #{f}" }
    end
  end
end
