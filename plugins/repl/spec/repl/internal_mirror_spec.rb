require File.join(File.dirname(__FILE__), "..", "spec_helper")

class Redcar::REPL
  describe InternalMirror do
    before do
      @mirror = InternalMirror.new
      @changed_event = false
      @mirror.add_listener(:change) { @changed_event = true }
    end
    
    def commit_test_text1
      text = <<-RUBY
# Redcar REPL

>> $internal_repl_test = 707
RUBY
      @mirror.commit(text.chomp)
    end
    
    def result_test_text1
      (<<-RUBY).chomp
# Redcar REPL

>> $internal_repl_test = 707
=> 707
>> 
RUBY
    end

    def commit_test_text2
              text = <<-RUBY
# Redcar REPL

>> $internal_repl_test = 707
=> 707
>> $internal_repl_test = 909
RUBY
      @mirror.commit(text.chomp)
    end
    
    def result_test_text2
      (<<-RUBY).chomp
# Redcar REPL

>> $internal_repl_test = 707
=> 707
>> $internal_repl_test = 909
=> 909
>> 
RUBY
    end

    describe "with no history" do
      it "should exist" do
        @mirror.should be_exist
      end
      
      it "should have a message and a prompt" do
        @mirror.read.should == (<<-RUBY).chomp
# Redcar REPL

>> 
RUBY
      end
      
      it "should have a title" do
        @mirror.title.should == "(internal)"
      end
      
      it "should not be changed" do
        @mirror.should_not be_changed
      end
      
      describe "when executing" do
        it "should execute committed text" do
          commit_test_text1
          $internal_repl_test.should == 707
        end

        it "should emit changed event when text is executed" do
          commit_test_text1
          @changed_event.should be_true
        end

        it "should now have the command and the result at the end" do
          commit_test_text1
          @mirror.read.should == result_test_text1
        end
        
        it "should display errors" do
          @mirror.commit(">> nil.foo")
          @mirror.read.should == (<<-RUBY).chomp
# Redcar REPL

>> nil.foo
=> NoMethodError: undefined method `foo' for nil:NilClass
        (eval):1:in `commit'
>> 
RUBY
        end
      end
    end
    
    describe "with a history" do
      before do
        commit_test_text1
      end
      
      it "should not have changed" do
        @mirror.changed?.should be_false
      end
      
      it "should display the history and prompt correctly" do
        @mirror.read.should == result_test_text1
      end
      
      describe "when executing" do
        it "should execute committed text" do
          commit_test_text2
          $internal_repl_test.should == 909
        end
        
        it "should show the correct history" do
          commit_test_text2
          @mirror.read.should == result_test_text2
        end
      end
    end
  end
end