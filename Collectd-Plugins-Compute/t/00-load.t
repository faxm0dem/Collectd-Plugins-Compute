#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Collectd::Plugins::Compute' ) || print "Bail out!\n";
}

diag( "Testing Collectd::Plugins::Compute $Collectd::Plugins::Compute::VERSION, Perl $], $^X" );
