package Collectd::Plugins::Compute;

use 5.006;
use strict;
use warnings;
use Math::RPN;
use Try::Tiny;

use Collectd qw( :all );
use Collectd::Unixsock;
use Collectd::Plugins::GridEngine;

=head1 NAME

Collectd::Plugins::GridEngine::GlobalJobEfficiency

=head1 VERSION

Version 0.1001

=cut

our $VERSION = '0.1001';


=head1 SYNOPSIS

See L<Collectd>, L<collectd-perl>

=head1 PLUGIN CALLBACKS

Registered callbacks are of type READ and CONFIG.

=cut

my $plugin_name = "jobefficiency";
my %opt = (
	UnixSock => "/var/run/collectd/sock",
	UnixSock => "/var/tmp/collectd-unixsock",
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
			RPN => [ qw:cpu_u cpu_i /: ],
		},
	],
	MaxTimeDiff => 60,
	Target => {
		cpu_i => {
			host => "ccswissrp.in2p3.fr",
			plugin => "cpu",
			plugin_instance => 0,
			type => "cpu",
			type_instance => "idle",
		},
		cpu_u => {
			host => "ccswissrp.in2p3.fr",
			plugin => "cpu",
			plugin_instance => 1,
			type => "cpu",
			type_instance => "user",
		},
		cpu_idle => {
			host => "gridengine.in2p3.fr",
			plugin =>  "cpu",
			plugin_instance => "all-sum",
			type => "cpu",
			type_instance => "idle",
		},
		running_jobs => {
			host => "gridengine.in2p3.fr",
			plugin => "curl_xml",
			plugin_instance => "GridEngine",
			type => "jobs",
			type_instance => "Running",
		},
	},
);

my %target_value;
my $collectd;

plugin_register(TYPE_CONFIG, $plugin_name, 'my_config');
plugin_register(TYPE_READ, $plugin_name, 'my_read');
plugin_register(TYPE_INIT, $plugin_name, 'my_init');

=head2 my_log

Logging function

=cut

sub my_log {
	plugin_log shift @_, join " ", "plugin=".$plugin_name, @_;
}

=head2 config

=cut

sub my_config {
	my (undef,$opt) = recurse_config($_[0]);
	my $compute = $opt->{Compute};
	unless ($compute) {
		my_log(LOG_ERR, "Compute block missing");
		return
	}
	if (ref $compute eq "HASH") {
		$opt->{Compute} = [ $compute ];
	}
	%opt = %$opt;
	1;
}

sub _init_sock {
	$collectd = Collectd::Unixsock -> new ($opt{UnixSock}) or return
}

sub my_init {
	_init_sock();
}

=head2 write

=cut

sub my_read {
	# fetch values from cache
	my %target = %{$opt{Target}};
	while (my ($n,$identifier) = each %target) {
		my $cache_value;
		try {
			$cache_value = $collectd -> getval(%$identifier);
		} catch {
			my_log(LOG_ERR, "Problem getting value from socket: ",@_);
			_init_sock();
			return
		};
		$target_value{$n} = $cache_value -> {value} if defined $cache_value;
	}
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
			my_log(LOG_DEBUG, "dispatching $value");
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
