require_relative "schema_sherlock/version"
require_relative "schema_sherlock/configuration"
require_relative "schema_sherlock/railtie" if defined?(Rails)

module SchemaSherlock
  class Error < StandardError; end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end