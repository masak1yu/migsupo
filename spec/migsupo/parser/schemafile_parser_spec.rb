require "spec_helper"

RSpec.describe Migsupo::Parser::SchemafileParser do
  describe ".parse_string" do
    subject(:schema) { described_class.parse_string(source) }

    context "with a simple table" do
      let(:source) do
        <<~RUBY
          create_table "users" do |t|
            t.string "name", null: false
            t.string "email"
            t.integer "age"
            t.timestamps
          end
        RUBY
      end

      it "creates a SchemaDefinition with the users table" do
        expect(schema.tables).to have_key("users")
      end

      it "parses column names" do
        col_names = schema.tables["users"].columns.map(&:name)
        expect(col_names).to include("name", "email", "age", "created_at", "updated_at")
      end

      it "parses column types" do
        col = schema.tables["users"].column("name")
        expect(col.type).to eq(:string)
      end

      it "parses column options" do
        col = schema.tables["users"].column("name")
        expect(col.options[:null]).to eq(false)
      end
    end

    context "with add_index outside create_table" do
      let(:source) do
        <<~RUBY
          create_table "users" do |t|
            t.string "email"
          end

          add_index "users", ["email"], name: "index_users_on_email", unique: true
        RUBY
      end

      it "merges the index into the table definition" do
        idx = schema.tables["users"].index("index_users_on_email")
        expect(idx).not_to be_nil
        expect(idx.options[:unique]).to eq(true)
      end
    end

    context "with inline index inside create_table" do
      let(:source) do
        <<~RUBY
          create_table "posts" do |t|
            t.string "title"
            t.index ["title"], name: "index_posts_on_title"
          end
        RUBY
      end

      it "includes the inline index" do
        idx = schema.tables["posts"].index("index_posts_on_title")
        expect(idx).not_to be_nil
        expect(idx.columns).to eq(["title"])
      end
    end

    context "with multiple tables" do
      let(:source) do
        <<~RUBY
          create_table "users" do |t|
            t.string "name"
          end

          create_table "posts" do |t|
            t.string "title"
            t.references "user"
          end
        RUBY
      end

      it "parses both tables" do
        expect(schema.tables.keys).to contain_exactly("users", "posts")
      end

      it "expands references into a column" do
        col = schema.tables["posts"].column("user_id")
        expect(col).not_to be_nil
        expect(col.type).to eq(:bigint)
      end
    end
  end
end
