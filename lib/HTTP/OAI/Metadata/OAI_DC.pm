package HTTP::OAI::Metadata::OAI_DC;

use strict;
use warnings;

use HTTP::OAI::Metadata;

use vars qw(@ISA @DC_TERMS);

@ISA = qw(HTTP::OAI::Metadata);

use XML::LibXML;

@DC_TERMS = qw( contributor coverage creator date description format identifier language publisher relation rights source subject title type );

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	my %args = @_;
	if( exists $args{dc} && ref($args{dc}) eq 'HASH' ) {
		my ($dom,$dc) =_oai_dc_dom();
		for(keys %{$args{dc}}) {
			$self->{dc}->{lc($_)} = $args{dc}->{$_};
			foreach my $value (@{$args{dc}->{$_}}) {
				$dc->appendChild($dom->createElement("dc:".lc($_)))->appendChild($dom->createTextNode($value));
			}
		}
		$self->dom($dom);
	}
	for(@DC_TERMS) {
		$self->{dc}->{$_} ||= [];
	}
	$self;
}

sub dc { shift->{dc} }

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
	my $self = shift;
	return $self->dom() unless @_;
	my $md = shift or return $self->dom(undef);
#	unless(my @nodes = $md->findnodes("*/*[local-name()='oai_dc' and namespace:uri()='http://purl.org/dc/elements/1.1/']")) {
	my $oai_dc;
	foreach my $nameSpace (qw(
		http://www.openarchives.org/OAI/2.0/oai_dc/
		http://purl.org/dc/elements/1.1/
	)) {
		foreach my $tagName (qw(dc oai_dc)) {
			($oai_dc) = $md->getElementsByTagNameNS($nameSpace,$tagName);
			last if $oai_dc;
		}
		last if $oai_dc;
	}
	unless( defined($oai_dc) ) {
		die "Unable to locate OAI Dublin Core in:\n".$md->toString;
		return $self->dom(undef);
	}
	$md = $oai_dc;

	my ($dom,$dc) = _oai_dc_dom();

	for ($md->getChildNodes) {
		next unless $_->nodeType == XML_ELEMENT_NODE;
		next unless $_->hasChildNodes;
		next unless ($_->getFirstChild->nodeType == XML_TEXT_NODE || $_->getFirstChild->nodeType == XML_CDATA_SECTION_NODE);
		$dc->appendChild($dom->createElement("dc:".$_->localName))->appendChild($dom->createTextNode($_->getFirstChild->toString));
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
