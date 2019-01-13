# NAME

Plack::App::HostMap - Map multiple Plack apps by host

# SYNOPSIS

       use Plack::App::HostMap;
    
       my $foo_app = sub { ... };
       my $bar_app = sub { ... };
       my $baz_app = sub { ... };
       my $foo_bar_app= sub { ... };
    
       my $host_map = Plack::App::HostMap->new;

       #map different hosts to different apps
       $host_map->map("www.foo.com" => $foo_app);
       $host_map->map("bar.com" => $bar_app);
       $host_map->map("test.baz.com" => $baz_app);

       #map multiple hosts to same app conveniently
       $host_map->map(["www.foo.com", "foo.com", "beta.foo.com"] => $foo_app);

       #map all subdomains of a host to an app
       $host_map->map("*.foo.com" => $foo_app); #will match www.foo.com, foo.com, beta.foo.com, test.foo.com, beta.test.foo.com, etc...

       #map multilevel subdomains of a host to an app
       $host_map->map("*.foo.bar.com" => $foo_bar_app); #will match test.foo.bar.com, beta.foo.bar.com, beta.test.foo.bar.com, etc...
    
       my $app = $host_map->to_app;
    

# DESCRIPTION

Plack::App::HostMap is a PSGI application that can dispatch multiple
applications based on host name (a.k.a "virtual hosting"). [Plack::App::URLMap](https://metacpan.org/pod/Plack::App::URLMap) can
also dispatch applications based on host name. However, it also more versatile and can dispatch
applications based on URL paths. Because of this, if you were to use [Plack::App::URLMap](https://metacpan.org/pod/Plack::App::URLMap) to map
applications based on host name it would take linear time to find your app. So if you had N host name entries
to map to apps, you might have to search through N mappings before you find the right one. Because Plack::App::HostMap
is simpler and only dispatches based on host name, it can be much more efficient for this use case. Plack::App::HostMap
uses a hash to look up apps by host name, and thus instead of a linear time lookup is constant time. So if you had 2 apps
to dispatch by host name or 10,000, there shouldn't be a difference in terms of performance since hashes provide constant
time lookup.

# METHODS

## map

       $host_map->map("www.foo.com" => $foo_app);
       $host_map->map("bar.com" => $bar_app);
    

Maps a host name to a PSGI application. You can also map multiple host names to
one application at once by providing an array reference:

    $host_map->map(["www.foo.com", "foo.com", "beta.foo.com"] => $foo_app);

If you need all subdomains of a host name to map to the same app, instead of listing them all out you can do so like this:

    $host_map->map("*.foo.com" => $foo_app); #will match www.foo.com, foo.com, beta.foo.com, test.foo.com, beta.test.foo.com, etc...

This will map any subdomain of foo.com to `$foo_app`. This way you can point new subdomains at your app without
having to update your mappings. Also, [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) will always match the most exact rule. For example, if you have the rules:

    $host_map->map("foo.com" => $foo_app);
    $host_map->map("*.foo.com" => $generic_foo_app);

And you request `foo.com`, it will match the `$foo_app`, not the `$generic_foo_app` since there is an explicit rule for `foo.com`. 
Also, if [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) cannot find an exact match for a host, [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) will always
match the first rule it finds. For instance, if you have these two rules:

    $host_map->map("*.beta.foo.com" => $beta_foo_app);
    $host_map->map("*.foo.com" => $foo_app);

And you request `beta.foo.com`, it will match the `$beta_foo_app`, not the `$foo_app` because [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) will find
`beta.foo.com` before `foo.com` when looking for a match. 

## mount

Alias for `map`.

## to\_app

     my $handler = $host_map->to_app;
    

Returns the PSGI application code reference. Note that the
Plack::App::HostMap object is callable (by overloading the code
dereference), so returning the object itself as a PSGI application
should also work.

## no\_cache

    $host_map->no_cache(1);

    #or
    my $host_map = Plack::App::HostMap->new(no_cache => 1);

This method only applies if you are using the `*.` syntax. By default, [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) will cache the corresponding
mappings for a domain. For instance, if you have:

    #beta.foo.com maps to *.foo.com
    beta.foo.com -> *.foo.com

Then after the first time that a url with the host `beta.foo.com` is requested, the domain beta.foo.com will be stored in a hash as 
a key with its value being `*.foo.com`, to specify that that's what it maps to.
If you are using the `*.` syntax, it is strongly recommended that you do not turn this off because it could speed things up a lot since you avoid
[Domain::PublicSuffix](https://metacpan.org/pod/Domain::PublicSuffix)'s parsing logic, as well as some regex and logic that [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) does to map the host to the right rule. However,
one particular reason why you might want to disable caching would be if you were pointing A LOT of domains at your app. For instance, if you have the rule:

    $host_map->map("*.foo.com" => $foo_app);

And you request many urls with different `foo.com` subdomains. This would take up a lot
of memory since each host you requested to your app would be stored as a key in a hash. Keep in mind this would need to be very many, since even 1,000
domains wouldn't take up much memory in a perl hash. Another possible reason
to disable this would be that someone could potentially use it to crash your application/server. If you had this rule:

    $host_map->map("*.foo.com" => $foo_app);

And someone were to request many foo.com domains:

    test.foo.com
    test1.foo.com
    test2.foo.com
    ...

Then each one would be cached as a key with its value being `foo.com`. If you are really worried about someone crashing your app, you could set ["no\_cache"](#no_cache) to 1, or instead of using
the `*.` syntax you could list out each individual host. Note: This only applies if you are using the `*.` syntax. If you do not use the `*.` syntax, the hash
that is used for caching is never even used. Also, in order to avoid letting the memory of your app grow uncontrollably, [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap) only caches hosts that
actually map to a rule that you set. This way even if caching is on, someone can not make tons of requests with different hosts to your server and crash it.

# PERFORMANCE

Note: This only applies if ["no\_cache"](#no_cache) is set to 1. 
As mentioned in the [DESCRIPTION](#description), Plack::App::HostMap should perform
much more efficiently than [Plack::App::URLMap](https://metacpan.org/pod/Plack::App::URLMap) when being used for host names. One
caveat would be with the `*.` syntax that can be used with [map](#map). If you have even
just one mapping with a `*.` in it:

    $host_map->map("*.foo.com" => $foo_app);

Then on every request where the host is not an exact match for a rule (meaning that the host either matches a `*.` syntax rule or no rule), 
Plack::App::HostMap must call [Domain::PublicSuffix](https://metacpan.org/pod/Domain::PublicSuffix)'s `get_root_domain`
subroutine to parse out the root domain of the host. I can't imagine that this is very costly, but
maybe if you are receiving a lot of requests this could make a difference. Also, [Plack::App::HostMap](https://metacpan.org/pod/Plack::App::HostMap)
does some additional logic to map your hosts. If you find that it is the case that it is affecting your performance,
instead of using the `*.` syntax you could list out each individual possibility:

    $host_map->map("beta.foo.com" => $foo_app);
    $host_map->map("www.foo.com" => $foo_app);
    $host_map->map("foo.com" => $foo_app);

    #or
    $host_map->map(["beta.foo.com", "www.foo.com", "foo.com"] => $foo_app);

And the result would be that lookup is back to constant time. However, you might never see a performance hit
and it might be more worth it to use the convenient syntax.

# AUTHOR

Adam Hopkins <srchulo@cpan.org>

# COPYRIGHT

Copyright 2019- Adam Hopkins

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
