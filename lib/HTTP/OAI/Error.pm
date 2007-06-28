package HTTP::OAI::Error;

use strict;
use warnings;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAG);

use vars qw(
	$PARSER
);

$PARSER = 600;

use Exporter;
use HTTP::OAI::SAXHandler qw( :SAX );

@ISA = qw(HTTP::OAI::Encapsulation Exporter);

@EXPORT = qw();
@EXPORT_OK = qw(%OAI_ERRORS);
%EXPORT_TAG = ();

my %OAI_ERRORS = (
	badArgument => 'The request includes illegal arguments, is missing required arguments, includes a repeated argument, or values for arguments have an illegal syntax.',
#	badGranularity => 'The values of the from and until arguments are illegal or specify a finer granularity than is supported by the repository.',
	badResumptionToken => 'The value of the resumptionToken argument is invalid or expired.',
	badVerb => 'Value of the verb argument is not a legal OAI-PMH verb, the verb argument is missing, or the verb argument is repeated.',
	cannotDisseminateFormat => 'The metadata format identified by the value given for the metadataPrefix argument is not supported by the item or by the repository',
	idDoesNotExist => 'The value of the identifier argument is unknown or illegal in this repository.',
	noRecordsMatch => 'The combination of the values of the from, until, set, and metadataPrefix arguments results in an empty list.',
	noMetadataFormats => 'There are no metadata formats available for the specified item.',
	noSetHierarchy => 'The repository does not support sets.'
);

sub new {
	my ($class,%args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->code($args{code});
	$self->message($args{message});

	$self;
}

sub code { shift->_elem('code',@_) }
sub message { shift->_elem('message',@_) }

sub toString {
	my $self = shift;
	return $self->code . " (\"" . ($self->message || 'No further information available') . "\")";
}

sub generate {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);
	Carp::croak ref($self)."::generate Error code undefined" unless defined($self->code);

	g_data_element($handler,
		'http://www.openarchives.org/OAI/2.0/',
		'error',
		{
			'{}code'=>{
				'LocalName' => 'code',
				'Prefix' => '',
				'Value' => $self->code,
				'Name' => 'code',
				'NamespaceURI' => '',
			},
		},
		($self->message || $OAI_ERRORS{$self->code} || '')
	);
}

1;

__END__

=head1 NAME

HTTP::OAI::Error - Encapsulates OAI error codes

=head1 METHODS

=over 4

=item $err = new HTTP::OAI::Error(code=>'badArgument',[message=>'An incorrect argument was supplied'])

This constructor method returns a new HTTP::OAI::Error object.

If no message is specified, and the code is a valid OAI error code, the appropriate message from the OAI protocol document is the default message.

=item $code = $err->code([$code])

Returns and optionally sets the error name.

=item $msg = $err->message([$msg])

Returns and optionally sets the error message.

=back

=head1 NOTE - noRecordsMatch

noRecordsMatch, without additional errors, is not treated as an error code. If noRecordsMatch was returned by a repository the HTTP::OAI::Response object will have a verb 'error' and will contain the noRecordsMatch error, however is_success will return true.

e.g.

	my $r = $ha->ListIdentifiers(metadataPrefix='oai_dc',from=>'3000-02-02');

	if( $r->is_success ) {
		print "Successful\n";
	} else {
		print "Failed\n";
	}

	print $r->verb, "\n";

Will print "Successful" followed by "error".
