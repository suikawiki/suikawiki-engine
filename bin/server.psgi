# -*- perl -*-
use strict;
use warnings;
use SWE::Web;
use Karasuma::Config::JSON;

my $config = Karasuma::Config::JSON->new_from_env;
if ($config->get_text ('web_has_reverse_proxy')) {
  $Wanage::HTTP::UseXForwardedScheme = 1;
  $Wanage::HTTP::UseXForwardedHost = 1;
}
$Warabe::App::MaxContentLength = 100*1024*1024;
return SWE::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2014-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
