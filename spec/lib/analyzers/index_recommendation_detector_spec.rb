require 'spec_helper'
require_relative '../../../lib/schema_sherlock/analyzers/index_recommendation_detector'

RSpec.describe SchemaSherlock::Analyzers::IndexRecommendationDetector do
  let(:mock_model_class) { double('ModelClass') }
  let(:mock_connection) { double('ActiveRecord::Connection') }
  let(:detector) { described_class.new(mock_model_class) }

  before do
    allow(mock_model_class).to receive(:name).and_return('Post')
    allow(mock_model_class).to receive(:table_name).and_return('posts')
    allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
  end

  describe '#analyze' do
    let(:columns) do
      [
        double('Column', name: 'id', type: :integer),
        double('Column', name: 'user_id', type: :integer),
        double('Column', name: 'category_id', type: :integer),
        double('Column', name: 'title', type: :string),
        double('Column', name: 'created_at', type: :datetime),
        double('Column', name: 'updated_at', type: :datetime)
      ]
    end

    let(:existing_indexes) { [] }
    before do
      allow(mock_model_class).to receive(:columns).and_return(columns)
      allow(mock_connection).to receive(:table_exists?).with('posts').and_return(true)
      allow(mock_connection).to receive(:indexes).with('posts').and_return(existing_indexes)
    end

    it 'analyzes and returns structured results' do
      detector.analyze

      expect(detector.results).to have_key(:missing_foreign_key_indexes)
    end

    context 'when foreign keys have no indexes' do
      it 'identifies missing foreign key indexes' do
        detector.analyze

        missing_indexes = detector.results[:missing_foreign_key_indexes]
        expect(missing_indexes.length).to eq(2)

        user_id_index = missing_indexes.find { |idx| idx[:column] == 'user_id' }
        expect(user_id_index).to include(
          column: 'user_id',
          table: 'posts',
          migration: 'add_index :posts, :user_id',
          reason: 'Foreign key without index'
        )

        category_id_index = missing_indexes.find { |idx| idx[:column] == 'category_id' }
        expect(category_id_index).to include(
          column: 'category_id',
          table: 'posts',
          migration: 'add_index :posts, :category_id',
          reason: 'Foreign key without index'
        )
      end

      it 'includes all foreign keys without indexes' do
        detector.analyze

        missing_indexes = detector.results[:missing_foreign_key_indexes]
        expect(missing_indexes.length).to eq(2)
        
        expect(missing_indexes.map { |idx| idx[:column] }).to contain_exactly('user_id', 'category_id')
        expect(missing_indexes.all? { |idx| idx[:reason] == 'Foreign key without index' }).to be true
      end
    end

    context 'when some indexes already exist' do
      let(:existing_indexes) do
        [
          double('Index', columns: ['user_id'])
        ]
      end

      it 'excludes columns that already have indexes' do
        detector.analyze

        missing_indexes = detector.results[:missing_foreign_key_indexes]
        expect(missing_indexes.length).to eq(1)
        expect(missing_indexes.first[:column]).to eq('category_id')
      end
    end

  end

  describe 'private methods' do
    let(:columns) do
      [
        double('Column', name: 'id', type: :integer),
        double('Column', name: 'user_id', type: :integer),
        double('Column', name: 'category_id', type: :integer),
        double('Column', name: 'created_at', type: :datetime),
        double('Column', name: 'published_at', type: :datetime),
        double('Column', name: 'title', type: :string)
      ]
    end

    before do
      allow(mock_model_class).to receive(:columns).and_return(columns)
    end

    describe '#foreign_key_columns' do
      it 'identifies foreign key columns correctly' do
        fk_columns = detector.send(:foreign_key_columns)
        
        expect(fk_columns.map(&:name)).to contain_exactly('user_id', 'category_id')
      end

      it 'excludes the primary key id column' do
        fk_columns = detector.send(:foreign_key_columns)
        
        expect(fk_columns.map(&:name)).not_to include('id')
      end
    end

    describe '#has_index_on_column?' do
      let(:existing_indexes) do
        [
          double('Index', columns: ['user_id']),
          double('Index', columns: ['user_id', 'created_at'])
        ]
      end

      before do
        allow(mock_connection).to receive(:table_exists?).with('posts').and_return(true)
        allow(mock_connection).to receive(:indexes).with('posts').and_return(existing_indexes)
      end

      it 'returns true for columns with single-column indexes' do
        expect(detector.send(:has_index_on_column?, 'user_id')).to be true
      end

      it 'returns false for columns without single-column indexes' do
        expect(detector.send(:has_index_on_column?, 'category_id')).to be false
      end

      it 'returns false for columns that only appear in composite indexes' do
        existing_indexes.clear
        existing_indexes << double('Index', columns: ['user_id', 'created_at'])
        
        expect(detector.send(:has_index_on_column?, 'user_id')).to be false
      end
    end

  end
end