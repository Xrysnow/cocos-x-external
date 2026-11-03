#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(WNOHANG _exit setpgid);

# A process group belongs to this command only. Killing CMake must not leave an
# orphan make writing a directory whose lock was owned by the dead caller.
my $environment_file = shift @ARGV;
die "Pass environment-file and command arguments\n" unless defined $environment_file && @ARGV;
delete @ENV{qw(CC CXX AS AR RANLIB CFLAGS CXXFLAGS CPPFLAGS LDFLAGS MAKE MAKEFLAGS MFLAGS
    PERL5LIB PERL5OPT OPENSSL_LOCAL_CONFIG_DIR OPENSSL_CONF OPENSSL_MODULES OPENSSL_ENGINES
    CROSS_COMPILE CROSS_SYSROOT ANDROID_NDK ANDROID_NDK_ROOT SDKROOT MACOSX_DEPLOYMENT_TARGET)};
open my $environment, '<', $environment_file or die "Cannot read environment: $!\n";
while (my $line = <$environment>) {
    chomp $line;
    die "Malformed environment record\n" unless $line =~ /^([A-Za-z_][A-Za-z_0-9]*)=(.*)$/;
    $ENV{$1} = $2;
}
close $environment;

my $caller = getppid();
my $cancelled = 0;
$SIG{TERM} = sub { $cancelled = 15; };
$SIG{INT} = sub { $cancelled = 2; };
$SIG{HUP} = sub { $cancelled = 1; };
my $child = fork();
die "Cannot fork command: $!\n" unless defined $child;
if ($child == 0) {
    setpgid(0, 0) == 0 or die "Cannot create private command process group: $!\n";
    $SIG{TERM} = $SIG{INT} = $SIG{HUP} = 'DEFAULT';
    exec { $ARGV[0] } @ARGV;
    print STDERR "Cannot execute $ARGV[0]: $!\n";
    _exit(127);
}
# Either child or parent wins this harmless race. The child also checks errors.
setpgid($child, $child);
while (1) {
    my $ended = waitpid($child, WNOHANG);
    if ($ended == $child) {
        my $status = $?;
        # Retire command-specific background children, if a tool started any.
        kill 'TERM', -$child;
        select undef, undef, undef, 0.1;
        kill 'KILL', -$child;
        exit(($status & 127) ? 128 + ($status & 127) : ($status >> 8));
    }
    $cancelled ||= 15 if getppid() != $caller;
    if ($cancelled || $ended == -1) {
        kill 'TERM', -$child;
        select undef, undef, undef, 0.5;
        kill 'KILL', -$child;
        waitpid($child, 0);
        exit(128 + ($cancelled || 15));
    }
    select undef, undef, undef, 0.1;
}
