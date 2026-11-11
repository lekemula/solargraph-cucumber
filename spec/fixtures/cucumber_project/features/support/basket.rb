# frozen_string_literal: true

# A countable basket of cucumbers shared by the step definitions.
class Basket
  attr_accessor :owner, :path, :color, :label, :items
  attr_reader :count

  def initialize(count = 0)
    @count = count
    @items = {}
  end

  def take(amount)
    @count -= amount
  end
end
