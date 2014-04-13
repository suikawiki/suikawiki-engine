use strict;
use warnings;
use Path::Tiny;
use SWE::Web;
use Karasuma::Config::JSON;

my $root_path = path (__FILE__)->parent->parent;
my $config = Karasuma::Config::JSON->new_from_env;
return SWE::Web->psgi_app ($config, $root_path);

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
