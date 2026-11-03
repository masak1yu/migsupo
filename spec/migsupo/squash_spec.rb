require "spec_helper"
require "tmpdir"

RSpec.describe Migsupo::Squash do
  let(:schemafile) do
    <<~SCHEMA
      create_table "users", id: :uuid do |t|
        t.string "name", null: false
      end
      add_index "users", ["name"], name: "index_users_on_name"

      create_table "posts" do |t|
        t.text "body"
      end
    SCHEMA
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      File.write(File.join(dir, "Schemafile"), schemafile)
      example.run
    end
  end

  describe ".build" do
    it "renders every Schemafile table into one Init migration, keeping table options" do
      content = described_class.build(schemafile_path: File.join(@dir, "Schemafile"), rails_version: "7.1")

      expect(content).to start_with("class Init < ActiveRecord::Migration[7.1]")
      expect(content).to include('create_table "users", id: :uuid do |t|')
      expect(content).to include('add_index "users", ["name"], name: "index_users_on_name"')
      expect(content).to include('create_table "posts" do |t|')
    end
  end

  describe ".write" do
    it "replaces all existing migration files with a single *_init.rb" do
      File.write(File.join(@dir, "20260101000000_create_users.rb"), "")
      File.write(File.join(@dir, "20260102000000_add_columns_to_users.rb"), "")

      path = described_class.write("content", migrations_dir: @dir)

      expect(Dir.glob(File.join(@dir, "*.rb"))).to eq([path])
      expect(File.basename(path)).to match(/\A\d{14}_init\.rb\z/)
    end
  end
end
