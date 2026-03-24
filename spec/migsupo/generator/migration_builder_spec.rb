require "spec_helper"

RSpec.describe Migsupo::Generator::MigrationBuilder do
  let(:builder) { described_class.new(rails_version: "7.1") }

  def parse(source)
    Migsupo::Parser::SchemafileParser.parse_string(source)
  end

  def calculate_diff(desired_src, current_src)
    desired = parse(desired_src)
    current = parse(current_src)
    Migsupo::Differ::DiffCalculator.new.calculate(desired: desired, current: current)
  end

  describe "#build for CreateTable" do
    let(:diff) do
      calculate_diff(
        <<~RUBY,
          create_table "users" do |t|
            t.string "name", null: false
            t.string "email"
            t.timestamps
          end
          add_index "users", ["email"], name: "index_users_on_email", unique: true
        RUBY
        ""
      )
    end

    subject(:output) { builder.build(diff.operations, class_name: "CreateUsers") }

    it "generates a valid migration class" do
      expect(output).to include("class CreateUsers < ActiveRecord::Migration[7.1]")
    end

    it "uses change method for reversible migrations" do
      expect(output).to include("def change")
      expect(output).not_to include("def up")
    end

    it "includes create_table" do
      expect(output).to include("create_table")
    end

    it "includes timestamps" do
      expect(output).to include("t.timestamps")
    end

    it "includes add_index" do
      expect(output).to include("add_index")
      expect(output).to include("unique: true")
    end
  end

  describe "#build for AddColumn" do
    let(:diff) do
      calculate_diff(
        <<~RUBY,
          create_table "users" do |t|
            t.string "name"
            t.string "email"
          end
        RUBY
        <<~RUBY
          create_table "users" do |t|
            t.string "name"
          end
        RUBY
      )
    end

    subject(:output) { builder.build(diff.operations, class_name: "AddColumnsToUsers") }

    it "uses change method" do
      expect(output).to include("def change")
    end

    it "includes add_column" do
      expect(output).to include('add_column "users", "email", :string')
    end
  end

  describe "#build for ChangeColumn" do
    let(:diff) do
      calculate_diff(
        <<~RUBY,
          create_table "users" do |t|
            t.bigint "age"
          end
        RUBY
        <<~RUBY
          create_table "users" do |t|
            t.integer "age"
          end
        RUBY
      )
    end

    subject(:output) { builder.build(diff.operations, class_name: "ModifyUsers") }

    it "uses up/down methods (irreversible)" do
      expect(output).to include("def up")
      expect(output).to include("def down")
    end

    it "includes change_column in up" do
      expect(output).to match(/def up.*change_column.*:bigint/m)
    end

    it "includes change_column reversal in down" do
      expect(output).to match(/def down.*change_column.*:integer/m)
    end
  end
end
