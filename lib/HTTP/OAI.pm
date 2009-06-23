package HTTP::OAI;

use strict;

our $VERSION = '3.22';

# perlcore
use Carp;
use Encode;

# http related stuff
use URI;
use HTTP::Headers;
use HTTP::Request;
use HTTP::Response;

# xml related stuff
use XML::SAX;
use XML::SAX::ParserFactory;
use XML::LibXML;
use XML::LibXML::SAX;
use XML::LibXML::SAX::Parser;
use XML::LibXML::SAX::Builder;

# debug
use HTTP::OAI::Debug;

# oai data objects
use HTTP::OAI::Encapsulation; # Basic XML handling stuff
use HTTP::OAI::Metadata; # Super class of all data objects
use HTTP::OAI::Error;
use HTTP::OAI::Header;
use HTTP::OAI::MetadataFormat;
use HTTP::OAI::Record;
use HTTP::OAI::ResumptionToken;
use HTTP::OAI::Set;

# parses OAI headers and other utility bits
use HTTP::OAI::Headers;

# generic superclasses
use HTTP::OAI::Response;
use HTTP::OAI::PartialList;

# oai verbs
use HTTP::OAI::GetRecord;
use HTTP::OAI::Identify;
use HTTP::OAI::ListIdentifiers;
use HTTP::OAI::ListMetadataFormats;
use HTTP::OAI::ListRecords;
use HTTP::OAI::ListSets;

# oai agents
use HTTP::OAI::UserAgent;
use HTTP::OAI::Harvester;
use HTTP::OAI::Repository;

$HTTP::OAI::Harvester::VERSION = $VERSION;

if( $ENV{HTTP_OAI_TRACE} )
{
	HTTP::OAI::Debug::level( '+trace' );
}
if( $ENV{HTTP_OAI_SAX_TRACE} )
{
	HTTP::OAI::Debug::level( '+sax' );
}

1;

__END__

=head1 NAME

HTTP::OAI - API for the OAI-PMH

=head1 DESCRIPTION

This is a stub module, you probably want to look at L<HTTP::OAI::Harvester|HTTP::OAI::Harvester> or L<HTTP::OAI::Repository|HTTP::OAI::Repository>.

=head1 SEE ALSO

You can find links to this and other OAI tools (perl, C++, java) at: http://www.openarchives.org/tools/tools.html.

Ed Summers L<Net::OAI::Harvester> module.

=head1 AUTHOR

Copyright 2004 Tim Brody <tdb01r@ecs.soton.ac.uk>

These modules are distributed under the same terms as Perl.
