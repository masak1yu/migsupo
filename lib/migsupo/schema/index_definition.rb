module Migsupo
  module Schema
    class IndexDefinition
      attr_reader :table_name, :columns, :name, :options

      def initialize(table_name:, columns:, name: nil, options: {})
        @table_name = table_name.to_s
        @columns    = Array(columns).map(&:to_s).freeze
        @options    = options.transform_keys(&:to_sym).freeze
        @name       = (name || generate_name).to_s
        freeze
      end

      def ==(other)
        return false unless other.is_a?(IndexDefinition)

        name == other.name &&
          table_name == other.table_name &&
          columns == other.columns &&
          comparable_options == other.comparable_options
      end

      alias eql? ==

      def hash
        [table_name, name].hash
      end

      def to_h
        { table_name: table_name, columns: columns, name: name, options: options }
      end

      def comparable_options
        options.reject { |k, _| k == :name }
      end

      private

      def generate_name
        "index_#{table_name}_on_#{columns.join('_and_')}"
      end
    end
  end
end
