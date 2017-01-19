describe Bumbleworks::StorageParticipant do
  let(:sid) { :storage_id }
  let(:workitem) {
    double(:sid => sid, :to_h => {
      'fei' => { 'wfid' => :the_workflow_id }
    })
  }

  subject { described_class.new(Bumbleworks.dashboard.context) }

  describe "#on_workitem" do
    it "stores workitem, delegates to work, and triggers on dispatch" do
      expect(subject).to receive(:work).with(sid)
      expect(subject).to receive(:trigger_on_dispatch)
      expect {
        subject._on_workitem(workitem)
      }.to change {
        Bumbleworks.dashboard.context.storage.get_many("workitems").count
      }.by(1)
    end

    it "behaves when #work is not implemented" do
      expect(subject).to receive(:trigger_on_dispatch)
      expect {
        subject._on_workitem(workitem)
      }.not_to raise_error
    end
  end

  describe "#trigger_on_dispatch" do
    it "calls on_dispatch on a new Bumbleworks Task" do
      allow(subject).to receive(:current_workitem).and_return(workitem)
      new_task = double(Bumbleworks::Task)
      expect(Bumbleworks::Task).to receive(:new).
        with(workitem).
        and_return(new_task)
      expect(new_task).to receive(:on_dispatch)
      subject.trigger_on_dispatch
    end
  end

  describe "#current_workitem" do
    it "reloads the workitem from the storage" do
      allow(subject).to receive(:workitem).and_return(workitem)
      allow(subject).to receive(:[]).with(:storage_id).and_return(:the_workitem)
      expect(subject.current_workitem).to eq(:the_workitem)
    end
  end
end
