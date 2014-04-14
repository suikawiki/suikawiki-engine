package SWE::Object::Document::SWML;
use strict;
use warnings;
use base qw(SWE::Object::Document);
use Web::DOM::Document;

sub to_xml ($;%) {
  my ($self, %args) = @_;

  my $id = $self->id;

  $self->lock;
  
  my $id_prop = $self->{id_prop_db}->get_data ($id); ## XXX
  my $cache_prop = $self->{cache_prop_db}->get_data ($id); ## XXX
  my $doc = $self->{swml_to_xml}->($args{db}, $id, $id_prop, $cache_prop); ## XXX

  $self->unlock;

  if ($args{styled}) {
    my $pi = $doc->create_processing_instruction
        ('xml-stylesheet', 'href="http://suika.suikawiki.org/www/style/swml/structure"');
    $doc->insert_before ($pi, $doc->first_child);
  }
  
  return $doc;
}

sub to_xml_media_type ($) {
  return 'application/xml';
}

sub to_html_fragment ($;%) {
  my ($self, %args) = @_;

  my ($html_doc, $html_container);

  $self->lock;
  
  require SWE::Lang::XML2HTML;
  my $html_converter_version = $SWE::Lang::XML2HTML::ConverterVersion;
  
  my $id = $self->id;
  my $id_prop = $self->{id_prop_db}->get_data ($id); # XXX
  my $cache_prop = $self->{cache_prop_db}->get_data ($id); # XXX
  
  my $html_cache_version = $cache_prop->{'html-cache-version'};
  if (defined $html_cache_version and
      $html_cache_version >= $html_converter_version) {
    my $html_cached_hash = $cache_prop->{'html-cached-hash'} // 'x';
    my $current_hash = $id_prop->{hash} // '';
    if ($html_cached_hash eq $current_hash) {
      $html_doc = $self->db->id_html_cache->get_data ($id);
    }
  }

  unless ($html_doc) {
    my $xml_doc = $self->to_xml (%args);
    if ($xml_doc) {
      $html_doc = new Web::DOM::Document;
      $html_doc->strict_error_checking (0);
      $html_doc->dom_config->set_parameter
          ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
      $html_doc->manakai_is_html (1);
      
      $html_container = SWE::Lang::XML2HTML->convert
          ($self->{name}, $xml_doc => $html_doc, $self->{get_page_url}, 2); # XXX
      
      $self->db->id_html_cache->set_data ($id => $html_container);
      $cache_prop->{'html-cached-hash'} = $id_prop->{hash};
      $cache_prop->{'html-cache-version'} = $html_converter_version;
      $self->{cache_prop_db}->set_data ($id => $cache_prop); # XXX
    }
  } else {
    $html_doc->manakai_is_html (1);
    $html_container = $html_doc->create_document_fragment;
    while (@{$html_doc->child_nodes}) {
      $html_container->append_child ($html_doc->first_child);
    }
  }
  
  $self->unlock;

  return ($html_doc, $html_container);
}

1;
