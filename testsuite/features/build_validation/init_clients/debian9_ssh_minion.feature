# Copyright (c) 2021 SUSE LLC
# Licensed under the terms of the MIT license.
#
#  1) bootstrap a new Debian minion via salt-ssh
#  2) subscribe it to a base channel for testing

@debian9_ssh_minion
Feature: Bootstrap a Debian 9 Salt SSH minion

  Scenario: Clean up sumaform leftovers on a 9 Salt SSH minion
    When I perform a full salt minion cleanup on "debian9_ssh_minion"

  Scenario: Bootstrap a SSH-managed Debian 9 minion
    Given I am authorized as "admin" with password "admin"
    When I go to the bootstrapping page
    Then I should see a "Bootstrap Minions" text
    When I enter the hostname of "debian9_ssh_minion" as "hostname"
    And I enter "root" as "user"
    And I enter "linux" as "password"
    And I enter "22" as "port"
    And I select "1-debian9_ssh_minion_key" from "activationKeys"
    And I select the hostname of "proxy" from "proxies"
    And I check "manageWithSSH"
    And I click on "Bootstrap"
    And I wait until I see "Successfully bootstrapped host!" text
    And I wait until onboarding is completed for "debian9_ssh_minion"

  # WORKAROUND bsc#1181847
  Scenario: Import the GPG keys for 9 Salt SSH minion
    When I import the GPG keys for "debian9_ssh_minion"

  Scenario: Check events history for failures on SSH-managed Debian 9 minion
    Given I am on the Systems overview page of this "debian9_ssh_minion"
    Then I check for failed events on history event page
