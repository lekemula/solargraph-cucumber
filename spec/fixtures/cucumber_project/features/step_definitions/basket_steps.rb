# frozen_string_literal: true

Given('I have {int} cucumber(s) in my basket') do |count|
  @basket = Basket.new(count)
end

When('I eat/consume {int} cucumber(s)') do |count|
  @basket.take(count)
end

Then('I should have {int} cucumber(s) left') do |count|
  expect(@basket.count).to eq(count)
end

And('the basket belongs to {string}') do |owner|
  @basket.owner = owner
end

But('the basket is not empty') do
  expect(@basket.count).to be_positive
end
