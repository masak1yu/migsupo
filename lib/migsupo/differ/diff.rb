module Migsupo
  module Differ
    class Diff
      attr_reader :operations

      def initialize(operations: [])
        @operations = operations.freeze
        freeze
      end

      def empty?
        @operations.empty?
      end

      def to_s
        return "No changes." if empty?

        @operations.map(&:to_s).join("\n")
      end
    end
  end
end
