require "rails/railtie"

module Migsupo
  class Railtie < Rails::Railtie
    railtie_name :migsupo

    rake_tasks do
      load File.join(__dir__, "tasks", "migsupo.rake")
    end
  end
end
