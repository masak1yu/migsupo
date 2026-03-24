require_relative "../differ/operations/create_table"
require_relative "../differ/operations/drop_table"
require_relative "../differ/operations/add_column"
require_relative "../differ/operations/remove_column"
require_relative "../differ/operations/change_column"
require_relative "../differ/operations/rename_column"
require_relative "../differ/operations/add_index"
require_relative "../differ/operations/remove_index"

module Migsupo
  module Generator
    class MigrationBuilder
      def initialize(rails_version: nil)
        @rails_version = rails_version
      end

      def build(operations, class_name:)
        all_reversible = operations.all?(&:reversible?)

        body = if all_reversible
                 indent("def change\n#{indent(render_operations(operations))}\nend", 2)
               else
                 up   = indent("def up\n#{indent(render_operations(operations, direction: :up))}\nend", 2)
                 down = indent("def down\n#{indent(render_operations(operations, direction: :down))}\nend", 2)
                 "#{up}\n\n#{down}"
               end

        <<~RUBY
          class #{class_name} < ActiveRecord::Migration#{version_suffix}
          #{body}
          end
        RUBY
      end

      private

      def version_suffix
        return "" unless @rails_version

        "[#{@rails_version}]"
      end

      def render_operations(operations, direction: :change)
        operations.map { |op| render_operation(op, direction: direction) }.join("\n")
      end

      def render_operation(op, direction:)
        case op
        when Differ::Operations::CreateTable
          render_create_table(op)
        when Differ::Operations::DropTable
          render_drop_table(op, direction: direction)
        when Differ::Operations::AddColumn
          direction == :down ? render_remove_column_from_add(op) : render_add_column(op)
        when Differ::Operations::RemoveColumn
          direction == :down ? render_add_column_from_remove(op) : render_remove_column(op)
        when Differ::Operations::ChangeColumn
          direction == :down ? render_change_column(op, column: op.old_column) : render_change_column(op, column: op.new_column)
        when Differ::Operations::RenameColumn
          direction == :down ? render_rename_column(op, reverse: true) : render_rename_column(op)
        when Differ::Operations::AddIndex
          direction == :down ? render_remove_index(op.table_name, op.index) : render_add_index(op.table_name, op.index)
        when Differ::Operations::RemoveIndex
          direction == :down ? render_add_index(op.table_name, op.index) : render_remove_index(op.table_name, op.index)
        else
          "# Unknown operation: #{op.class}"
        end
      end

      def render_create_table(op)
        table   = op.table
        opts    = table_options_str(table.options.reject { |k, _| k == :force })
        columns = table.columns.map { |col| "  #{render_column_in_table(col)}" }.join("\n")

        idx_lines = table.indexes.map { |idx| render_add_index(table.name, idx) }.join("\n")

        lines = ["create_table #{table.name.inspect}#{opts} do |t|"]
        lines << collapse_timestamps(table.columns, columns)
        lines << "end"
        lines << idx_lines unless idx_lines.empty?
        lines.join("\n")
      end

      def collapse_timestamps(columns, rendered)
        col_names = columns.map(&:name)
        if col_names.include?("created_at") && col_names.include?("updated_at")
          created = columns.find { |c| c.name == "created_at" }
          updated = columns.find { |c| c.name == "updated_at" }
          if created.type == :datetime && updated.type == :datetime &&
             created.comparable_options.empty? && updated.comparable_options.empty?
            rendered
              .gsub(/\s*t\.datetime :created_at[^\n]*\n/, "")
              .gsub(/\s*t\.datetime :updated_at[^\n]*/, "")
              .sub(/\n*$/, "\n\n  t.timestamps")
          else
            rendered
          end
        else
          rendered
        end
      end

      def render_drop_table(op, direction:)
        if direction == :down
          render_create_table(Operations::CreateTable.new(op.table))
        else
          "drop_table #{op.table_name.inspect}"
        end
      end

      def render_add_column(op)
        col  = op.column
        opts = column_options_str(col.options)
        "add_column #{op.table_name.inspect}, #{col.name.inspect}, :#{col.type}#{opts}"
      end

      def render_remove_column(op)
        col  = op.column
        opts = column_options_str(col.options.merge(type: col.type))
        "remove_column #{op.table_name.inspect}, #{col.name.inspect}#{opts}"
      end

      def render_remove_column_from_add(op)
        "remove_column #{op.table_name.inspect}, #{op.column.name.inspect}"
      end

      def render_add_column_from_remove(op)
        col  = op.column
        opts = column_options_str(col.options)
        "add_column #{op.table_name.inspect}, #{col.name.inspect}, :#{col.type}#{opts}"
      end

      def render_change_column(op, column:)
        opts = column_options_str(column.options)
        "change_column #{op.table_name.inspect}, #{column.name.inspect}, :#{column.type}#{opts}"
      end

      def render_rename_column(op, reverse: false)
        old_name = reverse ? op.new_name : op.old_name
        new_name = reverse ? op.old_name : op.new_name
        "rename_column #{op.table_name.inspect}, #{old_name.inspect}, #{new_name.inspect}"
      end

      def render_add_index(table_name, idx)
        cols = idx.columns.map(&:inspect).join(", ")
        opts = index_options_str(idx)
        "add_index #{table_name.inspect}, [#{cols}]#{opts}"
      end

      def render_remove_index(table_name, idx)
        "remove_index #{table_name.inspect}, name: #{idx.name.inspect}"
      end

      def render_column_in_table(col)
        opts = column_options_str(col.options)
        "t.#{col.type} #{col.name.inspect}#{opts}"
      end

      def column_options_str(opts)
        return "" if opts.nil? || opts.empty?

        pairs = opts.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        ", #{pairs}"
      end

      def table_options_str(opts)
        return "" if opts.nil? || opts.empty?

        pairs = opts.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        ", #{pairs}"
      end

      def index_options_str(idx)
        opts = idx.comparable_options
        opts[:name] = idx.name
        pairs = opts.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        ", #{pairs}"
      end

      def indent(str, spaces = 2)
        str.lines.map { |line| line.chomp.empty? ? line : ("  " * (spaces / 2)) + line }.join
      end
    end
  end
end
