module Bumbleworks
  class Task
    class Finder
      include Enumerable

      def initialize(queries = [], task_class = Bumbleworks::Task)
        @queries = queries
        @queries << proc { |wi| wi['fields']['params']['task'] }
        @task_class = task_class
        @wfids = nil
      end

      def by_nickname(nickname)
        @queries << proc { |wi| wi['fields']['params']['task'] == nickname }
        self
      end

      def for_roles(identifiers)
        identifiers ||= []
        @queries << proc { |wi| identifiers.include?(wi['participant_name']) }
        self
      end

      def for_role(identifier)
        for_roles([identifier])
      end

      def unclaimed(check = true)
        @queries << proc { |wi| wi['fields']['params']['claimant'].nil? == check }
        self
      end

      def claimed
        unclaimed(false)
      end

      def for_claimant(token)
        @queries << proc { |wi| wi['fields']['params']['claimant'] == token }
        self
      end

      def for_entity(entity)
        entity_id = entity.respond_to?(:identifier) ? entity.identifier : entity.id
        @queries << proc { |wi|
          (wi['fields'][:entity_type] || wi['fields']['entity_type']) == entity.class.name &&
            (wi['fields'][:entity_id] || wi['fields']['entity_id']) == entity_id
        }
        self
      end

      def for_processes(processes)
        process_ids = (processes || []).map { |p|
          p.is_a?(Bumbleworks::Process) ? p.wfid : p
        }
        @wfids = process_ids
        self
      end

      def for_process(process)
        for_processes([process])
      end

      def all
        return [] if @wfids == []
        workitems = Bumbleworks.dashboard.context.storage.get_many('workitems', @wfids).select { |wi|
          @queries.all? { |q| q.call(wi) }
        }.collect { |wi|
          ::Ruote::Workitem.new(wi)
        }
        from_workitems(workitems)
      end

      def each(&block)
        all.each(&block)
      end

      def empty?
        all.empty?
      end

      def next_available(options = {})
        options[:timeout] ||= Bumbleworks.timeout

        start_time = Time.now
        while first.nil?
          if (Time.now - start_time) > options[:timeout]
            raise @task_class::AvailabilityTimeout, "No tasks found matching criteria in time"
          end
          sleep 0.1
        end
        first
      end

    private

      def from_workitems(workitems)
        tasks = workitems.map { |wi|
          @task_class.new(wi)
        }.compact
      end
    end
  end
end
