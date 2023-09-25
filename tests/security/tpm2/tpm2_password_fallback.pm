# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Testing password fallback when TPM is not available.
#          This should simulate a scenario in which the disk
#          is moved to a different machine. It requires an image
#          with TPM2 already set up.
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    wait_still_screen 2;
    assert_screen "alp-decrypt-with-password";
    type_string "luksrecoverypwd";
    send_key "ret";
    # Wait for unlock and continue
    wait_still_screen 5;
}

1;
