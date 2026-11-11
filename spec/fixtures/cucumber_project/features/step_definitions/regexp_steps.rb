# frozen_string_literal: true

Then(/^the basket (?:is|should be) owned by (\w+)$/) do |owner|
  expect(@basket.owner).to eq(owner)
end

Given(%r{^the basket is stored at (/\S+)$}) do |path|
  @basket.path = path
end
