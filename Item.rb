class Item
  attr_accessor :title, :desc, :price
  
  def isValid?
    title != nil && price != nil
  end
end