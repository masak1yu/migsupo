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
      puts "DB と Schemafile に差分はありません。coherent は不要です。"
      next
    end

    puts "DB を正として以下を取り込みます:"
    puts diff.to_s
    puts

    files = Migsupo.generate_migrations(diff, output_dir: output_dir, dry_run: dry_run)
    next if dry_run

    Migsupo::Coherent.dump_schemafile(path: schemafile_path)
    versions = files.map { |f| File.basename(f)[/\A\d+/] }

    puts "生成したマイグレーション:"
    files.each { |f| puts "  #{f}" }
    puts "更新した Schemafile: #{schemafile_path}"
    puts
    puts "内容を確認したうえで、DB を変更せず履歴だけを進めるには:"
    puts "  rails db:coherent:apply VERSION=#{versions.join(',')}"
  end

  namespace :coherent do
    desc "Mark the given migrations as applied without running them (VERSION=ts[,ts...])"
    task apply: :environment do
      schemafile_path = ENV.fetch("SCHEMAFILE", Migsupo.configuration.schemafile_path)
      output_dir      = ENV.fetch("OUTPUT_DIR", Migsupo.configuration.migrations_dir)
      versions        = ENV["VERSION"].to_s.split(",").map(&:strip).reject(&:empty?)

      if versions.empty?
        puts "VERSION を指定してください (例: VERSION=20260901120000)。"
        pending = Migsupo::Coherent.pending(output_dir)
        if pending.empty?
          puts "未適用のマイグレーションはありません。"
        else
          puts "未適用のマイグレーション:"
          pending.each { |version, name| puts "  #{version}  #{name}" }
        end
        exit 1
      end

      known = Migsupo::Coherent.migration_files(output_dir).to_h
      unknown = versions.reject { |v| known.key?(v) }
      unless unknown.empty?
        puts "#{output_dir} に該当するマイグレーションがありません: #{unknown.join(', ')}"
        exit 1
      end

      # 履歴だけを進める前提は「DB が既に Schemafile どおりである」こと。
      # 差分が残っていれば、そのマイグレーションは本当に実行が必要ということ。
      diff = Migsupo::Coherent.diff(schemafile_path: schemafile_path)
      unless diff.empty?
        puts "DB と Schemafile が一致していません。先に rails db:coherent を実行してください:"
        puts diff.to_s
        exit 1
      end

      inserted = Migsupo::Coherent.mark_applied(versions)
      skipped  = versions - inserted

      inserted.each { |v| puts "適用済みとして記録: #{v}  #{known[v]}" }
      skipped.each  { |v| puts "既に記録済みのためスキップ: #{v}  #{known[v]}" }

      Rake::Task["db:schema:dump"].invoke
      puts "db/schema.rb を更新しました。"
    end
  end
end
