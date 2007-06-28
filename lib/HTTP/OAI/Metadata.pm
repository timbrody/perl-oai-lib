package HTTP::OAI::Metadata;

use vars qw(@ISA);
@ISA = qw(HTTP::OAI::Encapsulation::DOM);

1;

__END__

=head1 NAME

HTTP::OAI::Metadata - Base class for data objects that contain DOM trees

=head1 SYNOPSIS

	use HTTP::OAI::Metadata;

	$xml = XML::LibXML::Document->new();
	$xml = XML::LibXML->new->parse( ... );

	$md = new HTTP::OAI::Metadata(dom=>$xml);

	print $md->dom->toString;

	my $dom = $md->dom(); # Return internal DOM tree

=head1 METHODS

=over 4

=item $md->dom( [$dom] )

Return and optionally set the XML DOM object that contains the actual metadata. If you intend to use the generate() method $dom must be a XML_DOCUMENT_NODE.

=back
