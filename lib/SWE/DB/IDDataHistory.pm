package SWE::DB::IDDataHistory;
use strict;
use warnings;
use RCSFormat::File;
use Git::Parser::Log;

sub new_from_root_path ($$) {
  return bless {root_path => $_[1]}, $_[0];
} # new_from_root_path

sub _file_names_for_id ($$) {
  my ($self, $id) = @_;
  $id = sprintf '%d/%d', $id / 1000, $id % 1000;
  return ("ids/$id.txt", "ids/$id.prop", "ids/$id.history");
} # _file_names_for_id

sub get_data ($$) {
  my ($self, $id) = @_;
  my $root_path = $self->{root_path};
  my @name = grep { $root_path->child ($_)->is_file }
      $self->_file_names_for_id ($id);
  if (@name) {
    open my $log_file, '-|', "cd \Q$root_path\E && git log --format=raw @{[join ' ', map { quotemeta } @name]}"
        or die "git log: $!";
    local $/ = undef;
    my $log = <$log_file>;
    my $data = {revs => $self->_log_from_git ($log)};

    my $sw4_log_name = sprintf 'sw4cvs/ids/%d/%d.txt,v', $id / 1000, $id % 1000;
    push @{$data->{revs}}, @{$self->_log_from_rcs ('4', $sw4_log_name)};

    if (@{$data->{revs}} and defined $data->{revs}->[-1]->{sw3_name}) {
      my $sw3_name = delete $data->{revs}->[-1]->{sw3_name};
      $data->{sw3_name} = $sw3_name;
      my $sw3_log_name = sprintf 'sw3cvs/page/%s,v', $sw3_name;
      push @{$data->{revs}}, @{$self->_log_from_rcs ('3', $sw3_log_name)};
    }

    return {data => $data,
            last_modified => @{$data->{revs}} ? $data->{revs}->[0]->{time} : undef};
  } else {
    return {};
  }
} # get_data

sub _log_from_git ($$) {
  my $parsed_log = Git::Parser::Log->parse_format_raw ($_[1]);
  my $data = [];
  for my $commit (@{$parsed_log->{commits}}) {
    my $entry = {};
    $entry->{rev} = '6:'.$commit->{commit};
    $entry->{time} = $commit->{author}->{time};
    if ($commit->{body} =~ /updated by /) {
      $entry->{event} = 'updated';
    } elsif ($commit->{body} =~ /created by /) {
      $entry->{event} = 'created';
    } elsif ($commit->{body} =~ /^id-name association changed by /) {
      $entry->{event} = 'id-name';
    } else {
      $entry->{event} = 'misc';
      $entry->{comment} = $commit->{body};
    }
    push @$data, $entry;
  }
  return $data;
} # _log_from_git

sub _log_from_rcs ($$$) {
  my ($self, $prefix, $name) = @_;
  my $root_path = $self->{root_path};
  open my $file, '-|', "cd \Q$root_path\E && git show HEAD:\Q$name\E"
      or return [];
  local $/ = undef;
  my $bytes = <$file>;
  close $file;
  
  my $rcs = RCSFormat::File->new_from_stringref (\$bytes);
  my $data = [];
  for (@{$rcs->revision_numbers_sorted_by_date}) {
    my $rev = $rcs->get_revision_by_number ($_);
    my $entry = {};
    $entry->{rev} = $prefix.':'.$rev->number;
    $entry->{time} = $rev->date_as_epoch;
    my $log = $rev->log;
    if ($log =~ /updated by /) {
      $entry->{event} = 'updated';
    } elsif ($log =~ /created by /) {
      $entry->{event} = 'created';
    } elsif ($log =~ /^id-name association changed by /) {
      $entry->{event} = 'id-name';
    } elsif ($log =~ /^auto-committed$/) {
      $entry->{event} = 'updated';
    } elsif ($log =~ m{^converted from SuikaWiki3 <http://suika.fam.cx/gate/cvs/suikawiki/wikidata/page/([^<>]+)>$}) {
      $entry->{event} = 'from-sw3';
      $entry->{sw3_name} = $1;
    } else {
      $entry->{event} = 'misc';
      $entry->{comment} = $log;
    }
    push @$data, $entry;
  } # $rcs_rev
  return $data;
} # _log_from_rcs_path

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
