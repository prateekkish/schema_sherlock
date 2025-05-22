require "rails/engine"

module AnnotatePlus
  class Engine < Rails::Engine
    isolate_namespace AnnotatePlus

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end