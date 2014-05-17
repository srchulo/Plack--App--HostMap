package Plack::App::HostMap;
use strict;
use warnings;
use parent qw/Plack::Component/;

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
	$self->{_dps} = Domain::PublicSuffix->new;
}

sub call {
    my ($self, $env) = @_;
 
    my $http_host = $env->{HTTP_HOST};
 
    if ($http_host and my $port = $env->{SERVER_PORT}) {
		$http_host =~ s/:$port$//;
    }

	if(keys %{$self->{_all_subdomains}}) { 
		my $root = $self->{_dps}->get_root_domain($http_host);	
		if($self->{_map}->{$root}) {
			warn "ROOT $root\n";
			$http_host = $root;
		}
	}

    return [404, [ 'Content-Type' => 'text/plain' ], [ "Not Found" ]] unless $self->{_map}->{$http_host};

	my $app = $self->{_map}->{$http_host};
    return $self->response_cb($app->($env), sub {
    });
}
 
1;
