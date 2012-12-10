#!perl -T

use Test::More;
use Test::Collectd::Plugins tests => 1;

BEGIN {
    load_ok( 'Collectd::Plugins::Compute' ) || print "Bail out!\n";
}

diag( "Testing Collectd::Plugins::Compute $Collectd::Plugins::Compute::VERSION, Perl $], $^X" );
