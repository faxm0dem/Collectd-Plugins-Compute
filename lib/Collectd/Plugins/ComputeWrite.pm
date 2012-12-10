package Collectd::Plugins::ComputeWrite;

use 5.006;
use strict;
use warnings;
use Math::RPN;
use Try::Tiny;

use Collectd qw( :all );
use threads;
use threads::shared;

=head1 NAME

Collectd::Plugins::ComputeWrite - Write plugin to make simple calculations on values

=head1 VERSION

Version 0.1001

=cut

our $VERSION = '0.1001';


=head1 SYNOPSIS

See L<Collectd>, L<collectd-perl>

=head1 PLUGIN CALLBACKS

Registered callbacks are of type WRITE and CONFIG.

=cut

my $plugin_name = "compute";
my %opt = (
	Compute => [
#		{
#			SetHost => "gridengine.in2p3.fr",
#			SetPlugin => "jobefficiency",
#			SetPluginInstance => "global",
#			SetType => "percent",
#			SetTypeInstance => "idle",
#			RPN => [ qw:cpu_idle running_jobs / 100 *: ],
#		},
		{
			SetHost => "gridengine.in2p3.fr",
			SetPlugin => "cpu",
			SetPluginInstance => "compute",
			SetType => "gauge",
			SetTypeInstance => "idle",
			RPN => [ qw:cpu_user cpu_idle: ],
		},
	],
	MaxTimeDiff => 60,
	Target => {
		cpu_idle => {
			Host => "ccswissrp.in2p3.fr",
			Plugin => "cpu",
			PluginInstance => 0,
			Type => "cpu",
			TypeInstance => "idle",
		},
		cpu_user => {
			Host => "ccswissrp.in2p3.fr",
			Plugin => "cpu",
			PluginInstance => 1,
			Type => "cpu",
			TypeInstance => "user",
		},
		cpu_idle => {
			Host => "gridengine.in2p3.fr",
			Plugin =>  "cpu",
			PluginInstance => "all-sum",
			Type => "cpu",
			TypeInstance => "idle",
			Time => undef,
			Values => [],
		},
		running_jobs => {
			Host => "gridengine.in2p3.fr",
			Plugin => "curl_xml",
			PluginInstance => "GridEngine",
			Type => "jobs",
			TypeInstance => "Running",
			Time => undef,
			Values => [],
		},
	},
);

my %target_value :shared;

plugin_register(TYPE_CONFIG, $plugin_name, 'config');
plugin_register(TYPE_WRITE, $plugin_name, 'write');

=head2 my_log

Logging function

=cut

sub my_log {
	plugin_log shift @_, join " ", "plugin=".$plugin_name, @_;
}

=head2 config

=cut

sub config {
	1;
}

=head2 write

=cut

sub write {
	my ($type, $ds, $vl) = @_;
	$vl -> {plugin_instance} //= "";
	$vl -> {type_instance} //= "";
	# fetch values from cache
	my %target = %{$opt{Target}};
	my $hit = 0;
	while (my ($n,$t) = each %target) {
		if ( $vl -> {host} eq $t -> {Host}
			&& $vl -> {plugin} eq $t -> {Plugin}
			&& $vl -> {type} eq $t -> {Type}
			&& $vl -> {plugin_instance} eq $t -> {PluginInstance}
			&& $vl -> {type_instance} eq $t -> {TypeInstance})
		{
			$target_value{$n} = $vl -> {values} -> [0];
			$hit++;
			last;
		}
	}
	return 1 unless $hit;
	# generate new value-list
	my @compute = @{$opt{Compute}};
	COMPUTE: for my $c (@compute) {
		my @rpn;
		# replace target names with their values
		for (@{$c->{RPN}}) {
			if (/^[a-zA-Z_]/) {
				if (defined $target{$_} && defined $target_value{$_}) {
					push @rpn, $target_value{$_};
				} else {
					my_log(LOG_ERR,"empty value in cache for $_");
					next COMPUTE;
				}
			} else {
					push @rpn, $_;
			}
		}
		my $value;
		try {
			$value = rpn(@rpn);
		} catch {
			my_log(LOG_ERR,"Caught exception when computing RPN `", @rpn,"': ", @_);
		};
		if (defined $value) {
			plugin_dispatch_values({
				host => $c->{SetHost},
				plugin => $c->{SetPlugin},
				plugin_instance => $c->{SetPluginInstance},
				type => $c->{SetType},
				type_instance => $c->{SetTypeInstance},
				values => [ $value ],
			});
			1;
		}
	}
	1;
}

=head1 AUTHOR

Fabien Wernli, C<< <cpan at faxm0dem.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-collectd-plugins-compute at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Collectd-Plugins-Compute>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Collectd::Plugins::Compute


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Collectd-Plugins-Compute>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Collectd-Plugins-Compute>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Collectd-Plugins-Compute>

=item * Search CPAN

L<http://search.cpan.org/dist/Collectd-Plugins-Compute/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Fabien Wernli.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Collectd::Plugins::Compute
