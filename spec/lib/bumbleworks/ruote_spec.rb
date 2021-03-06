describe Bumbleworks::Ruote do
  describe ".cancel_process!" do
    before :each do
      Bumbleworks.start_worker!
    end

    it 'cancels given process' do
      Bumbleworks.define_process 'do_nothing' do
        lazy_guy :task => 'absolutely_nothing'
      end
      process = Bumbleworks.launch!('do_nothing')
      Bumbleworks.dashboard.wait_for(:lazy_guy)
      expect(Bumbleworks.dashboard.process(process.wfid)).not_to be_nil
      described_class.cancel_process!(process.wfid)
      expect(Bumbleworks.dashboard.process(process.wfid)).to be_nil
    end

    it 'times out if process is not cancelled in time' do
      Bumbleworks.define_process "time_hog" do
        sequence :on_cancel => 'ignore_parents' do
          pigheaded :task => 'whatever'
        end
        define 'ignore_parents' do
          wait '1s'
        end
      end
      process = Bumbleworks.launch!('time_hog')
      Bumbleworks.dashboard.wait_for(:pigheaded)
      expect(Bumbleworks.dashboard.process(process.wfid)).not_to be_nil
      expect {
        described_class.cancel_process!(process.wfid, :timeout => 0.5)
      }.to raise_error(Bumbleworks::Ruote::CancelTimeout)
    end
  end

  describe ".kill_process!" do
    before :each do
      Bumbleworks.start_worker!
    end

    it 'kills given process without running on_cancel' do
      Bumbleworks.define_process "do_nothing" do
        sequence :on_cancel => 'rethink_life' do
          lazy_guy :task => 'absolutely_nothing'
        end
        define 'rethink_life' do
          wait '10s'
        end
      end
      process = Bumbleworks.launch!('do_nothing')
      Bumbleworks.dashboard.wait_for(:lazy_guy)
      expect(Bumbleworks.dashboard.process(process.wfid)).not_to be_nil
      described_class.kill_process!(process.wfid)
      expect(Bumbleworks.dashboard.process(process.wfid)).to be_nil
    end

    it 'times out if process is not killed in time' do
      allow(Bumbleworks.dashboard).to receive(:process).with('woot').and_return(:i_exist)
      expect {
        described_class.kill_process!('woot', :timeout => 0.5)
      }.to raise_error(Bumbleworks::Ruote::KillTimeout)
    end

    it 'uses storage.remove_process if force option is true' do
      expect(Bumbleworks.dashboard.storage).to receive(:remove_process).with('woot')
      allow(Bumbleworks.dashboard).to receive(:process).with('woot').and_return(nil)
      described_class.kill_process!('woot', :force => true)
    end
  end

  describe ".cancel_all_processes!" do
    before :each do
      Bumbleworks::Ruote.register_participants
      Bumbleworks.start_worker!
    end

    it 'cancels all processes' do
      5.times do |i|
        Bumbleworks.define_process "do_nothing_#{i}" do
          participant :ref => "lazy_guy_#{i}", :task => 'absolutely_nothing'
        end
        Bumbleworks.launch!("do_nothing_#{i}")
        Bumbleworks.dashboard.wait_for("lazy_guy_#{i}".to_sym)
      end
      expect(Bumbleworks.dashboard.processes.count).to eq(5)
      described_class.cancel_all_processes!
      expect(Bumbleworks.dashboard.processes.count).to eq(0)
    end


    it 'cancels processes which show up while waiting' do
      class Bumbleworks::Ruote
        class << self
          alias_method :original, :send_cancellation_message
          def send_cancellation_message(method, processes)
            # 2. call original method to cancel the processes kicked off below
            original(method, processes)

            # 3. launch some more processes before returning, but only do it once.
            #    These should also be cancelled.
            if !@kicked_off
              Bumbleworks.define_process "do_more_nothing" do
                participant :ref => "lazy_guy_bob", :task => 'absolutely_nothing'
              end

              10.times do
                Bumbleworks.launch!("do_more_nothing")
              end
              @kicked_off = true
            end
          end
        end
      end

      # 1. kick off some processes, wait for them then cancel them.
      5.times do |i|
        Bumbleworks.define_process "do_nothing_#{i}" do
          participant :ref => "lazy_guy_#{i}", :task => 'absolutely_nothing'
        end
        Bumbleworks.launch!("do_nothing_#{i}")
        Bumbleworks.dashboard.wait_for("lazy_guy_#{i}".to_sym)
      end

      expect(Bumbleworks.dashboard.process_wfids.count).to eq(5)

      described_class.cancel_all_processes!(:timeout => 30)

      # 4. When this is all done, all processes should be cancelled.
      expect(Bumbleworks.dashboard.process_wfids.count).to eq(0)
    end

    it 'times out if processes are not cancelled in time' do
      Bumbleworks.define_process "time_hog" do
        sequence :on_cancel => 'ignore_parents' do
          pigheaded :task => 'whatever'
        end
        define 'ignore_parents' do
          wait '1s'
        end
      end
      Bumbleworks.launch!('time_hog')
      Bumbleworks.dashboard.wait_for(:pigheaded)
      expect(Bumbleworks.dashboard.process_wfids.count).to eq(1)
      expect {
        described_class.cancel_all_processes!(:timeout => 0.5)
      }.to raise_error(Bumbleworks::Ruote::CancelTimeout)
    end
  end

  describe ".kill_all_processes!" do
    before :each do
      Bumbleworks::Ruote.register_participants
      Bumbleworks.start_worker!
    end

    it 'kills all processes without running on_cancel' do
      5.times do |i|
        Bumbleworks.define_process "do_nothing_#{i}" do
          sequence :on_cancel => 'rethink_life' do
            participant :ref => "lazy_guy_#{i}", :task => 'absolutely_nothing'
          end
          define 'rethink_life' do
            wait '10s'
          end
        end
        Bumbleworks.launch!("do_nothing_#{i}")
        Bumbleworks.dashboard.wait_for("lazy_guy_#{i}".to_sym)
      end
      expect(Bumbleworks.dashboard.processes.count).to eq(5)
      described_class.kill_all_processes!
      expect(Bumbleworks.dashboard.processes.count).to eq(0)
    end

    it 'times out if processes are not killed in time' do
      allow(Bumbleworks.dashboard).to receive(:process_wfids).and_return(['immortal_wfid'])
      expect {
        described_class.kill_all_processes!(:timeout => 0.5)
      }.to raise_error(Bumbleworks::Ruote::KillTimeout)
    end

    it 'uses storage.clear if force option is true' do
      allow(Bumbleworks.dashboard).to receive(:process_wfids).and_return(['wfid'], [])
      expect(Bumbleworks.dashboard.storage).to receive(:clear)
      described_class.kill_all_processes!(:force => true)
    end
  end

  describe '.send_cancellation_message' do
    it 'sends cancel message to given wfids if method is cancel' do
      expect(Bumbleworks.dashboard).to receive(:cancel).with('wfid1')
      expect(Bumbleworks.dashboard).to receive(:cancel).with('wfid2')
      described_class.send_cancellation_message(:cancel, ['wfid1', 'wfid2'])
    end

    it 'sends kill message to given wfids if method is kill' do
      expect(Bumbleworks.dashboard).to receive(:kill).with('wfid1')
      expect(Bumbleworks.dashboard).to receive(:kill).with('wfid2')
      described_class.send_cancellation_message(:kill, ['wfid1', 'wfid2'])
    end
  end

  describe '.dashboard' do
    it 'raises an error if no storage is defined' do
      Bumbleworks.storage = nil
      expect { described_class.dashboard }.to raise_error Bumbleworks::UndefinedSetting
    end

    it 'creates a new dashboard' do
      expect(described_class.dashboard).to be_an_instance_of(Ruote::Dashboard)
    end

    it 'does not start a worker by default' do
      expect(described_class.dashboard.worker).to be_nil
    end
  end

  describe '.start_worker!' do
    it 'adds new worker to dashboard and returns worker' do
      expect(described_class.dashboard.worker).to be_nil
      new_worker = described_class.start_worker!
      expect(new_worker).to be_an_instance_of(Bumbleworks::Worker)
      expect(described_class.dashboard.worker).to eq(new_worker)
    end

    it 'runs in current thread if :join option is true' do
      allow(Bumbleworks::Worker).to receive(:new).and_return(worker_double = double('worker'))
      expect(worker_double).to receive(:run)
      described_class.start_worker!(:join => true)
    end

    it 'runs in new thread and returns worker if :join option not true' do
      allow(Bumbleworks::Worker).to receive(:new).and_return(worker_double = double('worker'))
      expect(worker_double).to receive(:run_in_thread)
      expect(described_class.start_worker!).to eq(worker_double)
    end

    it 'sets dashboard to noisy if :verbose option true' do
      expect(described_class.dashboard).to receive(:noisy=).with(true)
      described_class.start_worker!(:verbose => true)
    end

    it 'registers error handler' do
      expect(described_class).to receive(:register_error_dispatcher)
      described_class.start_worker!
    end

    it 'calls set_up_storage_history' do
      expect(described_class).to receive(:set_up_storage_history)
      described_class.start_worker!
    end

    it 'does not add another error_dispatcher if already registered' do
      described_class.register_participants
      described_class.start_worker!
      expect(described_class.dashboard.participant_list.map(&:classname)).to eq([
        'Bumbleworks::ErrorDispatcher',
        'Bumbleworks::EntityInteractor',
        'Bumbleworks::StorageParticipant'
      ])
      expect(Bumbleworks.dashboard.on_error.flatten[2]).to eq('error_dispatcher')
    end
  end

  describe '.set_up_storage_history' do
    it 'adds a storage history service to the dashboard if storage adapter allows it' do
      storage_adapter = double('adapter', :allow_history_storage? => true)
      Bumbleworks.storage_adapter = storage_adapter
      allow(described_class).to receive_messages(:storage => Ruote::HashStorage.new({}))
      expect(Bumbleworks.dashboard).to receive(:add_service).with(
        'history', 'ruote/log/storage_history', 'Ruote::StorageHistory'
      )
      described_class.set_up_storage_history
    end

    it 'does not add a storage history service to the dashboard if not allowed' do
      storage_adapter = double('adapter', :allow_history_storage? => false)
      Bumbleworks.storage_adapter = storage_adapter
      allow(described_class).to receive_messages(:storage => Ruote::HashStorage.new({}))
      expect(Bumbleworks.dashboard).to receive(:add_service).never
      described_class.set_up_storage_history
    end

    it 'does not add a storage history service to the dashboard if turned off in config' do
      storage_adapter = double('adapter', :allow_history_storage? => true)
      Bumbleworks.storage_adapter = storage_adapter
      allow(described_class).to receive_messages(:storage => Ruote::HashStorage.new({}))
      expect(Bumbleworks.dashboard).to receive(:add_service).never
      Bumbleworks.store_history = false
      described_class.set_up_storage_history
    end
  end

  describe '.register_participants' do
    it 'loads participants from given block, adding storage participant catchall' do
      registration_block = Proc.new {
        bees_honey 'BeesHoney'
        maple_syrup 'MapleSyrup'
        catchall 'NewCatchall'
      }

      expect(described_class.dashboard.participant_list).to be_empty
      described_class.register_participants &registration_block
      expect(described_class.dashboard.participant_list.size).to eq(6)
      expect(described_class.dashboard.participant_list.map(&:classname)).to eq([
        'Bumbleworks::ErrorDispatcher',
        'Bumbleworks::EntityInteractor',
        'BeesHoney', 'MapleSyrup', 'NewCatchall',
        'Bumbleworks::StorageParticipant'
      ])
    end

    it 'does not add storage participant catchall if already exists' do
      registration_block = Proc.new {
        bees_honey 'BeesHoney'
        catchall
      }

      expect(described_class.dashboard.participant_list).to be_empty
      described_class.register_participants &registration_block
      expect(described_class.dashboard.participant_list.size).to eq(4)
      expect(described_class.dashboard.participant_list.map(&:classname)).to eq([
        'Bumbleworks::ErrorDispatcher', 'Bumbleworks::EntityInteractor', 'BeesHoney', 'Ruote::StorageParticipant'
      ])
    end

    it 'adds catchall and error_handler participants if block is nil' do
      expect(described_class.dashboard.participant_list).to be_empty
      described_class.register_participants &nil
      expect(described_class.dashboard.participant_list.size).to eq(3)
      expect(described_class.dashboard.participant_list.map(&:classname)).to eq(
        ['Bumbleworks::ErrorDispatcher', 'Bumbleworks::EntityInteractor', 'Bumbleworks::StorageParticipant']
      )
    end
  end

  describe '.register_error_dispatcher', dev:true do
    it 'registers the error handler participant' do
      described_class.register_error_dispatcher
      expect(Bumbleworks.dashboard.participant_list.map(&:classname)).to include('Bumbleworks::ErrorDispatcher')
    end

    it 'it sets the global Ruote on_error to the error_dispatcher' do
      described_class.register_error_dispatcher
      expect(Bumbleworks.dashboard.on_error.flatten[2]).to eq('error_dispatcher')
    end

    it 'does not override existing error_dispatcher' do
      described_class.register_participants do
        error_dispatcher 'Whatever'
      end
      described_class.register_error_dispatcher
      expect(Bumbleworks.dashboard.participant_list.map(&:classname)).to eq(
        ['Bumbleworks::EntityInteractor', 'Whatever', 'Bumbleworks::StorageParticipant']
      )

    end
  end

  describe '.storage' do
    it 'raise error when storage is not defined' do
      Bumbleworks.storage = nil
      expect { described_class.storage }.to raise_error Bumbleworks::UndefinedSetting
    end

    it 'returns new storage from configured adapter' do
      driven_storage = ::Ruote::HashStorage.new({})
      storage = {}
      adapter = double('Adapter')
      options = { :thing => 'yay' }
      allow(adapter).to receive(:new_storage).with(storage, options).and_return(driven_storage)
      Bumbleworks.storage = storage
      Bumbleworks.storage_adapter = adapter
      Bumbleworks.storage_options = options
      expect(described_class.storage).to eq(driven_storage)
    end
  end

  describe '.launch' do
    before :each do
      @pdef = Bumbleworks.define_process 'foo' do; end
    end

    it 'tells dashboard to launch process' do
      expect(described_class.dashboard).to receive(:launch).with(@pdef.tree, 'variable' => 'neat')
      described_class.launch('foo', 'variable' => 'neat')
    end

    it 'sets catchall if needed' do
      expect(described_class.dashboard.participant_list).to be_empty
      described_class.launch('foo')
      expect(described_class.dashboard.participant_list.size).to eq(1)
      expect(described_class.dashboard.participant_list.first.classname).to eq('Bumbleworks::StorageParticipant')
    end

    it 'raises ProcessDefinition::NotFound if given process name does not exist' do
      expect {
        described_class.launch('gevalstumerfkabambph')
      }.to raise_error(Bumbleworks::ProcessDefinition::NotFound)
    end
  end

  describe '.reset!' do
    it 'purges and shuts down storage, then resets storage' do
      old_storage = double('Storage')
      allow(described_class).to receive(:initialize_storage_adapter).and_return(old_storage)
      expect(old_storage).to receive(:purge!)
      expect(old_storage).to receive(:shutdown)
      described_class.reset!
      allow(described_class).to receive(:initialize_storage_adapter).and_return(:new_storage)
      expect(described_class.storage).to eq(:new_storage)
      # clean up
      described_class.instance_variable_set(:@storage, nil)
    end

    it 'skips purging and shutting down of storage if no storage' do
      described_class.instance_variable_set(:@storage, nil)
      expect {
        described_class.reset!
      }.not_to raise_error
    end

    it 'shuts down dashboard and detaches' do
      old_dashboard = described_class.dashboard
      expect(old_dashboard).to receive(:shutdown)
      described_class.reset!
      expect(described_class.dashboard).not_to eq(old_dashboard)
    end

    it 'skips shutting down dashboard if no dashboard' do
      described_class.instance_variable_set(:@dashboard, nil)
      expect {
        described_class.reset!
      }.not_to raise_error
    end

    it 'skips shutting down dashboard if dashboard can not be shutdown' do
      dashboard = double('dashboard', :respond_to? => false)
      described_class.instance_variable_set(:@dashboard, dashboard)
      expect(dashboard).to receive(:shutdown).never
      described_class.reset!
      expect(described_class.dashboard).not_to eq(dashboard)
    end
  end
end
