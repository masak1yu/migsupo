# Migsupo

Migsupo is a Rails gem that generates migration files from the diff between a **Schemafile** (your desired schema) and the current database state.

It is inspired by [ridgepole](https://github.com/ridgepole/ridgepole) but with a key difference: instead of applying schema changes directly to the database, Migsupo generates standard Rails migration files that you can review, modify, and run through the normal `rails db:migrate` workflow.

## How It Works

```
Schemafile          →  migsupo  →  db/migrate/*.rb  →  rails db:migrate  →  DB
(desired state)                    (auto-generated)                          ↓
                                                                      db/schema.rb
                                                                      (managed by Rails)
```

You define your desired schema in a `Schemafile` using the same DSL as ridgepole. Migsupo compares it against the current database and generates migration files for any differences.

### File Responsibilities

| File | Managed by | Purpose |
|---|---|---|
| `Schemafile` | You | Declares the desired schema state |
| `db/migrate/*.rb` | Migsupo (generated) + you (reviewed) | Incremental changes to apply |
| `db/schema.rb` | Rails | Snapshot of the current schema after migrations — do not edit manually |

The `Schemafile` and `db/schema.rb` are intentionally separate. Rails owns `db/schema.rb` and keeps it in sync after every `rails db:migrate`. The `Schemafile` is yours to manage — Rails never touches it.

## Installation

Add to your `Gemfile`:

```ruby
gem "migsupo"
```

Then run:

```bash
bundle install
```

## Getting Started

### 1. Create a Schemafile

Create a `Schemafile` in your Rails root. For existing projects, you can use `db/schema.rb` as a reference — copy the `create_table` and `add_index` blocks as-is (without the `ActiveRecord::Schema.define` wrapper).

```bash
# Example: use schema.rb as a starting point
grep -v "ActiveRecord::Schema\|^end$\|^#\|version:" db/schema.rb > Schemafile
```

From this point on, the `Schemafile` is yours to manage. Rails will not touch it.

### 2. Edit the Schemafile to describe your desired schema

```ruby
# Schemafile

create_table "users", force: :cascade do |t|
  t.string  "name",  null: false
  t.string  "email", null: false
  t.integer "age"
  t.timestamps
end

add_index "users", ["email"], name: "index_users_on_email", unique: true

create_table "posts", force: :cascade do |t|
  t.string     "title",   null: false
  t.text       "body"
  t.references "user"
  t.timestamps
end
```

### 3. Generate migration files

```bash
rails db:generate_migration
```

Migsupo compares the Schemafile against the current database and writes migration files to `db/migrate/`.

### 4. Review and run migrations

```bash
# Review the generated files
cat db/migrate/20260324120000_create_users.rb

# Apply to the database
rails db:migrate
```

## Commands

### `rails db:generate_migration`

Generate migration files for all differences between the Schemafile and the current database.

```bash
rails db:generate_migration
rails db:generate_migration SCHEMAFILE=db/Schemafile
rails db:generate_migration OUTPUT_DIR=db/migrate
rails db:generate_migration DRY_RUN=true    # print to stdout, no files written
rails db:generate_migration VERBOSE=true    # also print diff summary
```

### `rails db:generate_migration:diff`

Print a human-readable diff between the Schemafile and the current database. No files are written.

```bash
rails db:generate_migration:diff
```

### `rails db:generate_migration:check`

Exit with code 1 if the Schemafile and the current database are not in sync. Useful in CI pipelines.

```bash
rails db:generate_migration:check
```

### `rails db:coherent` / `rails db:coherent:apply`

Adopt a hand-made database change as the truth. See [coherent](#coherent--when-the-db-was-changed-by-hand).

## `coherent` — when the DB was changed by hand

Sometimes someone edits the database directly — an emergency `ALTER TABLE` in production, say — and that state is the one you want to keep. The normal flow cannot express this: the Schemafile is behind, and running a migration to catch up would touch columns that are already correct.

`coherent` takes the **DB as the source of truth** and moves everything else up to it: it writes the migration file that *would* have produced the change (so every other environment gets it through the normal `rails db:migrate`), updates the Schemafile, and then records the migration as applied on this database **without executing it**.

```
DB (hand-edited, = truth)
  ├─ db:coherent        → db/migrate/*.rb (generated) + Schemafile (updated)
  └─ db:coherent:apply  → INSERT INTO schema_migrations   ← columns untouched
                          db/schema.rb re-dumped
```

### 1. Generate

```bash
rails db:coherent
```

```
Adopting the following from the database:
add_column users.nickname (string)

Generated migration(s):
  db/migrate/20260901120000_add_columns_to_users.rb
Updated Schemafile: Schemafile

Review them, then record the history without touching the database:
  rails db:coherent:apply VERSION=20260901120000
```

The diff runs in the opposite direction from `db:generate_migration`: the DB is the desired state and the Schemafile is the current one, so a column that exists only in the DB comes out as `add_column`, not `remove_column`.

### 2. Review, then rewrite history only

```bash
rails db:coherent:apply VERSION=20260901120000
```

This inserts the version into `schema_migrations` and re-dumps `db/schema.rb`. No DDL is executed — the columns are already where they should be.

`VERSION` is required (comma-separate several). Run without it to list the pending migrations. Before writing anything, `apply` re-checks that the DB and the Schemafile match: if they do not, the migration genuinely needs to run and the task aborts.

### On other environments

Nothing special. `db/migrate/*.rb` is a normal migration, so staging and production pick it up with `rails db:migrate`.

### Caveats

- `db:coherent` regenerates the whole Schemafile from the DB, so hand-written comments and ordering in it are lost. Review the diff (`git diff Schemafile`) before committing.
- `rename_hints` are not applied — a column renamed by hand comes out as `remove_column` + `add_column`.
- Only what migsupo models is tracked: tables, columns, indexes. Foreign keys, extensions and check constraints are neither diffed nor written to the Schemafile.
- Primary key options (`id: :uuid`, `primary_key: "uid"`) are not read back from the database, so the regenerated Schemafile drops them. Diffs are unaffected — table options are not compared — but re-add them by hand if you ever recreate the table from the Schemafile.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SCHEMAFILE` | `Schemafile` | Path to the Schemafile |
| `OUTPUT_DIR` | `db/migrate` | Output directory for generated migration files |
| `LOADER` | `activerecord` | Schema loader: `activerecord` or `schema_rb` |
| `DRY_RUN` | `false` | Print migrations to stdout instead of writing files |
| `VERBOSE` | `false` | Print diff summary before generating files |

### Loaders

- **`activerecord`** (default): Reads the current schema directly from the database via `ActiveRecord::Base.connection`. Always reflects the true current state.
- **`schema_rb`**: Reads from `db/schema.rb` without a live database connection. Useful for offline environments, but only as accurate as the last `rails db:migrate` run.

## Configuration

You can configure Migsupo in an initializer:

```ruby
# config/initializers/migsupo.rb
Migsupo.configure do |config|
  config.schemafile_path   = Rails.root.join("db/Schemafile")
  config.migrations_dir    = Rails.root.join("db/migrate")
  config.ignored_tables    = %w[schema_migrations ar_internal_metadata]
  config.migration_version = "7.1"  # defaults to current Rails version

  # Explicit rename hints (see "Column Renames" below)
  config.rename_hints = {
    "users" => { "full_name" => "name" }
  }
end
```

## Generated Migration Examples

### New table

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :age

      t.timestamps
    end

    add_index :users, [:email], name: "index_users_on_email", unique: true
  end
end
```

### Add columns

```ruby
class AddColumnsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :phone, :string
    add_index  :users, [:phone], name: "index_users_on_phone"
  end
end
```

### Change column type (uses explicit `up`/`down`)

```ruby
class ModifyUsers < ActiveRecord::Migration[7.1]
  def up
    change_column :users, :age, :bigint
  end

  def down
    change_column :users, :age, :integer
  end
end
```

## Column Renames

Migsupo cannot automatically distinguish a rename from a drop + add, so rename detection is **opt-in** via `rename_hints`. Without a hint, Migsupo will emit `remove_column` + `add_column`, which would cause data loss.

```ruby
# config/initializers/migsupo.rb
Migsupo.configure do |config|
  config.rename_hints = {
    "users" => { "full_name" => "name" }
  }
end
```

This generates `rename_column` instead of `remove_column` + `add_column`.

## CI Integration

Use `db:generate_migration:check` to verify that your Schemafile and database are always in sync after all migrations have been applied:

```yaml
# .github/workflows/ci.yml
- name: Check schema sync
  run: bundle exec rails db:generate_migration:check
```

## Comparison with ridgepole

| | ridgepole | migsupo |
|---|---|---|
| Schema definition | Schemafile | Schemafile (compatible) |
| How changes are applied | Directly to DB | Generates Rails migration files |
| Rails migration workflow | Bypassed | Preserved |
| Rollback support | No | Yes (via `rails db:rollback`) |
| Review before applying | Not built-in | Yes (review generated files) |

## Requirements

- Ruby >= 3.0
- Rails >= 6.1

## License

MIT
