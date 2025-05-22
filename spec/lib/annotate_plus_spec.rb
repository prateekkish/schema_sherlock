require "spec_helper"

RSpec.describe AnnotatePlus do
  it "has a version number" do
    expect(AnnotatePlus::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| AnnotatePlus.configure(&b) }.to yield_with_args(AnnotatePlus.configuration)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(AnnotatePlus.configuration).to be_a(AnnotatePlus::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      expect(AnnotatePlus.configuration).to be(AnnotatePlus.configuration)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      old_config = AnnotatePlus.configuration
      AnnotatePlus.reset_configuration!
      expect(AnnotatePlus.configuration).not_to be(old_config)
    end
  end
end