# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

use utils;
use testapi;
use bmwqemu;

use HTTP::Tiny;
use IPC::Run;
use Socket;
use Time::HiRes 'sleep';

sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    print @cmd;
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    die join(' ', @cmd) . ": $stderr" unless ($ret);
    bmwqemu::diag("IPMI: $stdout");
    return $stdout;
}

sub poweroff_host {
    ipmitool("chassis power off");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is off/;
        ipmitool('chassis power off');
    }
}

sub poweron_host {
    ipmitool("chassis power on");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is on/;
        ipmitool('chassis power on');
    }
}

sub set_pxe_boot {
    while (1) {
        my $stdout = ipmitool('chassis bootparam get 5');
        last if $stdout =~ m/Force PXE/;
        diag "setting boot device to pxe";
        ipmitool("chassis bootdev pxe");
        sleep(3);
    }
}

sub set_bootscript {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url         = "$http_server/v1/bootscript/script.ipxe/$ip";
    my $arch        = get_required_var('ARCH');
    my $autoyast    = get_var('AUTOYAST', '');

    my $kernel = get_required_var('MIRROR_HTTP');
    my $initrd = get_required_var('MIRROR_HTTP');

    if ($arch eq "aarch64") {
        $kernel .= "/boot/$arch/linux";
        $initrd .= "/boot/$arch/initrd";
    } else {
        $kernel .= "/boot/$arch/loader/linux";
        $initrd .= "/boot/$arch/loader/initrd";
    }
    my $install = get_required_var('MIRROR_HTTP');
    my $cmdline_extra;

    my $console = get_var('IPXE_CONSOLE');

    $cmdline_extra = "console=$console" if $console;

    $cmdline_extra .= " root=/dev/ram0 initrd=initrd textmode=1" if check_var('IPXE_UEFI', '1');

    if ($autoyast != '') {
        $cmdline_extra .= " autoyast=$autoyast ";
    } else {
        $cmdline_extra .= " sshd=1 vnc=1 VNCPassword=$testapi::password sshpassword=$testapi::password ";    # trigger default VNC installation
    }
    $cmdline_extra .= ' plymouth.enable=0 ';

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
echo ++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++ openQA ipxe boot ++++++++++++
echo +    Host: $host
echo ++++++++++++++++++++++++++++++++++++++++++

kernel $kernel install=$install $cmdline_extra
initrd $initrd
boot
END_BOOTSCRIPT

    diag "setting iPXE bootscript to: $bootscript";

    diag "===== autoyast $autoyast =====";
    my $curl = `curl -s $autoyast`;
    diag $curl;
    diag "===== END bootscript $autoyast =====";

    my $response = HTTP::Tiny->new->request('POST', $url, {content => $bootscript, headers => {'content-type' => 'text/plain'}});
    diag "$response->{status} $response->{reason}\n";
}

sub set_bootscript_hdd {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url         = "$http_server/v1/bootscript/script.ipxe/$ip";

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
exit
END_BOOTSCRIPT

    my $response = HTTP::Tiny->new->request('POST', $url, {content => $bootscript, headers => {'content-type' => 'text/plain'}});
    diag "$response->{status} $response->{reason}\n";
}

sub run {
    my $self = shift;

    poweroff_host;

    set_bootscript;

    set_pxe_boot;
    poweron_host;

    # when we don't use autoyast, we need to also load the right test modules to perform the remote installation
    if (get_var('AUTOYAST')) {
        select_console 'sol', await_console => 0;
        # make sure to wait for a while befor changing the boot device again, in order to not change it too early
        sleep 120;
        if (check_var('IPXE_UEFI', '1')) {
            # some machines need really long to boot into the installer, make sure
            # we wait long enough so the bootscript was loaded
            sleep 600;
            set_bootscript_hdd;
        }
        assert_screen('linux-login', 1800);
    } else {
        select_console 'sol', await_console => 0;
        sleep 120;
        my $ssh_vnc_wait_time = 1200;
        my $ssh_vnc_tag       = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        my @tags              = ($ssh_vnc_tag);
        if (check_screen(\@tags, $ssh_vnc_wait_time)) {
            save_screenshot;
            sleep 2;
        }
        save_screenshot;
        select_console 'installation';
        save_screenshot;

        wait_still_screen;
    }
}

1;
