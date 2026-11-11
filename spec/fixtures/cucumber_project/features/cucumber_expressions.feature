Feature: Cucumber Expressions

  Scenario: int parameter and optional text
    Given I have 1 cucumber in my basket
    Then I should have 1 cucumber left

  Scenario: alternation
    Given I have 5 cucumbers in my basket
    When I eat 2 cucumbers
    And I consume 1 cucumber
    Then I should have 2 cucumbers left

  Scenario: string parameter
    Given I have 3 cucumbers in my basket
    And the basket belongs to "Aslak"
    Then the basket is owned by Aslak

  Scenario: And, But and star steps
    Given I have 10 cucumbers in my basket
    And the basket belongs to "Julien"
    When I eat 3 cucumbers
    * I consume 1 cucumber
    Then I should have 6 cucumbers left
    But the basket is not empty

  Scenario Outline: eating <eat> of <start> cucumbers
    Given I have <start> cucumbers in my basket
    When I eat <eat> cucumbers
    Then I should have <left> cucumbers left

    Examples:
      | start | eat | left |
      | 12    | 5   | 7    |
      | 2     | 1   | 1    |
