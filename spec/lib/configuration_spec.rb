require "spec_helper"

RSpec.describe AnnotatePlus::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.analyze_query_logs).to be false
      expect(config.suggest_indexes).to be true
      expect(config.detect_unused_associations).to be true
      expect(config.annotation_position).to eq :top
      expect(config.exclude_models).to eq ['ActiveRecord::Base']
      expect(config.min_usage_threshold).to eq 3
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting analyze_query_logs" do
      config.analyze_query_logs = true
      expect(config.analyze_query_logs).to be true
    end

    it "allows setting and getting suggest_indexes" do
      config.suggest_indexes = false
      expect(config.suggest_indexes).to be false
    end

    it "allows setting and getting detect_unused_associations" do
      config.detect_unused_associations = false
      expect(config.detect_unused_associations).to be false
    end

    it "allows setting and getting annotation_position" do
      config.annotation_position = :bottom
      expect(config.annotation_position).to eq :bottom
    end

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