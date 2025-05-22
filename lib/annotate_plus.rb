require_relative "annotate_plus/version"
require_relative "annotate_plus/configuration"
require_relative "annotate_plus/railtie" if defined?(Rails)

module AnnotatePlus
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