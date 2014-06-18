require File.expand_path(File.join(fixtures_path, 'entities', 'rainbow_loom'))
require File.expand_path(File.join(fixtures_path, 'trackers'))

describe Bumbleworks::Tracker do
  before(:each) do
    Bumbleworks.dashboard.stub(:get_trackers => fake_trackers)
  end

  describe '.all' do
    it 'returns instances for each tracker in system' do
      trackers = described_class.all
      trackers.all? { |t| t.class == Bumbleworks::Tracker }.should be_truthy
      trackers.map(&:id).should =~ [
        'on_error',
        'global_tracker',
        'local_tracker',
        'local_error_intercept',
        'participant_tracker'
      ]
    end
  end

  describe '.count' do
    it 'returns count of current trackers' do
      expect(described_class.count).to eq 5
    end
  end

  describe '.new' do
    it 'sets tracker id and fetches original_hash from dashboard' do
      tr = described_class.new('global_tracker')
      tr.id.should == 'global_tracker'
      tr.original_hash.should == fake_trackers['global_tracker']
    end

    it 'sets tracker id and original_hash if directly provided' do
      tr = described_class.new('global_tracker', 'snarfles')
      tr.id.should == 'global_tracker'
      tr.original_hash.should == 'snarfles'
    end
  end

  describe '#wfid' do
    it 'returns wfid from original hash' do
      described_class.new('local_tracker').wfid.should == 'my_wfid'
    end

    it 'returns wfid from flow expression for global trackers' do
      described_class.new('global_tracker').wfid.should == 'my_wfid'
    end

    it 'returns nil if no wfid' do
      described_class.new('on_error').wfid.should be_nil
    end
  end

  describe '#process' do
    it 'returns process for wfid stored in msg' do
      tr = described_class.new('global_tracker')
      tr.process.should == Bumbleworks::Process.new('my_wfid')
    end

    it 'returns nil if no wfid' do
      tr = described_class.new('on_error')
      tr.process.should be_nil
    end
  end

  describe '#global?' do
    it 'returns true if not listening to events on a specific wfid' do
      described_class.new('on_error').global?.should be_truthy
      described_class.new('global_tracker').global?.should be_truthy
    end

    it 'returns false if listening to events on a specific wfid' do
      described_class.new('local_tracker').global?.should be_falsy
    end
  end

  describe '#conditions' do
    it 'returns conditions that this tracker is watching' do
      described_class.new('global_tracker').conditions.should == { "tag" => [ "the_event" ] }
      described_class.new('local_tracker').conditions.should == { "tag" => [ "local_event" ] }
      described_class.new('local_error_intercept').conditions.should == { "message" => [ "/bad/" ] }
      described_class.new('participant_tracker').conditions.should == { "participant_name" => [ "goose","bunnies" ] }
    end

    it 'returns empty hash when no conditions' do
      described_class.new('on_error').conditions.should == {}
    end
  end

  describe '#tags' do
    it 'returns array of tags' do
      described_class.new('global_tracker').tags.should == [ "the_event" ]
      described_class.new('local_tracker').tags.should == [ "local_event" ]
    end

    it 'returns empty array if no tags' do
      described_class.new('local_error_intercept').tags.should == []
      described_class.new('participant_tracker').tags.should == []
    end
  end

  describe '#action' do
    it 'returns action being awaited' do
      described_class.new('global_tracker').action.should == 'left_tag'
      described_class.new('local_error_intercept').action.should == 'error_intercepted'
      described_class.new('participant_tracker').action.should == 'dispatch'
    end
  end

  describe '#waiting_expression' do
    it 'returns nil when no expression is waiting' do
      described_class.new('on_error').waiting_expression.should be_nil
    end

    it 'returns expression awaiting reply' do
      process = Bumbleworks::Process.new('my_wfid')
      expression1 = double(:expid => '0_0_0', :tree => :a_global_expression)
      expression2 = double(:expid => '0_0_1', :tree => :a_local_expression)
      process.stub(:expressions => [expression1, expression2])

      tracker1 = described_class.new('global_tracker')
      tracker1.stub(:process => process)
      tracker1.waiting_expression.should == :a_global_expression

      tracker2 = described_class.new('local_tracker')
      tracker2.stub(:process => process)
      tracker2.waiting_expression.should == :a_local_expression
    end
  end

  describe '#where_clause' do
    it 'returns where clause from waiting expression' do
      tracker = described_class.new('global_tracker')
      tracker.stub(:waiting_expression => [
        'wait_for_event', { "where" => "some_stuff_matches" }, []
      ])
      tracker.where_clause.should == 'some_stuff_matches'
    end

    it 'returns nil when waiting_expression does not include where clause' do
      tracker = described_class.new('global_tracker')
      tracker.stub(:waiting_expression => [
        'wait_for_event', {}, []
      ])
      tracker.where_clause.should be_nil
    end

    it 'returns nil when no waiting_expression' do
      described_class.new('on_error').where_clause.should be_nil
    end
  end
end
