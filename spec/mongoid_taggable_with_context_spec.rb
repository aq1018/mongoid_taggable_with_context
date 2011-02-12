require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class MyModel
  include Mongoid::Document
  include Mongoid::TaggableWithContext
  taggable
  taggable :artists
end

describe Mongoid::TaggableWithContext do
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

  context "indexing tags" do
    it "should generate the tags aggregation collection name correctly" do
      MyModel.tags_aggregation_collection.should == "my_models_tags_aggregation"
    end
    
    it "should generate the artists aggregation collection name correctly" do
      MyModel.artists_aggregation_collection.should == "my_models_artists_aggregation"
    end

    context "retriving index" do
      context "on create directly" do
        before :each do
          MyModel.create!(:tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          MyModel.create!(:tags => "juice food bee zip", :artists => "grant andrew andy")
          MyModel.create!(:tags => "honey strip food", :artists => "mandy aaron andy")
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          MyModel.tags.should == %w[ant bee food honey juice strip zip]
          MyModel.artists.should == %w[aaron andrew andy grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          MyModel.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 1],
            ['juice', 1],
            ['strip', 1],
            ['zip', 1]
          ]
        
          MyModel.artists_with_weight.should == [
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
          m = MyModel.new
          m.tags = "food ant bee"
          m.artists = "jeff greg mandy aaron andy"
          m.save!
          
          m = MyModel.new
          m.tags = "juice food bee zip"
          m.artists = "grant andrew andy"
          m.save!

          m = MyModel.new
          m.tags = "honey strip food"
          m.artists = "mandy aaron andy"
          m.save!
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          MyModel.tags.should == %w[ant bee food honey juice strip zip]
          MyModel.artists.should == %w[aaron andrew andy grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          MyModel.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 1],
            ['juice', 1],
            ['strip', 1],
            ['zip', 1]
          ]
        
          MyModel.artists_with_weight.should == [
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
          m1 = MyModel.create!(:tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          m2 = MyModel.create!(:tags => "juice food bee zip", :artists => "grant andrew andy")
          m3 = MyModel.create!(:tags => "honey strip food", :artists => "mandy aaron andy")
          
          m1.tags_array = m1.tags_array + %w[honey strip shoe]
          m1.save!
          
          m3.artists_array = m3.artists_array + %w[grant greg gory]
          m3.save!
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          MyModel.tags.should == %w[ant bee food honey juice shoe strip zip]
          MyModel.artists.should == %w[aaron andrew andy gory grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          MyModel.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 2],
            ['food', 3],
            ['honey', 2],
            ['juice', 1],
            ['shoe', 1],
            ['strip', 2],
            ['zip', 1]
          ]
        
          MyModel.artists_with_weight.should == [
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
          m1 = MyModel.create!(:tags => "food ant bee", :artists => "jeff greg mandy aaron andy")
          m2 = MyModel.create!(:tags => "juice food bee zip", :artists => "grant andrew andy")
          m3 = MyModel.create!(:tags => "honey strip food", :artists => "mandy aaron andy")
          
          m1.tags_array = m1.tags_array + %w[honey strip shoe]
          m1.save!
          
          m3.artists_array = m3.artists_array + %w[grant greg gory]
          m3.save!
          
          m2.destroy
        end
      
        it "should retrieve the list of all saved tags distinct and ordered" do
          MyModel.tags.should == %w[ant bee food honey shoe strip]
          MyModel.artists.should == %w[aaron andy gory grant greg jeff mandy]
        end

        it "should retrieve a list of tags with weight" do
          MyModel.tags_with_weight.should == [
            ['ant', 1],
            ['bee', 1],
            ['food', 2],
            ['honey', 2],
            ['shoe', 1],
            ['strip', 2]
          ]
        
          MyModel.artists_with_weight.should == [
            ['aaron', 2],
            ['andy', 2],
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
end