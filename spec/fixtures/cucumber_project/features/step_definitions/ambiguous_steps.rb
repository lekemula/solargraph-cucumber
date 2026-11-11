# frozen_string_literal: true

# Both definitions match "the basket weighs 2 kg"; only features/ambiguous.feature uses it.
Given('the basket weighs {int} kg') do |_weight|
end

Given(/^the basket weighs (\d+) kg$/) do |_weight|
end
