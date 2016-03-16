# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use testapi;
use utils;

#testcase 5255-1503803: Gnome:Change Password

my $rootpwd = "$password";
my $password;
my $newpwd      = "suseTEST-987";
my $newUser     = "test";
my $pwd4newUser = "helloWORLD-0";

sub lock_screen {
    assert_and_click "system-indicator";
    assert_and_click "lock-button";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub logout_and_login {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub reboot_system {
    wait_idle;
    send_key "ctrl-alt-delete";    #reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';
    if (check_screen("reboot-auth", 5)) {
        type_string "$rootpwd";
        assert_and_click "authenticate";
    }
    assert_screen "displaymanager", 200;
    send_key "ret";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub switch_user {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "switch-user";
}

sub change_pwd_and_add_user {
    #change current pwd
    send_key "super";
    type_string "users", 1;    #use 1 to give gnome-shell enough time searching the user-settings module.
    send_key "ret";
    assert_screen "users-settings", 60;
    assert_and_click "Unlock";
    assert_screen "authentication-required";
    type_string "$rootpwd";
    assert_and_click "authenticate";
    send_key "alt-p";
    send_key "ret";
    send_key "alt-p";
    type_string "$rootpwd";
    send_key "alt-n";
    type_string "$newpwd";
    send_key "alt-v";
    type_string "$newpwd";
    assert_screen "actived-change-button";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    $password = $newpwd;

    #add a new user
    assert_and_click "plus-button";
    send_key "alt-f";
    type_string "$newUser";
    assert_and_click "set-password";
    send_key "alt-p";
    type_string "$pwd4newUser";
    send_key "alt-v";
    type_string "$pwd4newUser";
    assert_screen "actived-add-button";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    send_key "alt-f4";
}

sub run () {
    my $self = shift;

    #change pwd for current user and add new user for switch scenario
    change_pwd_and_add_user;

    #verify changed password work well in the following scenario:
    lock_screen;
    logout_and_login;
    reboot_system;
    #swtich to new added user then switch back
    switch_user;
    assert_screen "displaymanager";
    send_key "down";
    send_key "ret";
    assert_screen "test-login";
    type_string "$pwd4newUser";
    send_key "ret";
    assert_screen "generic-desktop";
    switch_user;
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "origin-login";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";

    #restore password to original value
    x11_start_program("gnome-terminal");
    type_string "su";
    send_key "ret";
    assert_screen "pwd4root-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "root-terminal";
    type_string "passwd $username";
    send_key "ret";
    assert_screen "pwd4user-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "pwd4user-confirm-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "password-changed";
    send_key "alt-f4";
    send_key "ret";
}

1;
# vim: set sw=4 et:
