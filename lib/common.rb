# requirement used by  everything
require 'facets/string'
require 'facets/kernel'
require 'facets/hash'
require 'facets/array'

require 'virtus'
require 'aequitas/virtus_integration'
require 'active_model'

class Object
  def andtap(&block)
    self && (block ? block[self] : self)
  end
end

