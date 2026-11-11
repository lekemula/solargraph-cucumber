# frozen_string_literal: true

Angenommen('ich habe {int} Gurke(n) im Korb') do |count|
  @basket = Basket.new(count)
end

Wenn('ich {int} Gurke(n) esse') do |count|
  @basket.take(count)
end
