package Collectd::Plugins::Compute;

use 5.006;
use strict;
use warnings;
use Math::RPN;
use Try::Tiny;

use Collectd qw( :all );
use Collectd::Unixsock;
use Collectd::Plugins::Common qw/recurse_config/;

=head1 NAME

Collectd::Plugins::Compute;

=head1 VERSION

Version 0.1001

=cut

our $VERSION = '0.1001';

=head1 SYNOPSIS

See L<Collectd>, L<collectd-perl>

=head1 DESCRIPTION

This plugin will use L<Collectd::Unixsock> to retrieve values from the cache, and compute
a new value using a RPN expression.

=head1 CONFIGURATION

The configuration is best explained in an example:

 LoadPlugin perl
 <Plugin perl>
	BaseName "Collectd::Plugins"
	LoadPlugin Compute
	<Plugin Compute>
		UnixSock "/var/run/collectd-unixsock"
		<Target>
			<tgt_memused>
				host          "target1host.example.com"
				plugin        "memory"
				type          "memory"
				type_instance "used"
			</tgt_memused>
			<tgt_memfree>
				host          "target1host.example.com"
				plugin        "memory"
				type          "memory"
				type_instance "free"
			</tgt_memfree>
		</Target>
		<Compute>
			RPN     "tgt_memused" "tgt_memfree" "/" 100 "*"
			SetHost           "somehost.example.com"
			SetPlugin         "memory_ratio"
			SetType           "percent"
			SetTypeInstance   "used_vs_free"
		</Compute>
	</Plugin>
 </Plugin>

This example will yield a new value whose identifier will be C<somehost.example.com/memory_ratio/percent-used_vs_free>. C<Target> blocks must contain fully qualified plugin names, e.g. must match exactly one plugin in the cache, and will be used inside C<Compute> blocks by their name, to compute the reverse polish notation C<RPN> blocks.
There can be as many C<Compute> blocks as needed.

=cut

my $plugin_name = "Compute";
my %opt = (
	UnixSock => "/var/run/collectd/sock",
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
		my_log(LOG_ERR, "No Compute block defined");
		return
	}
	if (ref $compute eq "HASH") {
		$opt->{Compute} = [ $compute ];
	}
	my @valid_compute;
	for my $c (@{$opt->{Compute}}) {
		unless (exists $c -> {SetPlugin}) {
			my_log(LOG_WARNING, "Ignoring Compute block with missing `SetPlugin' directive");
			next;
		}
		unless (exists $c -> {SetType}) {
			my_log(LOG_WARNING, "Ignoring Compute block with missing `SetType' directive");
			next;
		}
		unless (exists $c -> {RPN}) {
			my_log(LOG_WARNING, "Ignoring Compute block with missing RPN block");
			next;
		}
		if (ref ($c->{RPN}) =~ /^(?:ARRAY)?$/) {
			push @valid_compute, $c;
		} else {
			my_log(LOG_WARNING, "Ignoring Compute block with invalid RPN block (must be string or array)");
		}
	}
	unless (scalar @valid_compute) {
		my_log(LOG_ERR, "No valid Compute block");
		return
	}
	$opt->{Compute} = \@valid_compute;
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
			my_log(LOG_ERR,"Caught exception when computing RPN", @{$c->{RPN}}, "=", @rpn, @_);
		};
		if (defined $value) {
			my_log(LOG_DEBUG, "dispatching RPN", @{$c->{RPN}}, "=", @rpn, "=", $value);
			my %vl = (
				plugin => $c->{SetPlugin},
				type  => $c->{SetType},
				values => [ $value ],
			);
			$vl{host} = $c->{SetHost} if exists $c->{SetHost};
			$vl{plugin_instance} = $c->{SetPluginInstance} if exists $c->{SetPluginInstance};
			$vl{type_instance} = $c->{SetTypeInstance} if exists $c->{SetTypeInstance};
			plugin_dispatch_values(\%vl)
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
