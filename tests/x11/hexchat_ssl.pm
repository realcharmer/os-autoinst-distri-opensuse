# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: hexchat
# Summary: FIPS : hexchat_ssl
# Maintainer: QE Security <none@suse.de>
# Tags: poo#49139 , poo#49136 , poo#52796

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

my $CHANNEL_NAME = "#openqa-test_irc_from_openqa";
my $TEST_MESSAGE = "Hello, this is openQA with SSL Enabled!";
my $QUIT_MESSAGE = "I'll be back!";

sub irc_login_send_message {
    my ($name) = @_;

    my @connection_tags = ("$name-connection-complete-dialog", "$name-SASL-only-error");
    assert_screen \@connection_tags;

    if (match_has_tag("$name-connection-complete-dialog")) {
        wait_still_screen;
        assert_and_click "$name-join-channel";

        # Clear the original '#hexchat' channel name
        wait_still_screen 2;
        wait_screen_change { send_key 'ctrl-a' };
        wait_screen_change { send_key "delete" };

        # Join our custom channel
        enter_cmd $CHANNEL_NAME;
        assert_screen "$name-join-channel";
        assert_and_click "$name-join-channel-OK";

        # Send a test message
        assert_screen "$name-main-window";
        enter_cmd $TEST_MESSAGE;
        assert_screen "$name-message-sent-to-channel";

        # Quit
        enter_cmd "/quit $QUIT_MESSAGE";
        assert_screen "$name-quit";
    } elsif (match_has_tag("$name-SASL-only-error")) {
        record_info('SASL required', 'The public IP address of the current worker has been blacklisted on Libera, so a SASL connection would be required. https://progress.opensuse.org/issues/66697');
    }
}

sub run {
    select_console "root-console";

    my $name = 'hexchat';
    zypper_call("in $name");

    select_console "x11";

    if (my $url = get_var("XCHAT_URL")) {
        x11_start_program("$name --url=$url", valid => 0);
        irc_login_send_message($name);
    } else {
        x11_start_program($name, target_match => "$name-network-select");
        enter_cmd "Rizon";

        # Enable SSL
        assert_and_click "$name-edit-button";
        assert_screen ["$name-use-ssl-button", "$name-ssl-on"];
        assert_and_click "$name-use-ssl-button" unless match_has_tag("$name-ssl-on");
        assert_and_click "$name-close-button";

        # Connect
        assert_and_click "$name-connect-button";
        irc_login_send_message($name);
    }
    send_key "alt-f4";
}

1;
