require "spec_helper"

RSpec.describe Migsupo::Schema::ColumnDefinition do
  describe "#==" do
    it "is equal when name, type, and options match" do
      a = described_class.new(name: "email", type: :string, options: { null: false })
      b = described_class.new(name: "email", type: :string, options: { null: false })
      expect(a).to eq(b)
    end

    it "is not equal when type differs" do
      a = described_class.new(name: "age", type: :integer)
      b = described_class.new(name: "age", type: :bigint)
      expect(a).not_to eq(b)
    end

    it "is not equal when options differ" do
      a = described_class.new(name: "email", type: :string, options: { null: false })
      b = described_class.new(name: "email", type: :string, options: { null: true })
      expect(a).not_to eq(b)
    end

    it "treats missing null option same as null: nil" do
      a = described_class.new(name: "x", type: :string, options: {})
      b = described_class.new(name: "x", type: :string, options: { null: nil })
      expect(a).to eq(b)
    end
  end
end
