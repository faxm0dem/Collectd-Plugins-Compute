use inc::Module::Install;

name     'Collectd-Plugins-Compute';
all_from 'lib/Collectd/Plugins/Compute.pm';
author   q{Fabien Wernli <cpan@faxm0dem.org>};
license  'perl';

requires 'Math::RPN';
requires 'Collectd';
requires 'Collectd::Plugins::Common';
requires 'Collectd::Unixsock';
requires 'Try::Tiny';
requires 'threads';

build_requires 'Test::More';
build_requires 'Test::Collectd::Plugins';

auto_install;

WriteAll;

