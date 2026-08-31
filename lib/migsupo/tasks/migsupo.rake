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

namespace :db do
  desc "Take the current DB as truth: generate migrations for hand-made changes and update the Schemafile"
  task coherent: :environment do
    schemafile_path = ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path)
    output_dir      = ENV.fetch("OUTPUT_DIR", Migsupo.configuration.migrations_dir)
    dry_run         = ENV["DRY_RUN"] == "true"

    diff = Migsupo::Coherent.diff(schemafile_path: schemafile_path)

    if diff.empty?
      puts "No differences between the database and the Schemafile. Nothing for coherent to do."
      next
    end

    puts "Adopting the following from the database:"
    puts diff.to_s
    puts

    files = Migsupo.generate_migrations(diff, output_dir: output_dir, dry_run: dry_run)
    next if dry_run

    Migsupo::Coherent.dump_schemafile(path: schemafile_path)
    versions = files.map { |f| File.basename(f)[/\A\d+/] }

    puts "Generated migration(s):"
    files.each { |f| puts "  #{f}" }
    puts "Updated Schemafile: #{schemafile_path}"
    puts
    puts "Review them, then record the history without touching the database:"
    puts "  rails db:coherent:apply VERSION=#{versions.join(',')}"
  end

  namespace :coherent do
    desc "Mark the given migrations as applied without running them (VERSION=ts[,ts...])"
    task apply: :environment do
      schemafile_path = ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path)
      output_dir      = ENV.fetch("OUTPUT_DIR", Migsupo.configuration.migrations_dir)
      versions        = ENV["VERSION"].to_s.split(",").map(&:strip).reject(&:empty?)

      if versions.empty?
        puts "VERSION is required (e.g. VERSION=20260901120000)."
        pending = Migsupo::Coherent.pending(output_dir)
        if pending.empty?
          puts "No pending migrations."
        else
          puts "Pending migrations:"
          pending.each { |version, name| puts "  #{version}  #{name}" }
        end
        exit 1
      end

      known = Migsupo::Coherent.migration_files(output_dir).to_h
      unknown = versions.reject { |v| known.key?(v) }
      unless unknown.empty?
        puts "No migration found in #{output_dir} for: #{unknown.join(', ')}"
        exit 1
      end

      # Recording history only is sound when the DB already matches the
      # Schemafile. A remaining diff means the migration genuinely needs to run.
      diff = Migsupo::Coherent.diff(schemafile_path: schemafile_path)
      unless diff.empty?
        puts "The database and the Schemafile do not match. Run rails db:coherent first:"
        puts diff.to_s
        exit 1
      end

      inserted = Migsupo::Coherent.mark_applied(versions)
      skipped  = versions - inserted

      inserted.each { |v| puts "Recorded as applied: #{v}  #{known[v]}" }
      skipped.each  { |v| puts "Already recorded, skipped: #{v}  #{known[v]}" }

      Rake::Task["db:schema:dump"].invoke
      puts "Updated db/schema.rb."
    end
  end
end
