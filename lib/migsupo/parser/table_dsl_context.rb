require_relative "../schema/column_definition"
require_relative "../schema/index_definition"
require_relative "../schema/table_definition"

module Migsupo
  module Parser
    class TableDslContext
      COLUMN_TYPES = %i[
        string text integer bigint float decimal boolean
        date datetime time timestamp binary blob json jsonb
        uuid hstore inet cidr macaddr bit varbit
        virtual primary_key
      ].freeze

      def initialize(table_name, options = {})
        @table_name = table_name.to_s
        @options    = options
        @columns    = []
        @indexes    = []
      end

      COLUMN_TYPES.each do |type|
        define_method(type) do |*names, **opts|
          names.each { |name| add_column(name, type, opts) }
        end
      end

      def column(name, type, **opts)
        add_column(name, type, opts)
      end

      def references(name, **opts)
        polymorphic = opts.delete(:polymorphic)
        index_opt   = opts.delete(:index) { true }
        foreign_key = opts.delete(:foreign_key)

        col_type = opts.delete(:type) { :bigint }
        add_column("#{name}_id", col_type, opts)

        if polymorphic
          add_column("#{name}_type", :string, {})
          if index_opt
            add_index_entry([@table_name, "#{name}_type", "#{name}_id"],
                            name: "index_#{@table_name}_on_#{name}_type_and_#{name}_id")
          end
        elsif index_opt
          idx_opts = index_opt.is_a?(Hash) ? index_opt : {}
          add_index_entry(["#{name}_id"], idx_opts)
        end
      end

      alias belongs_to references

      def timestamps(**opts)
        precision = opts.fetch(:precision, nil)
        col_opts  = precision ? { precision: precision } : {}
        col_opts[:null] = opts[:null] if opts.key?(:null)
        add_column("created_at", :datetime, col_opts)
        add_column("updated_at", :datetime, col_opts)
      end

      def index(columns, **opts)
        add_index_entry(Array(columns).map(&:to_s), opts)
      end

      def to_table_definition
        Schema::TableDefinition.new(
          name:    @table_name,
          columns: @columns,
          indexes: @indexes,
          options: @options
        )
      end

      private

      def add_column(name, type, opts)
        @columns << Schema::ColumnDefinition.new(name: name.to_s, type: type, options: opts)
      end

      def add_index_entry(columns, opts)
        columns = columns.map(&:to_s)
        @indexes << Schema::IndexDefinition.new(
          table_name: @table_name,
          columns:    columns,
          name:       opts.delete(:name),
          options:    opts
        )
      end
    end
  end
end
