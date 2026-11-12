use strict;
use warnings;
use lib '.';
use configdata;

# Some official switches (notably no-fips) deliberately have no public macro.
# Check Configure's actual disabled set as well as the drivers' header checks.
for my $option (@ARGV) {
    $option =~ /^no-([a-z0-9][a-z0-9-]*)$/
        or die "Unexpected OpenSSL disable option: $option\n";
    exists $configdata::disabled{$1}
        or die "OpenSSL Configure did not disable $1\n";
}
# With no-module, legacy must remain enabled so it is built into libcrypto.
if (grep { $_ eq 'no-module' } @ARGV) {
    exists $configdata::disabled{legacy}
        and die "The built-in legacy provider must remain enabled\n";
}
print "All requested OpenSSL disable options are present in configdata.pm\n";
