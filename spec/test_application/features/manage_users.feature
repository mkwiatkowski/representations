#TODO test time representations
Feature: Test  user forms generated by Representations
  In order to test the app
  Representations should be able to create forms by which one can create, edit, show users
  
  Background:
    Given a user with nick "test_nick"
    And with following profile:
        |name     |surname  |eye_color|characteristics |
        |test_name|test_surname|green|test_characteristics|
    And with following tasks:
        |title   |due_to       |description        |priority| 
        |test_title1|2009 1 1|test_description1   |1       | 
        |test_title2|2009 2 2|test_description2   |2       | 

  Scenario: Watching at user's edit page
    When I visit this user's edit page
    Then I should see "test_nick" in the text field "user[nick]"
    And I should see "test_name" in the text field "user[profile_attributes][name]"
    And I should see "test_surname" in the text field "user[profile_attributes][surname]"
    And I should see "test_characteristics" within "textarea"
    And I should see "test_title1" in the text field "user[tasks_attributes][0][title]"
    And I should see "test_description1" in the text field "user[tasks_attributes][0][description]"
    And I should see "1" in the text field "user[tasks_attributes][0][priority]"
    And I should see "test_title2" in the text field "user[tasks_attributes][1][title]"
    And I should see "test_description2" in the text field "user[tasks_attributes][1][description]"
    And I should see "2" in the text field "user[tasks_attributes][1][priority]"
    And the "green" radio button should be checked
    And the "blue" radio button should not be checked
    And the "other" radio button should not be checked
    And the "2009 1 1" should be selected in "1st" task
    And the "2009 2 2" should be selected in "2st" task
    
  Scenario: Creating new user
    Given I am on the new user page
    When I fill in "user[nick]" with "test_nick"
    And I fill in "user[profile_attributes][name]" with "test_name"
    And I fill in "user[profile_attributes][surname]" with "test_surname"
    And I choose "user_profile_eye_color_green"
    And I fill in "user[profile_attributes][characteristics]" with "test_characteristics"
    And I fill in "user[tasks_attributes][new_0][description]" with "task_description"
    And I fill in "user[tasks_attributes][new_0][title]" with "task_title"
    And I fill in "user[tasks_attributes][new_0][priority]" with "1"
    And I press "ok"
    Then the new user should be created with:
        |nick   |name       |surname        |eye_color      |characteristics        |description    |due_to     |title      |priority|
        |test_nick|test_name|test_surname   |green          |test_characteristics   |task_description|2009, 1 1|task_title |1      |
  #Unfinished - add filling tasks data
  Scenario: Editing user
    When I visit this user's edit page
    And I fill in "user[profile_attributes][name]" with "test_name"
    And I fill in "user[profile_attributes][surname]" with "test_surname"
    And I choose "user_profile_eye_color_green"
    And I fill in "user[profile_attributes][characteristics]" with "test_characteristics"
    And I select "March" from "user[tasks_attributes][0][due_to(2i)]"
    And I press "ok"
    Then the user should have attributes:
        |nick           |test_nick|
        |name           |test_name|
        |surname        |test_surname|
        |eye_color      |green|
        |characteristics|test_characteristics|
        |title1         |test_title1|
        |title2         |test_title2|
        |priority1      |1|
        |priority2      |2|
        |description1   |test_description1|
        |description2   |test_description2|
        |due_to1        |2009 3 1|
        |due_to2        |2009 2 2|