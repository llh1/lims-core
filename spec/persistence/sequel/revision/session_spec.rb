require 'persistence/sequel/revision/spec_helper'

require 'lims-core/persistence/user_session'
require 'lims-core/persistence/sequel/user_session_sequel_persistor'

shared_examples "retrieving user" do |session_id, email, name|
  context "for session # #{session_id}" do
    subject { for_session(session_id) { |session| session.user[1] } }
    it "has the correct email" do subject.email.should == email end
    it "has the correct name" do subject.name.name.should == name end
  end
end

shared_examples "retrieving all modified resources" do |session_id, resource_states|
  context "for session # #{session_id}" do
    subject { for_session(session_id) { |session| session.resource_states } }
      it "has the correct resources", :now=>true do
        subject.map { |state| [state.persistor.model, state.id] }.order.should == resource_states.order
      end
  end
end

module Lims::Core
  module Persistence
    module Sequel
      describe  Revision::Session do
        context "With sql test store" do
          include_context "sqlite db"
          include_context "with test store"

          let(:session_id) { 1 }
          subject { described_class.new(store, session_id)  }
          it "creates revision persistors" do
            subject.name.is_a?(Sequel::Persistor).should == true
            subject.name.is_a?(Sequel::Revision::Persistor).should == true
          end

          context "with object history" do
            def for_session(session_id)
              described_class.new(store, session_id).with_session do |session|
                yield session
              end

            end

            context "#single object" do
              before(:all) {
                # Create history table
                store.database.create_table :names_revision do
                  primary_key :internal_id
                  String :name
                  Integer :revision
                  String :action
                  Integer :session_id
                  Integer :id
                end

                store.database[:names_revision].multi_insert([
                    {"session_id" => 1, "id" => 1, "name" => "a", "revision" => 1, "action" => "insert" },
                    {"session_id" => 5, "id" => 1, "name" => "b",  "revision" => 2, "action" => "update" },
                    {"session_id" => 10, "id" => 1, "name" => nil, "revision" => 3, "action" => "delete" },
                    {"session_id" => 5, "id" => 2, "name" => "foo", "revision" => 1, "action" => "insert" },

                  ])

              }

              it "can read specific revision" do
                for_session(1) { |session| session.name[1].name.should == "a" }
                for_session(5) { |session| session.name[1].name.should == "b" }
                for_session(10) { |session| session.name[1].should == nil }
              end

              it "can read a greater revision" do
                for_session(4) { |session| session.name[1].name.should == "a" }
                for_session(6) { |session| session.name[1].name.should == "b" }
                for_session(20) do |session| session.name[1].should == nil 
                  session.name.revision_for(1).action.should == "delete"
                end
              end

              it "can read in bulk" do
                for_session(6) do |session|
                  names = session.name[[1, 2]] 
                  names.size.should == 2
                  names.map { |n| n.name}.should == ["b", "foo"]
                end
                for_session(1) do |session|
                  names = session.name[[1, 2]] 
                  names.size.should == 2
                  names.map { |n| n && n.name }.should == ["a", nil] 
                end
              end
            end

            context "#linked objects" do
              before(:all) {
                # Create history table
                store.database.create_table :names_revision do
                  primary_key :internal_id
                  String :name
                  Integer :revision
                  String :action
                  Integer :session_id
                  Integer :id
                end

                store.database.create_table :users_revision do
                  primary_key :internal_id
                  String :email
                  Integer :name_id
                  Integer :revision
                  String :action
                  Integer :session_id
                  Integer :id
                end

                store.database[:names_revision].multi_insert([
                    {"session_id" => 1, "id" => 1, "name" => "jon", "revision" => 1, "action" => "insert" },
                    {"session_id" => 2, "id" => 1, "name" => "john", "revision" => 2, "action" => "update" },
                    {"session_id" => 4, "id" => 2, "name" => "John", "revision" => 1, "action" => "insert" },

                  ])

                store.database[:users_revision].multi_insert([
                    { "session_id" => 1, "id" => 1, "name_id" => 1, "email" => "john.smith@example.com", "revision" => 1, "action" => "insert" },
                    { "session_id" => 3, "id" => 1, "name_id" => 1, "email" => "john.smith@gmail.com", "revision" => 2, "action" => "update" },
                    { "session_id" => 4, "id" => 1, "name_id" => 2, "email" => "john.smith@gmail.com", "revision" => 3, "action" => "update" },
                  ])

              }
              context "for a specific revision" do
                let(:name) { subject.name.name }
                it_behaves_like "retrieving user", 1, "john.smith@example.com", 'jon'
                it_behaves_like "retrieving user", 2, "john.smith@example.com", 'john'
                it_behaves_like "retrieving user", 3, "john.smith@gmail.com", 'john'
                it_behaves_like "retrieving user", 4, "john.smith@gmail.com", 'John'
                                                                                     
                it_behaves_like "retrieving all modified resources", 1, [[:name, 1], [:user, 1]]
                it_behaves_like "retrieving all modified resources", 2, [[:name, 1], [:user, 1]]
                it_behaves_like "retrieving all modified resources", 3, [[:name, 1], [:user, 1]]
                it_behaves_like "retrieving all modified resources", 4, [[:name, 2], [:user, 1]]
              end

              context "for a specific resource" do        
                def self.it_finds_correct_revision(model, resource_id, session_ids)
                  it "find the correct revision " do
                    store.with_session do |session|
                      resource_state = session.send(model).state_for_id(resource_id)
                      session.user_session.session_ids_for(resource_state).should ==  session_ids
                    end
                  end
                end
                it_finds_correct_revision :user, 1, [1, 2, 3, 4]
                it_finds_correct_revision :name, 1, [1, 2]
                it_finds_correct_revision :name, 2, [4]
              end
            end
          end
        end
      end
    end
  end
end
