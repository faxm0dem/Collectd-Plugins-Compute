use inc::Module::Install;

name     'Collectd-Plugins-Compute';
all_from 'lib/Collectd/Plugins/Compute.pm';
author   q{Fabien Wernli <cpan@faxm0dem.org>};
license  'perl';

requires 'Math::RPN';
requires 'Collectd';
requires 'Try::Tiny';
requires 'threads';

build_requires 'Test::More';

auto_install;

WriteAll;

