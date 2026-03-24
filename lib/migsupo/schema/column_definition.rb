module Migsupo
  module Schema
    class ColumnDefinition
      attr_reader :name, :type, :options

      COMPARABLE_OPTIONS = %i[null default limit precision scale comment].freeze

      def initialize(name:, type:, options: {})
        @name    = name.to_s
        @type    = type.to_sym
        @options = normalize_options(options)
        freeze
      end

      def ==(other)
        return false unless other.is_a?(ColumnDefinition)

        name == other.name && type == other.type && comparable_options == other.comparable_options
      end

      alias eql? ==

      def hash
        [name, type, comparable_options].hash
      end

      def to_h
        { name: name, type: type, options: options }
      end

      def comparable_options
        options.slice(*COMPARABLE_OPTIONS).reject { |_, v| v.nil? }
      end

      private

      def normalize_options(opts)
        opts.transform_keys(&:to_sym).freeze
      end
    end
  end
end
