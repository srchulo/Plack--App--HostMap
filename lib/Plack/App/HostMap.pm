package Plack::App::HostMap;
use strict;
use warnings;
use parent qw/Plack::Component/;
# ABSTRACT: Map multiple Plack apps by host 

use Carp ();
use Domain::PublicSuffix;
 
sub mount { shift->map(@_) }
 
sub map {
    my $self = shift;
    my($domain, $app) = @_;

	if(ref $domain eq 'ARRAY') { 
		$self->_map_domain($_, $app) for @$domain;
	}
	else { $self->_map_domain($domain, $app) }
}

sub _map_domain { 
	my ($self, $domain, $app) = @_;

    Carp::croak("domain cannot be empty") unless $domain;

	if($domain =~ /^\*\.(.*)$/) { 
		$self->{_all_subdomains}->{$1} = 1;
		$domain = $1;
	} 

	$self->{_map}->{$domain} = $app;
}

sub prepare_app { 
	my ($self) = @_;
	$self->{_dps} = Domain::PublicSuffix->new if keys %{$self->{_all_subdomains}};
}

sub call {
    my ($self, $env) = @_;
 
    my $http_host = $env->{HTTP_HOST};
 
    if ($http_host and my $port = $env->{SERVER_PORT}) {
		$http_host =~ s/:$port$//;
    }

	if($self->{_dps}) {
		my $root = $self->{_dps}->get_root_domain($http_host);	
		if($self->{_map}->{$root}) {
			warn "ROOT $root\n";
			$http_host = $root;
		}
	}

    return [404, [ 'Content-Type' => 'text/plain' ], [ "Not Found" ]] unless $self->{_map}->{$http_host};

	my $app = $self->{_map}->{$http_host};
	return $app->($env);
}
 
1;

__END__
 
=head1 SYNOPSIS
 
    use Plack::App::HostMap;
 
    my $foo_app = sub { ... };
    my $bar_app = sub { ... };
    my $baz_app = sub { ... };
 
    my $host_map = Plack::App::HostMap->new;

    #map different hosts to different apps
    $host_map->map("www.foo.com" => $foo_app);
    $host_map->map("bar.com" => $bar_app);
    $host_map->map("test.baz.com" => $baz_app);

    #map multiple hosts to same app conveniently
    $host_map->map(["www.foo.com", "foo.com", "beta.foo.com"] => $foo_app);

    #map all subdomains of a host to an app
    $host_map->map("*.foo.com" => $foo_app); #will match www.foo.com, foo.com, beta.foo.com, test.foo.com, beta.test.foo.com, etc...
 
    my $app = $host_map->to_app;
 
=head1 DESCRIPTION
 
Plack::App::HostMap is a PSGI application that can dispatch multiple
applications based on host name (a.k.a "virtual hosting"). L<Plack::App::URLMap> can
also dispatch applications based on host name. However, it also more versatile and can dispatch
applications based on URL paths. Because of this, if you were to use L<Plack::App::URLMap> to map
applications based on host name it would take linear time to find your app. So if you had N host name entries
to map to apps, you might have to search through N mappings before you find the right one. Because Plack::App::HostMap
is simpler and only dispatches based on host name, it can be much more efficient for this use case. Plack::App::HostMap
uses a hash to look up apps by host name, and thus instead of a linear time lookup is constant time. So if you had 2 apps
to dispatch by host name or 10,000, there shouldn't be a difference in terms of performance since hashes provide constant
time lookup.
 
=method map
 
    $host_map->map("www.foo.com" => $foo_app);
    $host_map->map("bar.com" => $bar_app);
 
Maps a host name to a PSGI application. You can also map multiple host names to
one application at once by providing an array reference:

    $host_map->map(["www.foo.com", "foo.com", "beta.foo.com"] => $foo_app);

If you need all subdomains of a host name to map to the same app, instead of listing them all out you can do so like this:

    $host_map->map("*.foo.com" => $foo_app); #will match www.foo.com, foo.com, beta.foo.com, test.foo.com, beta.test.foo.com, etc...

This will map any subdomain of foo.com to C<$foo_app>. This way you can point new subdomains at your app without
having to update your mappings.
 
=method mount
 
Alias for C<map>.
 
=method to_app
 
  my $handler = $host_map->to_app;
 
Returns the PSGI application code reference. Note that the
Plack::App::HostMap object is callable (by overloading the code
dereference), so returning the object itself as a PSGI application
should also work.
 
=head1 PERFORMANCE
 
As mentioned in the L<DESCRIPTION|/"DESCRIPTION">, Plack::App::HostMap should perform
much more efficiently than L<Plack::App::URLMap> when being used for host names. One
caveat would be with the C<*.> syntax that can be used with L<map|/"map">. If you have even
just one mapping with a C<*.> in it:

    $host_map->map("*.foo.com" => $foo_app);

Then on every request Plack::App::HostMap must call L<Domain::PublicSuffix>'s C<get_root_domain>
subroutine to parse out the root domain of the host. I can't imagine that this is very costly, but
maybe if you are receiving a lot of requests this could make a difference. If you find that to be the case,
instead of using the C<*.> syntax you could list out each individual possibility:

    $host_map->map("beta.foo.com" => $foo_app);
    $host_map->map("www.foo.com" => $foo_app);
    $host_map->map("foo.com" => $foo_app);

    #or
	$host_map->map(["beta.foo.com", "www.foo.com", "foo.com"] => $foo_app);

And the result would be that lookup is back to constant time. However, you might never see a performance hit
and it might be more worth it to use the convenient syntax.
