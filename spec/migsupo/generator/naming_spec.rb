require "spec_helper"

RSpec.describe Migsupo::Generator::Naming do
  describe ".class_name" do
    def make_op(migration_type, table_name)
      double("op", migration_type: migration_type, table_name: table_name)
    end

    it "returns CreateXxx for create_table" do
      ops = [make_op(:create_table, "users")]
      expect(described_class.class_name(ops)).to eq("CreateUsers")
    end

    it "returns DropXxx for drop_table" do
      ops = [make_op(:drop_table, "users")]
      expect(described_class.class_name(ops)).to eq("DropUsers")
    end

    it "returns AddColumnsToXxx for add_column only" do
      ops = [make_op(:add_column, "users"), make_op(:add_column, "users")]
      expect(described_class.class_name(ops)).to eq("AddColumnsToUsers")
    end

    it "returns RemoveColumnsFromXxx for remove_column only" do
      ops = [make_op(:remove_column, "users")]
      expect(described_class.class_name(ops)).to eq("RemoveColumnsFromUsers")
    end

    it "returns ModifyXxx for mixed operations on one table" do
      ops = [make_op(:add_column, "users"), make_op(:change_column, "users")]
      expect(described_class.class_name(ops)).to eq("ModifyUsers")
    end

    it "returns SchemaChanges for operations spanning multiple tables" do
      ops = [make_op(:add_column, "users"), make_op(:add_column, "posts")]
      expect(described_class.class_name(ops)).to eq("SchemaChanges")
    end
  end

  describe ".file_name" do
    it "formats timestamp_class_name.rb" do
      result = described_class.file_name(timestamp: "20240101120000", class_name: "CreateUsers")
      expect(result).to eq("20240101120000_create_users.rb")
    end
  end

  describe ".underscore" do
    it "converts CamelCase to snake_case" do
      expect(described_class.underscore("CreateUsers")).to eq("create_users")
      expect(described_class.underscore("AddColumnsToUsers")).to eq("add_columns_to_users")
      expect(described_class.underscore("SchemaChanges")).to eq("schema_changes")
    end
  end
end
