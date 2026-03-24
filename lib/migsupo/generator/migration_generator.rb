require_relative "naming"
require_relative "migration_builder"
require_relative "../differ/operations/create_table"
require_relative "../differ/operations/drop_table"

module Migsupo
  module Generator
    class MigrationGenerator
      def initialize(rails_version: nil)
        @rails_version = rails_version
        @builder       = MigrationBuilder.new(rails_version: rails_version)
      end

      def generate(diff, output_dir:, dry_run: false)
        return [] if diff.empty?

        base_ts = base_timestamp
        groups  = group_operations(diff.operations)
        files   = []

        groups.each_with_index do |ops, i|
          class_name = Naming.class_name(ops)
          timestamp  = (base_ts + i).to_s
          file_name  = Naming.file_name(timestamp: timestamp, class_name: class_name)
          content    = @builder.build(ops, class_name: class_name)

          if dry_run
            puts "# #{file_name}"
            puts content
            puts
          else
            file_path = File.join(output_dir, file_name)
            File.write(file_path, content)
            files << file_path
          end
        end

        files
      end

      private

      def group_operations(operations)
        groups = []

        create_ops = operations.select { |op| op.is_a?(Differ::Operations::CreateTable) }
        drop_ops   = operations.select { |op| op.is_a?(Differ::Operations::DropTable) }
        other_ops  = operations.reject { |op| op.is_a?(Differ::Operations::CreateTable) || op.is_a?(Differ::Operations::DropTable) }

        create_ops.each { |op| groups << [op] }
        drop_ops.each   { |op| groups << [op] }

        other_ops.group_by(&:table_name).each_value do |ops|
          groups << ops
        end

        groups
      end

      def base_timestamp
        Time.now.strftime("%Y%m%d%H%M%S").to_i
      end
    end
  end
end
