require "spec_helper"

RSpec.describe SchemaSherlock::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.exclude_models).to eq ['ActiveRecord::Base']
      expect(config.min_usage_threshold).to eq 3
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting exclude_models" do
      config.exclude_models = ['User', 'Post']
      expect(config.exclude_models).to eq ['User', 'Post']
    end

    it "allows setting and getting min_usage_threshold" do
      config.min_usage_threshold = 5
      expect(config.min_usage_threshold).to eq 5
    end
  end
end