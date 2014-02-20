require 'lims-core/persistence/sequel/session'
require 'lims-core/persistence/sequel/revision/persistor'

module Lims::Core
  module Persistence
    module Sequel
      module Revision
      # A RevisionSession is a session reading through
      # the revision table instead of the "normal" table.
      # To do so, it extends all the persistors to change
        # their table name and add a session_id constraints on the were clause
        class Session < Sequel::Session
          include Persistence::Session::ReadOnly
          attr_reader :session_id
          def initialize(store, session_id)
            @session_id = session_id
            super(store)
          end
        end
      end
    end
  end
end
