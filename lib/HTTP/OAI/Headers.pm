package HTTP::OAI::Headers;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw( :SAX );

use vars qw( @ISA );

@ISA = qw( XML::SAX::Base );

my %VERSIONS = (
	'http://www.openarchives.org/oai/1.0/oai_getrecord' => '1.0',
	'http://www.openarchives.org/oai/1.0/oai_identify' => '1.0',
	'http://www.openarchives.org/oai/1.0/oai_listidentifiers' => '1.0',
	'http://www.openarchives.org/oai/1.0/oai_listmetadataformats' => '1.0',
	'http://www.openarchives.org/oai/1.0/oai_listrecords' => '1.0',
	'http://www.openarchives.org/oai/1.0/oai_listsets' => '1.0',
	'http://www.openarchives.org/oai/1.1/oai_getrecord' => '1.1',
	'http://www.openarchives.org/oai/1.1/oai_identify' => '1.1',
	'http://www.openarchives.org/oai/1.1/oai_listidentifiers' => '1.1',
	'http://www.openarchives.org/oai/1.1/oai_listmetadataformats' => '1.1',
	'http://www.openarchives.org/oai/1.1/oai_listrecords' => '1.1',
	'http://www.openarchives.org/oai/1.1/oai_listsets' => '1.1',
	'http://www.openarchives.org/oai/2.0/' => '2.0',
	'http://www.openarchives.org/oai/2.0/static-repository' => '2.0s',
);

sub new {
	my ($class,%args) = @_;
	my $self = bless {
		'field'=>{
			'xmlns'=>'http://www.openarchives.org/OAI/2.0/',
			'xmlns:xsi'=>'http://www.w3.org/2001/XMLSchema-instance',
			'xsi:schemaLocation'=>'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd'
		},
		%args,
	}, ref($class) || $class;
	return $self;
}

sub set_error
{
	my ($self,$error,$code) = @_;
	$code ||= 600;

	if( $self->get_handler ) {
		$self->get_handler->errors($error);
		$self->get_handler->code($code);
	} else {
		Carp::carp ref($self)." tried to set_error without having a handler to set it on!";
	}
}
sub generate_start {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	$handler->start_prefix_mapping({
			'Prefix'=>'xsi',
			'NamespaceURI'=>'http://www.w3.org/2001/XMLSchema-instance'
		});
	$handler->start_prefix_mapping({
			'Prefix'=>'',
			'NamespaceURI'=>'http://www.openarchives.org/OAI/2.0/'
		});
	g_start_element($handler,
		'http://www.openarchives.org/OAI/2.0/',
		'OAI-PMH',
			{
				'{http://www.w3.org/2001/XMLSchema-instance}schemaLocation'=>{
					'LocalName' => 'schemaLocation',
					'Prefix' => 'xsi',
					'Value' => 'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd',
					'Name' => 'xsi:schemaLocation',
					'NamespaceURI' => 'http://www.w3.org/2001/XMLSchema-instance',
				},
				'{}xmlns' => {
					'Prefix' => '',
					'LocalName' => 'xmlns',
					'Value' => 'http://www.openarchives.org/OAI/2.0/',
					'Name' => 'xmlns',
					'NamespaceURI' => '',
				},
				'{http://www.w3.org/2000/xmlns/}xsi'=>{
					'LocalName' => 'xsi',
					'Prefix' => 'xmlns',
					'Value' => 'http://www.w3.org/2001/XMLSchema-instance',
					'Name' => 'xmlns:xsi',
					'NamespaceURI' => 'http://www.w3.org/2000/xmlns/',
				},
			});

	g_data_element($handler,
		'http://www.openarchives.org/OAI/2.0/',
		'responseDate',
		{},
		$self->header('responseDate')
	);
	
	my $uri = URI->new($self->header('requestURL'));
	my $attr;
	my %QUERY = $uri->query_form;
	while(my ($key,$value) = each %QUERY) {
		$attr->{"{}$key"} = {
			'Name'=>$key,
			'LocalName'=>$key,
			'Value'=>$value,
			'Prefix'=>'',
			'NamespaceURI'=>'',
		};
	}
	$uri->query( undef );
	g_data_element($handler,
		'http://www.openarchives.org/OAI/2.0/',
		'request',
		$attr,
		$uri->as_string
	);
}

sub generate_end {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	g_end_element($handler,
		'http://www.openarchives.org/OAI/2.0/',
		'OAI-PMH'
	);

	$handler->end_prefix_mapping({
			'Prefix'=>'xsi',
			'NamespaceURI'=>'http://www.w3.org/2001/XMLSchema-instance'
		});
	$handler->end_prefix_mapping({
			'Prefix'=>'',
			'NamespaceURI'=>'http://www.openarchives.org/OAI/2.0/'
		});
}

sub header {
	my $self = shift;
	return @_ > 1 ? $self->{field}->{$_[0]} = $_[1] : $self->{field}->{$_[0]};
}

sub end_document {
	my $self = shift;
	$self->set_handler(undef);
	unless( defined($self->header('version')) ) {
		die "Not an OAI-PMH response: No recognised OAI-PMH namespace found before end of document\n";
	}
}

sub start_element {
	my ($self,$hash) = @_;
	return $self->SUPER::start_element($hash) if $self->{State};
	my $elem = $hash->{LocalName};
	my $attr = $hash->{Attributes};

	# Root element
	unless( defined($self->header('version')) ) {
		my $xmlns = $hash->{NamespaceURI};
		if( !defined($xmlns) || !length($xmlns) )
		{
			die "Error parsing response: no namespace on root element";
		}
		elsif( !exists $VERSIONS{lc($xmlns)} )
		{
			die "Error parsing response: unrecognised OAI namespace '$xmlns'";
		}
		else
		{
			$self->header('version',$VERSIONS{lc($xmlns)})
		}
	}
	# With a static repository, don't process any headers
	if( $self->header('version') && $self->header('version') eq '2.0s' ) {
		my %args = %{$self->{_args}};
		# ListRecords and the correct prefix
		if( $elem eq 'ListRecords' &&
			$elem eq $args{'verb'} && 
			$attr->{'{}metadataPrefix'}->{'Value'} eq $args{'metadataPrefix'} ) {
			$self->{State} = 1;
		# Start of the verb we're looking for
		} elsif(
			$elem ne 'ListRecords' && 
			$elem eq $args{'verb'}
		) {
			$self->{State} = 1;
		}
	} else {
		$self->{State} = 1;
	}
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = $hash->{LocalName};
	my $attr = $hash->{Attributes};
	my $text = $hash->{Text};
	# Static repository, don't process any headers
	if( $self->header('version') && $self->header('version') eq '2.0s' ) {
		# Stop parsing when we get to the closing verb
		if( $self->{State} &&
			$elem eq $self->{_args}->{'verb'} &&
			$hash->{NamespaceURI} eq 'http://www.openarchives.org/OAI/2.0/static-repository'
		) {
			$self->{State} = 0;
		}
		return $self->{State} ?
			$self->SUPER::end_element($hash) :
			undef;
	}
	$self->SUPER::end_element($hash);
	if( $elem eq 'responseDate' || $elem eq 'requestURL' ) {
		$self->header($elem,$text);
	} elsif( $elem eq 'request' ) {
		$self->header("request",$text);
		my $uri = new URI($text);
		$uri->query_form(map { ($_->{LocalName},$_->{Value}) } values %$attr);
		$self->header("requestURL",$uri);
	} else {
		die "Still in headers, but came across an unrecognised element: $elem";
	}
	if( $elem eq 'requestURL' || $elem eq 'request' ) {
		die "Oops! Root handler isn't \$self - $self != $hash->{State}"
			unless ref($self) eq ref($hash->{State}->get_handler);
		$hash->{State}->set_handler($self->get_handler);
	}
	return 1;
}

1;

__END__

=head1 NAME

HTTP::OAI::Headers - Encapsulation of 'header' values

=head1 METHODS

=over 4

=item $value = $hdrs->header($name,[$value])

Return and optionally set the header field $name to $value.

=back
