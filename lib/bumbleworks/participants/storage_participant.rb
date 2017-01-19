require "bumbleworks/workitem_entity_storage"

module Bumbleworks
  class StorageParticipant < ::Ruote::StorageParticipant
    include WorkitemEntityStorage

    def on_workitem
      return_value = super
      trigger_on_dispatch
      send(:work, workitem.sid) if respond_to?(:work)
      return return_value
    end

    def trigger_on_dispatch
      Bumbleworks::Task.new(current_workitem).on_dispatch
    end

    def current_workitem
      self[workitem.sid]
    end
  end
end
