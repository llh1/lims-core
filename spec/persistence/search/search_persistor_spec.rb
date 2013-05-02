# Spec requirements
require 'persistence/spec_helper'

# Model requirements
require 'lims-core/persistence/search/search_persistor'

module Lims::Core
  module Persistence
    describe Search, :search => true, :persistence => true do
      context "to be valid" do
        let(:filter) { mock(:filter) }
        let(:model) { mock(:model) }
        let(:description) { mock(:description) }
        let(:create_parameters) {  {:description => description, :filter => filter, :model => model } }

        it "requires a model" do
          described_class.new(create_parameters - [:model]).valid?.should == false
        end

        it "requires a filter" do
          described_class.new(create_parameters - [:filter]).valid?.should == false
        end
        
        it "requires a description" do
          described_class.new(create_parameters - [:description]).valid?.should == false
        end

        it "requires a model and a filter" do
          described_class.new(create_parameters).valid?.should == true
        end
      end
    end
  end
end