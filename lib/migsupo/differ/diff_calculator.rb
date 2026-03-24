require "set"
require_relative "diff"
require_relative "operations/create_table"
require_relative "operations/drop_table"
require_relative "operations/add_column"
require_relative "operations/remove_column"
require_relative "operations/change_column"
require_relative "operations/rename_column"
require_relative "operations/add_index"
require_relative "operations/remove_index"

module Migsupo
  module Differ
    class DiffCalculator
      def initialize(rename_hints: {})
        @rename_hints = rename_hints
      end

      def calculate(desired:, current:)
        operations = []

        desired_names = Set.new(desired.tables.keys)
        current_names = Set.new(current.tables.keys)

        (desired_names - current_names).each do |name|
          operations << Operations::CreateTable.new(desired.tables[name])
        end

        (current_names - desired_names).each do |name|
          operations << Operations::DropTable.new(current.tables[name])
        end

        (desired_names & current_names).each do |name|
          operations.concat(diff_table(desired.tables[name], current.tables[name]))
        end

        Diff.new(operations: operations)
      end

      private

      def diff_table(desired, current)
        operations = []
        operations.concat(diff_columns(desired, current))
        operations.concat(diff_indexes(desired, current))
        operations
      end

      def diff_columns(desired, current)
        desired_cols = desired.columns.each_with_object({}) { |c, h| h[c.name] = c }
        current_cols = current.columns.each_with_object({}) { |c, h| h[c.name] = c }

        added   = desired_cols.keys - current_cols.keys
        removed = current_cols.keys - desired_cols.keys

        hints = @rename_hints[desired.name] || {}
        operations = apply_rename_hints(desired.name, hints, added, removed, desired_cols, current_cols)

        # Remaining added/removed after renames
        renamed_old = operations.select { |op| op.is_a?(Operations::RenameColumn) }.map(&:old_name)
        renamed_new = operations.select { |op| op.is_a?(Operations::RenameColumn) }.map(&:new_name)

        (added - renamed_new).each do |name|
          operations << Operations::AddColumn.new(table_name: desired.name, column: desired_cols[name])
        end

        (removed - renamed_old).each do |name|
          operations << Operations::RemoveColumn.new(table_name: desired.name, column: current_cols[name])
        end

        (desired_cols.keys & current_cols.keys).each do |name|
          next if desired_cols[name] == current_cols[name]

          operations << Operations::ChangeColumn.new(
            table_name: desired.name,
            new_column:  desired_cols[name],
            old_column:  current_cols[name]
          )
        end

        operations
      end

      def apply_rename_hints(table_name, hints, added, removed, desired_cols, current_cols)
        operations = []
        hints.each do |old_name, new_name|
          next unless removed.include?(old_name) && added.include?(new_name)

          operations << Operations::RenameColumn.new(
            table_name: table_name,
            old_name:   old_name,
            new_name:   new_name
          )
        end
        operations
      end

      def diff_indexes(desired, current)
        desired_idxs = desired.indexes.each_with_object({}) { |i, h| h[i.name] = i }
        current_idxs = current.indexes.each_with_object({}) { |i, h| h[i.name] = i }

        operations = []

        (desired_idxs.keys - current_idxs.keys).each do |name|
          operations << Operations::AddIndex.new(table_name: desired.name, index: desired_idxs[name])
        end

        (current_idxs.keys - desired_idxs.keys).each do |name|
          operations << Operations::RemoveIndex.new(table_name: desired.name, index: current_idxs[name])
        end

        (desired_idxs.keys & current_idxs.keys).each do |name|
          next if desired_idxs[name] == current_idxs[name]

          operations << Operations::RemoveIndex.new(table_name: desired.name, index: current_idxs[name])
          operations << Operations::AddIndex.new(table_name: desired.name, index: desired_idxs[name])
        end

        operations
      end
    end
  end
end
