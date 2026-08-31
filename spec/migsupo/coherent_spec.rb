require "spec_helper"
require "tempfile"

RSpec.describe Migsupo::Coherent do
  def column(name, type, **options)
    Migsupo::Schema::ColumnDefinition.new(name: name, type: type, options: options)
  end

  def schema_with(*columns)
    table = Migsupo::Schema::TableDefinition.new(name: "users", columns: columns)
    Migsupo::Schema::SchemaDefinition.new(tables: { "users" => table })
  end

  describe ".diff" do
    it "treats the DB as truth: a column only in the DB becomes add_column, not remove_column" do
      allow(described_class).to receive(:actual_schema)
        .and_return(schema_with(column("name", :string), column("nickname", :string)))

      file = Tempfile.new("Schemafile")
      file.write(<<~SCHEMA)
        create_table "users" do |t|
          t.string "name"
        end
      SCHEMA
      file.flush

      diff = described_class.diff(schemafile_path: file.path)

      expect(diff.operations.size).to eq(1)
      expect(diff.operations.first).to be_a(Migsupo::Differ::Operations::AddColumn)
      expect(diff.operations.first.column.name).to eq("nickname")
    ensure
      file&.close!
    end
  end
end

RSpec.describe Migsupo::Generator::SchemafileDumper do
  it "dumps a schema that parses back into the same schema" do
    table = Migsupo::Schema::TableDefinition.new(
      name:    "users",
      columns: [
        Migsupo::Schema::ColumnDefinition.new(name: "name", type: :string, options: { null: false }),
        Migsupo::Schema::ColumnDefinition.new(name: "age", type: :integer)
      ],
      indexes: [
        Migsupo::Schema::IndexDefinition.new(
          table_name: "users", columns: ["name"], name: "index_users_on_name", options: { unique: true }
        )
      ]
    )
    schema = Migsupo::Schema::SchemaDefinition.new(tables: { "users" => table })

    reparsed = Migsupo::Parser::SchemafileParser.parse_string(described_class.new.dump(schema))

    expect(reparsed.table("users").columns).to eq(table.columns)
    expect(reparsed.table("users").index("index_users_on_name").columns).to eq(["name"])
  end
end
