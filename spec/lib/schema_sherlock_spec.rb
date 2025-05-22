require "spec_helper"

RSpec.describe SchemaSherlock do
  it "has a version number" do
    expect(SchemaSherlock::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| SchemaSherlock.configure(&b) }.to yield_with_args(SchemaSherlock.configuration)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(SchemaSherlock.configuration).to be_a(SchemaSherlock::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      expect(SchemaSherlock.configuration).to be(SchemaSherlock.configuration)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      old_config = SchemaSherlock.configuration
      SchemaSherlock.reset_configuration!
      expect(SchemaSherlock.configuration).not_to be(old_config)
    end
  end
end