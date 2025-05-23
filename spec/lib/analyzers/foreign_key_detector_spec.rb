require "spec_helper"
require_relative "../../../lib/schema_sherlock/analyzers/foreign_key_detector"

RSpec.describe SchemaSherlock::Analyzers::ForeignKeyDetector do
  let(:model_class) { double("ModelClass") }
  let(:detector) { described_class.new(model_class) }
  let(:connection) { double("ActiveRecord::Connection") }

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    allow(model_class).to receive(:table_name).and_return("test_table")
    allow(model_class).to receive(:name).and_return("TestModel")
    allow(model_class).to receive(:reflect_on_all_associations).and_return([])
  end

  describe "#analyze" do
    let(:user_id_column) { double("Column", name: "user_id", type: :integer) }
    let(:category_id_column) { double("Column", name: "category_id", type: :integer) }
    let(:fake_id_column) { double("Column", name: "fake_id", type: :integer) }
    let(:id_column) { double("Column", name: "id", type: :integer) }

    before do
      allow(model_class).to receive(:columns).and_return([user_id_column, category_id_column, fake_id_column, id_column])
    end

    context "when all _id columns are valid foreign keys" do
      before do
        # Mock valid foreign keys
        allow(detector).to receive(:valid_foreign_key?).with(user_id_column).and_return(true)
        allow(detector).to receive(:valid_foreign_key?).with(category_id_column).and_return(true)
        allow(detector).to receive(:valid_foreign_key?).with(fake_id_column).and_return(false)

        # Mock table existence
        allow(connection).to receive(:table_exists?).with("users").and_return(true)
        allow(connection).to receive(:table_exists?).with("categories").and_return(true)
        allow(connection).to receive(:table_exists?).with("fakes").and_return(false)
        
        # Mock usage tracker
        allow(SchemaSherlock::UsageTracker).to receive(:track_foreign_key_usage)
          .with(model_class)
          .and_return({
            "user_id" => 5,
            "category_id" => 3
          })
      end

      it "only includes valid foreign key columns" do
        detector.analyze

        missing_associations = detector.results[:missing_associations]
        expect(missing_associations.map { |ma| ma[:column] }).to contain_exactly("user_id", "category_id")
        expect(missing_associations.map { |ma| ma[:column] }).not_to include("fake_id")
      end
    end
  end

  describe "#valid_foreign_key?" do
    let(:user_id_column) { double("Column", name: "user_id", type: :integer) }
    let(:user_model) { double("User") }
    let(:id_column) { double("Column", name: "id", type: :integer) }

    context "when referenced table exists and has compatible primary key" do
      before do
        allow(detector).to receive(:infer_table_name).with(user_id_column).and_return("users")
        allow(connection).to receive(:table_exists?).with("users").and_return(true)

        # Mock the fallback path (let constantize fail and use direct table inspection)
        allow(connection).to receive(:primary_key).with("users").and_return("id")
        allow(connection).to receive(:columns).with("users").and_return([id_column])
        allow(detector).to receive(:compatible_types?).with(user_id_column, id_column).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:valid_foreign_key?, user_id_column)).to be true
      end
    end

    context "when referenced table does not exist" do
      before do
        allow(detector).to receive(:infer_table_name).with(user_id_column).and_return("users")
        allow(connection).to receive(:table_exists?).with("users").and_return(false)
      end

      it "returns false" do
        expect(detector.send(:valid_foreign_key?, user_id_column)).to be false
      end
    end

    context "when model class cannot be found but table exists" do
      before do
        allow(detector).to receive(:infer_table_name).with(user_id_column).and_return("users")
        allow(connection).to receive(:table_exists?).with("users").and_return(true)
        allow("users".classify).to receive(:constantize).and_raise(NameError)
        allow(detector).to receive(:check_table_primary_key).with("users", user_id_column).and_return(true)
      end

      it "falls back to checking table structure directly" do
        expect(detector.send(:valid_foreign_key?, user_id_column)).to be true
      end
    end
  end

  describe "#compatible_types?" do
    context "when both columns are integer types" do
      let(:fk_column) { double("Column", type: :integer) }
      let(:pk_column) { double("Column", type: :bigint) }

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when both columns are bigint" do
      let(:fk_column) { double("Column", type: :bigint) }
      let(:pk_column) { double("Column", type: :bigint) }

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when both columns are UUID types" do
      let(:fk_column) { double("Column", type: :uuid) }
      let(:pk_column) { double("Column", type: :uuid) }

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when string foreign key references UUID primary key" do
      let(:fk_column) { double("Column", type: :string) }
      let(:pk_column) { double("Column", type: :uuid) }

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when UUID foreign key references string primary key" do
      let(:fk_column) { double("Column", type: :uuid) }
      let(:pk_column) { double("Column", type: :string) }

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when both columns are strings and likely UUIDs" do
      let(:fk_column) { double("Column", type: :string, name: "user_uuid_id") }
      let(:pk_column) { double("Column", type: :string, name: "uuid") }

      before do
        allow(detector).to receive(:likely_uuid_column?).with(fk_column, pk_column).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be true
      end
    end

    context "when both columns are strings but not likely UUIDs" do
      let(:fk_column) { double("Column", type: :string, name: "user_name_id") }
      let(:pk_column) { double("Column", type: :string, name: "name") }

      before do
        allow(detector).to receive(:likely_uuid_column?).with(fk_column, pk_column).and_return(false)
      end

      it "returns false" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be false
      end
    end

    context "when one column is string and other is integer" do
      let(:fk_column) { double("Column", type: :string) }
      let(:pk_column) { double("Column", type: :integer) }

      it "returns false" do
        expect(detector.send(:compatible_types?, fk_column, pk_column)).to be false
      end
    end
  end

  describe "#check_table_primary_key" do
    let(:user_id_column) { double("Column", name: "user_id", type: :integer) }
    let(:id_column) { double("Column", name: "id", type: :integer) }

    context "when table has compatible primary key" do
      before do
        allow(connection).to receive(:table_exists?).with("users").and_return(true)
        allow(connection).to receive(:primary_key).with("users").and_return("id")
        allow(connection).to receive(:columns).with("users").and_return([id_column])
        allow(detector).to receive(:compatible_types?).with(user_id_column, id_column).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:check_table_primary_key, "users", user_id_column)).to be true
      end
    end

    context "when table has no primary key" do
      before do
        allow(connection).to receive(:table_exists?).with("users").and_return(true)
        allow(connection).to receive(:primary_key).with("users").and_return(nil)
      end

      it "returns false" do
        expect(detector.send(:check_table_primary_key, "users", user_id_column)).to be false
      end
    end

    context "when there's an error accessing table structure" do
      before do
        allow(connection).to receive(:table_exists?).with("users").and_return(true)
        allow(connection).to receive(:primary_key).with("users").and_raise(StandardError.new("Table error"))
      end

      it "returns false" do
        expect(detector.send(:check_table_primary_key, "users", user_id_column)).to be false
      end
    end
  end

  describe "#foreign_key_columns" do
    let(:user_id_column) { double("Column", name: "user_id", type: :integer) }
    let(:category_id_column) { double("Column", name: "category_id", type: :integer) }
    let(:fake_id_column) { double("Column", name: "fake_id", type: :integer) }
    let(:id_column) { double("Column", name: "id", type: :integer) }
    let(:name_column) { double("Column", name: "name", type: :string) }

    before do
      allow(model_class).to receive(:columns).and_return([
        user_id_column, category_id_column, fake_id_column, id_column, name_column
      ])
    end

    context "when filtering by valid foreign keys" do
      before do
        allow(detector).to receive(:valid_foreign_key?).with(user_id_column).and_return(true)
        allow(detector).to receive(:valid_foreign_key?).with(category_id_column).and_return(true)
        allow(detector).to receive(:valid_foreign_key?).with(fake_id_column).and_return(false)
      end

      it "only returns columns ending in _id that are valid foreign keys" do
        result = detector.send(:foreign_key_columns)
        expect(result).to contain_exactly(user_id_column, category_id_column)
      end

      it "excludes the primary key column 'id'" do
        result = detector.send(:foreign_key_columns)
        expect(result).not_to include(id_column)
      end

      it "excludes columns not ending in _id" do
        result = detector.send(:foreign_key_columns)
        expect(result).not_to include(name_column)
      end

      it "excludes invalid foreign key columns" do
        result = detector.send(:foreign_key_columns)
        expect(result).not_to include(fake_id_column)
      end
    end
  end

  describe "#likely_uuid_column?" do
    context "when both columns have UUID-length limits" do
      let(:fk_column) { double("Column", name: "user_id", limit: 36) }
      let(:pk_column) { double("Column", name: "id", limit: 36) }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(true)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be true
      end
    end

    context "when one column has 32-char limit (UUID without dashes)" do
      let(:fk_column) { double("Column", name: "user_id", limit: 32) }
      let(:pk_column) { double("Column", name: "id", limit: 36) }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(true)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be true
      end
    end

    context "when column names contain 'uuid'" do
      let(:fk_column) { double("Column", name: "user_uuid_id", limit: nil) }
      let(:pk_column) { double("Column", name: "uuid", limit: nil) }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(true)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be true
      end
    end

    context "when column names contain 'guid'" do
      let(:fk_column) { double("Column", name: "user_guid_id", limit: nil) }
      let(:pk_column) { double("Column", name: "id", limit: nil) }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(true)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(true)
      end

      it "returns true" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be true
      end
    end

    context "when columns don't match UUID patterns" do
      let(:fk_column) { double("Column", name: "user_name_id", limit: 255) }
      let(:pk_column) { double("Column", name: "name", limit: 255) }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(true)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(true)
      end

      it "returns false" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be false
      end
    end

    context "when columns don't respond to limit" do
      let(:fk_column) { double("Column", name: "user_id") }
      let(:pk_column) { double("Column", name: "id") }

      before do
        allow(fk_column).to receive(:respond_to?).with(:limit).and_return(false)
        allow(pk_column).to receive(:respond_to?).with(:limit).and_return(false)
      end

      it "falls back to name pattern matching" do
        expect(detector.send(:likely_uuid_column?, fk_column, pk_column)).to be false
      end
    end
  end
end