require_relative "dsl_context"

module Migsupo
  module Parser
    class SchemafileParser
      def self.parse(path)
        source = File.read(path)
        parse_string(source, path)
      end

      def self.parse_string(source, filename = "(string)")
        context = DslContext.new
        context.instance_eval(source, filename, 1)
        context.to_schema_definition
      end
    end
  end
end
