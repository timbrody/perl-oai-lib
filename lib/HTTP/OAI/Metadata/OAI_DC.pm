package HTTP::OAI::Metadata::OAI_DC;

use XML::LibXML;
use HTTP::OAI::Metadata;
@ISA = qw(HTTP::OAI::Metadata);

use strict;

our $OAI_DC_SCHEMA = 'http://www.openarchives.org/OAI/2.0/oai_dc/';
our $DC_SCHEMA = 'http://purl.org/dc/elements/1.1/';
our @DC_TERMS = qw( contributor coverage creator date description format identifier language publisher relation rights source subject title type );

sub new {
	my( $class, %self ) = @_;

	my $self = $class->SUPER::new( %self );

	if( exists $self{dc} && ref($self{dc}) eq 'HASH' )
	{
		my ($dom,$dc) =_oai_dc_dom();
		foreach my $term (@DC_TERMS)
		{
			foreach my $value (@{$self{dc}->{$term}||[]})
			{
				$dc->appendChild($dom->createElementNS($DC_SCHEMA, $term))->appendText( $value );
			}
		}
		$self->dom($dom);
	}

	$self;
}

sub dc
{
	my( $self ) = @_;

	my $dom = $self->dom;
	my $metadata = $dom->documentElement;

	return $self->{dc} if defined $self->{dc};

	my %dc = map { $_ => [] } @DC_TERMS;

	$self->_dc( $metadata, \%dc );

	return \%dc;
}

sub _dc
{
	my( $self, $node, $dc ) = @_;

	my $ns = $node->getNamespaceURI;
	$ns =~ s/\/?$/\//;

	if( $ns eq $DC_SCHEMA )
	{
		push @{$dc->{lc($node->localName)}}, $node->textContent;
	}
	elsif( $node->hasChildNodes )
	{
		for($node->childNodes)
		{
			next if $_->nodeType != XML_ELEMENT_NODE;
			$self->_dc( $_, $dc );
		}
	}
}

sub _oai_dc_dom {
	my $dom = XML::LibXML->createDocument();
	$dom->setDocumentElement(my $dc = $dom->createElement('oai_dc:dc'));
	$dc->setAttribute('xmlns:oai_dc','http://www.openarchives.org/OAI/2.0/oai_dc/');
	$dc->setAttribute('xmlns:dc','http://purl.org/dc/elements/1.1/');
	$dc->setAttribute('xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance');
	$dc->setAttribute('xsi:schemaLocation','http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd');
	return ($dom,$dc);
}

sub metadata { 
	my( $self, $md ) = @_;

	return $self->dom if @_ == 1;

	delete $self->{dc};
	$self->dom( $md );

	return if !defined $md;

	my $dc = $self->dc;

	my ($dom,$metadata) = _oai_dc_dom();

	foreach my $term (@DC_TERMS)
	{
		foreach my $value (@{$dc->{$term}})
		{
			$metadata->appendChild( $dom->createElementNS( $DC_SCHEMA, $term ) )->appendText( $value );
		}
	}

	$self->dom($dom)
}

sub toString {
	my $self = shift;
	my $str = "Open Archives Initiative Dublin Core (".ref($self).")\n";
	foreach my $term ( @DC_TERMS ) {
		for(@{$self->{dc}->{$term}}) {
			$str .= sprintf("%s:\t%s\n", $term, $_||'');
		}
	}
	$str;
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	if( exists($self->{dc}->{$elem}) ) {
		push @{$self->{dc}->{$elem}}, $hash->{Text};
	}
	$self->SUPER::end_element($hash);
}

sub end_document {
	my $self = shift;
	$self->SUPER::end_document();
	$self->metadata($self->dom);
}

1;

__END__

=head1 NAME

HTTP::OAI::Metadata::OAI_DC - Easy access to OAI Dublin Core

=head1 DESCRIPTION

HTTP::OAI::Metadata::OAI_DC provides a simple interface to parsing and generating OAI Dublin Core ("oai_dc").

=head1 SYNOPSIS

	use HTTP::OAI::Metadata::OAI_DC;

	my $md = new HTTP::OAI::Metadata(
		dc=>{title=>['Hello, World!','Hi, World!']},
	);

	# Prints "Hello, World!"
	print $md->dc->{title}->[0], "\n";

	my $xml = $md->metadata();

	$md->metadata($xml);

=head1 NOTE

HTTP::OAI::Metadata::OAI_DC will automatically (and silently) convert OAI version 1.x oai_dc records into OAI version 2.0 oai_dc records.
