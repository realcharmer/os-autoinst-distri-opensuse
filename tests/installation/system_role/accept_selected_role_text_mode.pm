# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module which accept pre-selected System Role
# 'Text Mode' and navigate to next screen in SLES.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use Test::Assert 'assert_equals';

sub run {
    my $system_role = $testapi::distri->get_system_role();
    assert_equals(
        $system_role->get_available_role('text_mode'),
        $system_role->get_selected_role(),
        'Wrong System Role is pre-selected');
    $system_role->accept_system_role();
}

1;
