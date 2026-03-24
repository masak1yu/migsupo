require "spec_helper"

RSpec.describe Migsupo::Differ::DiffCalculator do
  let(:calculator) { described_class.new }

  def parse(source)
    Migsupo::Parser::SchemafileParser.parse_string(source)
  end

  describe "#calculate" do
    context "when a table is added" do
      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end
      let(:current) { parse("") }

      it "returns a CreateTable operation" do
        diff = calculator.calculate(desired: desired, current: current)
        expect(diff.operations.first).to be_a(Migsupo::Differ::Operations::CreateTable)
        expect(diff.operations.first.table_name).to eq("users")
      end
    end

    context "when a table is removed" do
      let(:desired) { parse("") }
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end

      it "returns a DropTable operation" do
        diff = calculator.calculate(desired: desired, current: current)
        expect(diff.operations.first).to be_a(Migsupo::Differ::Operations::DropTable)
        expect(diff.operations.first.table_name).to eq("users")
      end
    end

    context "when a column is added" do
      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
            t.string "email"
          end
        RUBY
      end
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end

      it "returns an AddColumn operation" do
        diff = calculator.calculate(desired: desired, current: current)
        op = diff.operations.find { |o| o.is_a?(Migsupo::Differ::Operations::AddColumn) }
        expect(op).not_to be_nil
        expect(op.column.name).to eq("email")
      end
    end

    context "when a column is removed" do
      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
            t.string "email"
          end
        RUBY
      end

      it "returns a RemoveColumn operation" do
        diff = calculator.calculate(desired: desired, current: current)
        op = diff.operations.find { |o| o.is_a?(Migsupo::Differ::Operations::RemoveColumn) }
        expect(op).not_to be_nil
        expect(op.column_name).to eq("email")
      end
    end

    context "when a column type changes" do
      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.bigint "age"
          end
        RUBY
      end
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.integer "age"
          end
        RUBY
      end

      it "returns a ChangeColumn operation" do
        diff = calculator.calculate(desired: desired, current: current)
        op = diff.operations.find { |o| o.is_a?(Migsupo::Differ::Operations::ChangeColumn) }
        expect(op).not_to be_nil
        expect(op.new_column.type).to eq(:bigint)
        expect(op.old_column.type).to eq(:integer)
      end
    end

    context "when an index is added" do
      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "email"
          end
          add_index "users", ["email"], name: "index_users_on_email", unique: true
        RUBY
      end
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "email"
          end
        RUBY
      end

      it "returns an AddIndex operation" do
        diff = calculator.calculate(desired: desired, current: current)
        op = diff.operations.find { |o| o.is_a?(Migsupo::Differ::Operations::AddIndex) }
        expect(op).not_to be_nil
        expect(op.index.name).to eq("index_users_on_email")
      end
    end

    context "with rename_hints configured" do
      let(:calculator) { described_class.new(rename_hints: { "users" => { "full_name" => "name" } }) }

      let(:desired) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end
      let(:current) do
        parse(<<~RUBY)
          create_table "users" do |t|
            t.string "full_name"
          end
        RUBY
      end

      it "returns a RenameColumn operation instead of add+remove" do
        diff = calculator.calculate(desired: desired, current: current)
        expect(diff.operations.map(&:class)).to include(Migsupo::Differ::Operations::RenameColumn)
        expect(diff.operations.map(&:class)).not_to include(Migsupo::Differ::Operations::AddColumn)
        expect(diff.operations.map(&:class)).not_to include(Migsupo::Differ::Operations::RemoveColumn)
      end
    end

    context "when schemas are identical" do
      let(:source) do
        <<~RUBY
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      end

      it "returns an empty diff" do
        schema = parse(source)
        diff = calculator.calculate(desired: schema, current: schema)
        expect(diff).to be_empty
      end
    end
  end
end
