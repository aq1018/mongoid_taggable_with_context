require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class MyModel
  include Mongoid::Document
  include Mongoid::TaggableWithContext
    
  taggable
  taggable :artists
  taggable :albums, :default => []
end

class M1
  include Mongoid::Document
  include Mongoid::TaggableWithContext
  include Mongoid::TaggableWithContext::AggregationStrategy::MapReduce
  
  taggable
  taggable :artists
end

class M2
  include Mongoid::Document
  include Mongoid::TaggableWithContext
  include Mongoid::TaggableWithContext::AggregationStrategy::RealTime
  
  taggable
  taggable :artists
end

class M3
  include Mongoid::Document
  include Mongoid::TaggableWithContext::GroupBy::AggregationStrategy::RealTime

  field :user
  taggable :group_by_field => :user
  taggable :artists, :group_by_field => :user
end

describe Mongoid::TaggableWithContext do

  context "default field value" do
    before :each do
      @m = MyModel.new
    end

    it "should be nil for artists" do
      @m.changes['artists'].should be_nil
    end

    it "should be array for albums" do
      @m.changes['albums_array'].should eql([nil, []])
    end
  end

  context "saving tags from plain text" do
    before :each do
      @m = MyModel.new
    end

    it "should set tags array from string" do
      @m.tags = "some new tag"
      @m.tags_array.should == %w[some new tag]
    end
    
    it "should set artists array from string" do
      @m.artists = "some new tag"
      @m.artists_array.should == %w[some new tag]
    end

    it "should retrieve tags string from array" do
      @m.tags_array = %w[some new tags]
      @m.tags.should == "some new tags"
    end
    
    it "should retrieve artists string from array" do
      @m.artists_array = %w[some new tags]
      @m.artists.should == "some new tags"
    end

    it "should strip tags before put in array" do
      @m.tags = "now   with   some spaces   in places "
      @m.tags_array.should == %w[now with some spaces in places]
    end
    
    it "should remove repeated tags from string" do
      @m.tags = "some new tags some new tags"
      @m.tags_array.should == %w[some new tags]
    end
    
    it "should remove repeated tags from array" do
      @m.tags_array = %w[some new tags some new tags]
      @m.tags.should == "some new tags"
    end
    
    it "should remove nil tags from array" do
      @m.tags_array = ["some", nil, "new", nil, "tags"]
      @m.tags.should == "some new tags"
    end
  end

  context "saving tags from array" do
    before :each do
      @m = MyModel.new
    end
    
    it "should remove repeated tags from array" do
      @m.tags_array = %w[some new tags some new tags]
      @m.tags_array == %w[some new tags]
    end
    
    it "should remove nil tags from array" do
      @m.tags_array = ["some", nil, "new", nil, "tags"]
      @m.tags_array.should == %w[some new tags]
    end

    it "should remove empty strings from array" do
      @m.tags_array = ["some", "", "new", "", "tags"]
      @m.tags_array.should == %w[some new tags]
    end
  end

  context "changing separator" do
    before :all do
      MyModel.tags_separator = ";"
    end

    after :all do
      MyModel.tags_separator = " "
    end

    before :each do
      @m = MyModel.new
    end

    it "should split with custom separator" do
      @m.tags = "some;other;separator"
      @m.tags_array.should == %w[some other separator]
    end

    it "should join with custom separator" do
      @m.tags_array = %w[some other sep]
      @m.tags.should == "some;other;sep"
    end
  end
  
  context "tagged_with" do
    before :each do
      @m1 = MyModel.create!(:tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
      @m2 = MyModel.create!(:tags => "juice food bee zip", :artists => "grant andrew andy")
      @m3 = MyModel.create!(:tags => "honey strip food", :artists => "mandy aaron andy")
    end
    
    it "should retrieve a list of documents" do
      (MyModel.tags_tagged_with("food").to_a - [@m1, @m2, @m3]).should be_empty
      (MyModel.artists_tagged_with("aaron").to_a - [@m1, @m3]).should be_empty
    end
  end
  
  context "no aggregation" do
    it "should raise AggregationStrategyMissing exception when retreiving tags" do
      lambda{ MyModel.tags }.should raise_error(Mongoid::TaggableWithContext::AggregationStrategyMissing)
    end
    
    it "should raise AggregationStrategyMissing exception when retreiving tags with weights" do
      lambda{ MyModel.tags_with_weight }.should raise_error(Mongoid::TaggableWithContext::AggregationStrategyMissing)
    end
    
  end
  
  shared_examples_for "aggregation" do
    context "retrieving index" do
      context "when there's no tags'" do
        it "should return an empty array" do
          klass.tags.should == []
          klass.artists.should == []

          klass.tags_with_weight.should == []
          klass.artists_with_weight == []
        end
      end

      context "on create directly" do
        before :each do
          klass.create!(:user => "user1", :tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          klass.create!(:user => "user1", :tags => "juice food bee zip", :artists => "grant andrew andy")
          klass.create!(:user => "user2", :tags => "honey strip food", :artists => "mandy aaron andy")
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          klass.tags.should == %w[ant bee food honey juice strip zip]
          klass.artists.should == %w[aaron andrew andy grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          klass.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 1],
            ['juice', 1],
            ['strip', 1],
            ['zip', 1]
          ]
        
          klass.artists_with_weight.should == [
            ['aaron', 2],
            ['andrew', 1],
            ['andy', 3],
            ['grant', 1],
            ['greg', 1],
            ['jeff', 1],
            ['mandy', 2]
          ]
        end
      end
      
      context "on new then change attributes directly" do
        before :each do
          m = klass.new
          m.tags = "food ant bee"
          m.artists = "jeff greg mandy aaron andy"
          m.save!
          
          m = klass.new
          m.tags = "juice food bee zip"
          m.artists = "grant andrew andy"
          m.save!

          m = klass.new
          m.tags = "honey strip food"
          m.artists = "mandy aaron andy"
          m.save!
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          klass.tags.should == %w[ant bee food honey juice strip zip]
          klass.artists.should == %w[aaron andrew andy grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          klass.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 1],
            ['juice', 1],
            ['strip', 1],
            ['zip', 1]
          ]
        
          klass.artists_with_weight.should == [
            ['aaron', 2],
            ['andrew', 1],
            ['andy', 3],
            ['grant', 1],
            ['greg', 1],
            ['jeff', 1],
            ['mandy', 2]
          ]
        end
      end
      
      context "on create then update" do
        before :each do
          m1 = klass.create!(:user => "user1", :tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          m2 = klass.create!(:user => "user1", :tags => "juice food bee zip", :artists => "grant andrew andy")
          m3 = klass.create!(:user => "user2", :tags => "honey strip food", :artists => "mandy aaron andy")
          
          m1.tags_array = m1.tags_array + %w[honey strip shoe]
          m1.save!
          
          m3.artists_array = m3.artists_array + %w[grant greg gory]
          m3.save!
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          klass.tags.should == %w[ant bee food honey juice shoe strip zip]
          klass.artists.should == %w[aaron andrew andy gory grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          klass.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 2],
            ['juice', 1],
            ['shoe', 1],
            ['strip', 2],
            ['zip', 1]
          ]
        
          klass.artists_with_weight.should == [
            ['aaron', 2],
            ['andrew', 1],
            ['andy', 3],
            ['gory', 1],
            ['grant', 2],
            ['greg', 2],
            ['jeff', 1],
            ['mandy', 2]
          ]
        end
      end

      context "on create, update, then destroy" do
        before :each do
          m1 = klass.create!(:user => "user1", :tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          m2 = klass.create!(:user => "user1", :tags => "juice food bee zip", :artists => "grant andrew andy")
          m3 = klass.create!(:user => "user2", :tags => "honey strip food", :artists => "mandy aaron andy")
          
          m1.tags_array = m1.tags_array + %w[honey strip shoe] - %w[food]
          m1.save!
          
          m3.artists_array = m3.artists_array + %w[grant greg gory] - %w[andy]
          m3.save!
          
          m2.destroy
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          klass.tags.should == %w[ant bee food honey shoe strip]
          klass.artists.should == %w[aaron andy gory grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          klass.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 1],
            ['food', 1],
            ['honey', 2],
            ['shoe', 1],
            ['strip', 2]
          ]
        
          klass.artists_with_weight.should == [
            ['aaron', 2],
            ['andy', 1],
            ['gory', 1],
            ['grant', 1],
            ['greg', 2],
            ['jeff', 1],
            ['mandy', 2]
          ]
        end
      end
    end
  end

  context "map-reduce aggregation" do
    let(:klass) { M1 }
    it_should_behave_like "aggregation"

    it "should generate the tags aggregation collection name correctly" do
      klass.aggregation_collection_for(:tags).should == "m1s_tags_aggregation"
    end
    
    it "should generate the artists aggregation collection name correctly" do
      klass.aggregation_collection_for(:artists).should == "m1s_artists_aggregation"
    end
  end
  
  context "realtime aggregation" do
    let(:klass) { M2 }
    it_should_behave_like "aggregation"

    it "should generate the tags aggregation collection name correctly" do
      klass.aggregation_collection_for(:tags).should == "m2s_tags_aggregation"
    end
    
    it "should generate the artists aggregation collection name correctly" do
      klass.aggregation_collection_for(:artists).should == "m2s_artists_aggregation"
    end
  end

  context "realtime aggregation group by" do
    let(:klass) { M3 }
    it_should_behave_like "aggregation"

    it "should generate the tags aggregation collection name correctly" do
      klass.aggregation_collection_for(:tags).should == "m3s_tags_aggregation"
    end

    it "should generate the artists aggregation collection name correctly" do
      klass.aggregation_collection_for(:artists).should == "m3s_artists_aggregation"
    end

    context "for groupings" do
      before :each do
        klass.create!(:user => "user1", :tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
        klass.create!(:user => "user1", :tags => "juice food bee zip", :artists => "grant andrew andy")
        klass.create!(:user => "user2", :tags => "honey strip food", :artists => "mandy aaron andy")
      end

      it "should retrieve the list of all saved tags distinct and ordered" do
        klass.tags("user1").should == %w[ant bee food juice zip]
        klass.tags("user2").should == %w[food honey strip]

        klass.artists("user1").should == %w[aaron andrew andy grant greg jeff mandy]
        klass.artists("user2").should == %w[aaron andy mandy]
      end

      it "should retrieve a list of tags with weight" do
        klass.tags_with_weight("user1").should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 2],
            ['juice', 1],
            ['zip', 1]
        ]

        klass.tags_with_weight("user2").should == [
            ['food', 1],
            ['honey', 1],
            ['strip', 1]
        ]

        klass.artists_with_weight("user1").should == [
            ['aaron', 1],
            ['andrew', 1],
            ['andy', 2],
            ['grant', 1],
            ['greg', 1],
            ['jeff', 1],
            ['mandy', 1]
        ]

        klass.artists_with_weight("user2").should == [
            ['aaron', 1],
            ['andy', 1],
            ['mandy', 1]
        ]
      end
    end
  end
end
