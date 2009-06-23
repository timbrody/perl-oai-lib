package HTTP::OAI::Harvester;

use strict;
use warnings;

use vars qw( @ISA );

@ISA = qw( HTTP::OAI::UserAgent );

sub new {
	my ($class,%args) = @_;
	my %ARGS = %args;
	delete @ARGS{qw(baseURL resume repository handlers onRecord)};
	my $self = $class->SUPER::new(%ARGS);

	$self->{'resume'} = exists($args{resume}) ? $args{resume} : 1;
	$self->{'handlers'} = $args{'handlers'};
	$self->{'onRecord'} = $args{'onRecord'};
	$self->agent('OAI-PERL/'.$HTTP::OAI::VERSION);

	# Record the base URL this harvester instance is associated with
	$self->{repository} =
		$args{repository} ||
		HTTP::OAI::Identify->new(baseURL=>$args{baseURL});
	Carp::croak "Requires repository or baseURL" unless $self->repository and $self->repository->baseURL;
	# Canonicalise
	$self->baseURL($self->baseURL);

	return $self;
}

sub resume {
	my $self = shift;
	return @_ ? $self->{resume} = shift : $self->{resume};
}

sub repository {
	my $self = shift;
	return $self->{repository} unless @_;
	my $id = shift;
	# Don't clobber a good existing base URL with a bad one
	if( $self->{repository} && $self->{repository}->baseURL ) {
		if( !$id->baseURL ) {
			Carp::carp "Attempt to set a non-existant baseURL";
			$id->baseURL($self->baseURL);
		} else {
			my $uri = URI->new($id->baseURL);
			if( $uri && $uri->scheme ) {
				$id->baseURL($uri->canonical);
			} else {
				Carp::carp "Ignoring attempt to use an invalid base URL: " . $id->baseURL;
				$id->baseURL($self->baseURL);
			}
		}
	}
	return $self->{repository} = $id;
}

sub baseURL {
	my $self = shift;
	return @_ ? 
		$self->repository->baseURL(URI->new(shift)->canonical) :
		$self->repository->baseURL();
}

sub version { shift->repository->version(@_); }

# build the methods for each OAI verb
foreach my $verb (qw( GetRecord Identify ListIdentifiers ListMetadataFormats ListRecords ListSets ))
{
	no strict "refs";
	*$verb = sub { shift->_oai( verb => $verb, @_ )};
}

sub _oai {
	my( $self, %args ) = @_;

	my $verb = $args{verb} or Carp::croak "Requires verb argument";

	my $handlers = delete($args{handlers}) || $self->{'handlers'};
	my $onRecord = delete($args{onRecord}) || $self->{'onRecord'};

	if( !$args{force} &&
		defined($self->repository->version) &&
		'2.0' eq $self->repository->version &&
		(my @errors = HTTP::OAI::Repository::validate_request(%args)) ) {
		return new HTTP::OAI::Response(
			code=>503,
			message=>'Invalid Request (use \'force\' to force a non-conformant request): ' . $errors[0]->toString,
			errors=>\@errors
		);
	}

	delete $args{force};
	# Get rid of any empty arguments
	for( keys %args ) {
		delete $args{$_} if !defined($args{$_}) || !length($args{$_});
	}

	# Check for a static repository (sets _static)
	if( !$self->{_interogated} ) {
		$self->interogate();
		$self->{_interogated} = 1;
	}
	
	if( 'ListIdentifiers' eq $verb &&
		defined($self->repository->version) && 
		'1.1' eq $self->repository->version ) {
		delete $args{metadataPrefix};
	}

	my $r = "HTTP::OAI::$verb"->new(
		harvestAgent => $self,
		resume => $self->resume,
		handlers => $handlers,
		onRecord => $onRecord,
	);
	$r->headers->{_args} = \%args;

	# Parse all the records if _static set
	if( defined($self->{_static}) && !defined($self->{_records}) ) {
		my $lmdf = HTTP::OAI::ListMetadataFormats->new(
			handlers => $handlers,
		);
		$lmdf->headers->{_args} = {
			%args,
			verb=>'ListMetadataFormats',
		};
		# Find the metadata formats
		$lmdf = $lmdf->parse_string($self->{_static});
		return $lmdf unless $lmdf->is_success;
		@{$self->{_formats}} = $lmdf->metadataFormat;
		# Extract all records
		$self->{_records} = {};
		for($lmdf->metadataFormat) {
			my $lr = HTTP::OAI::ListRecords->new(
				handlers => $handlers,
			);
			$lr->headers->{_args} = {
				%args,
				verb=>'ListRecords',
				metadataPrefix=>$_->metadataPrefix,
			};
			$lr->parse_string($self->{_static});
			@{$self->{_records}->{$_->metadataPrefix}} = $lr->record;
		}
		undef($self->{_static});
	}
	
	# Make the remote request and return the result
	if( !defined($self->{_records}) ) {
		$r = $self->request({baseURL=>$self->baseURL,%args},undef,undef,undef,$r);
		# Lets call next() for the user if she's using the callback interface
		if( $onRecord and $r->is_success and $r->isa("HTTP::OAI::PartialList") ) {
			$r->next;
		}
		return $r;
	# Parse our memory copy of the static repository
	} else {
		$r->code(200);
		# Format doesn't exist
		if( $verb =~ /^GetRecord|ListIdentifiers|ListRecords$/ &&
			!exists($self->{_records}->{$args{metadataPrefix}}) ) {
			$r->code(600);
			$r->errors(HTTP::OAI::Error->new(
				code=>'cannotDisseminateFormat',
			));
		# GetRecord
		} elsif( $verb eq 'GetRecord' ) {
			for(@{$self->{_records}->{$args{metadataPrefix}}}) {
				if( $_->identifier eq $args{identifier} ) {
					$r->record($_);
					return $r;
				}
			}
			$r->code(600);
			$r->errors(HTTP::OAI::Error->new(
				code=>'idDoesNotExist'
			));
		# Identify
		} elsif( $verb eq 'Identify' ) {
			$r = $self->repository();
		# ListIdentifiers
		} elsif( $verb eq 'ListIdentifiers' ) {
			$r->identifier(map { $_->header } @{$self->{_records}->{$args{metadataPrefix}}})
		# ListMetadataFormats
		} elsif( $verb eq 'ListMetadataFormats' ) {
			$r->metadataFormat(@{$self->{_formats}});
		# ListRecords
		} elsif( $verb eq 'ListRecords' ) {
			$r->record(@{$self->{_records}->{$args{metadataPrefix}}});
		# ListSets
		} elsif( $verb eq 'ListSets' ) {
			$r->errors(HTTP::OAI::Error->new(
				code=>'noSetHierarchy',
				message=>'Static Repositories do not support sets',
			));
		}
		return $r;
	}
}

sub interogate {
	my $self = shift;
	Carp::croak "Requires baseURL" unless $self->baseURL;
	
HTTP::OAI::Debug::trace($self->baseURL);
	my $r = $self->request(HTTP::Request->new(GET => $self->baseURL));
	return unless length($r->content);
	my $id = HTTP::OAI::Identify->new(
		handlers=>$self->{handlers},
	);
	$id->headers->{_args} = {verb=>'Identify'};
	$id->parse_string($r->content);
	if( $id->is_success && $id->version eq '2.0s' ) {
		$self->{_static} = $r->content;
		$self->repository($id);
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::Harvester - Agent for harvesting from Open Archives version 1.0, 1.1, 2.0 and static ('2.0s') compatible repositories

=head1 DESCRIPTION

C<HTTP::OAI::Harvester> is the harvesting front-end in the OAI-PERL library.

To harvest from an OAI-PMH compliant repository create an C<HTTP::OAI::Harvester> object using the baseURL option and then call OAI-PMH methods to request data from the repository. To handle version 1.0/1.1 repositories automatically you B<must> request C<Identify()> first.

It is recommended that you request an Identify from the Repository and use the C<repository()> method to update the Identify object used by the harvester.

When making OAI requests the underlying L<HTTP::OAI::UserAgent> module will take care of automatic redirection (http code 302) and retry-after (http code 503). OAI-PMH flow control (i.e. resumption tokens) is handled transparently by C<HTTP::OAI::Response>.

=head2 Static Repository Support

Static repositories are automatically and transparently supported within the existing API. To harvest a static repository specify the repository XML file using the baseURL argument to HTTP::OAI::Harvester. An initial request is made that determines whether the base URL specifies a static repository or a normal OAI 1.x/2.0 CGI repository. To prevent this initial request state the OAI version using an HTTP::OAI::Identify object e.g.

	$h = HTTP::OAI::Harvester->new(
		repository=>HTTP::OAI::Identify->new(
			baseURL => 'http://arXiv.org/oai2',
			version => '2.0',
	));

If a static repository is found the response is cached, and further requests are served by that cache. Static repositories do not support sets, and will result in a noSetHierarchy error if you try to use sets. You can determine whether the repository is static by checking the version ($ha->repository->version), which will be "2.0s" for static repositories.

=head1 FURTHER READING

You should refer to the Open Archives Protocol version 2.0 and other OAI documentation, available from http://www.openarchives.org/.

Note OAI-PMH 1.0 and 1.1 are deprecated.

=head1 BEFORE USING EXAMPLES

In the examples I use arXiv.org's and cogprints OAI interfaces. To avoid causing annoyance to their server administrators please contact them before performing testing or large downloads (or use other, less loaded, servers for testing).

=head1 SYNOPSIS

	use HTTP::OAI;

	my $h = new HTTP::OAI::Harvester(baseURL=>'http://arXiv.org/oai2');
	my $response = $h->repository($h->Identify)
	if( $response->is_error ) {
		print "Error requesting Identify:\n",
			$response->code . " " . $response->message, "\n";
		exit;
	}

	# Note: repositoryVersion will always be 2.0, $r->version returns
	# the actual version the repository is running
	print "Repository supports protocol version ", $response->version, "\n";

	# Version 1.x repositories don't support metadataPrefix,
	# but OAI-PERL will drop the prefix automatically
	# if an Identify was requested first (as above)
	$response = $h->ListIdentifiers(
		metadataPrefix=>'oai_dc',
		from=>'2001-02-03',
		until=>'2001-04-10'
	);

	if( $response->is_error ) {
		die("Error harvesting: " . $response->message . "\n");
	}

	print "responseDate => ", $response->responseDate, "\n",
		"requestURL => ", $response->requestURL, "\n";

	while( my $id = $response->next ) {
		print "identifier => ", $id->identifier;
		# Only available from OAI 2.0 repositories
		print " (", $id->datestamp, ")" if $id->datestamp;
		print " (", $id->status, ")" if $id->status;
		print "\n";
		# Only available from OAI 2.0 repositories
		for( $id->setSpec ) {
			print "\t", $_, "\n";
		}
	}

	# Using a handler
	$response = $h->ListRecords(
		metadataPrefix=>'oai_dc',
		handlers=>{metadata=>'HTTP::OAI::Metadata::OAI_DC'},
	);
	while( my $rec = $response->next ) {
		print $rec->identifier, "\t",
			$rec->datestamp, "\n",
			$rec->metadata, "\n";
		print join(',', @{$rec->metadata->dc->{'title'}}), "\n";
	}
	if( $rec->is_error ) {
		die $response->message;
	}

	# Offline parsing
	$I = HTTP::OAI::Identify->new();
	$I->parse_string($content);
	$I->parse_file($fh);

=head1 METHODS

=over 4

=item HTTP::OAI::Harvester->new( %params )

This constructor method returns a new instance of C<HTTP::OAI::Harvester>. Requires either an L<HTTP::OAI::Identify> object, which in turn must contain a baseURL, or a baseURL from which to construct an Identify object.

Any other parameters are passed to the L<HTTP::OAI::UserAgent> module, and from there to the L<LWP::UserAgent> module.

	$h = HTTP::OAI::Harvester->new(
		baseURL	=>	'http://arXiv.org/oai2',
		resume=>0, # Suppress automatic resumption
	)
	$id = $h->repository();
	$h->repository($h->Identify);

	$h = HTTP::OAI::Harvester->new(
		HTTP::OAI::Identify->new(
			baseURL => 'http://arXiv.org/oai2',
	));

=item $h->repository()

Returns and optionally sets the L<HTTP::OAI::Identify> object used by the Harvester agent.

=item $h->resume( [1] )

If set to true (default) resumption tokens will automatically be handled by requesting the next partial list during C<next()> calls.

=back

=head1 OAI-PMH Verbs

The 6 OAI-PMH Verbs are the requests supported by an OAI-PMH interface.

=head2 Error Messages

Use C<is_success()> or C<is_error()> on the returned object to determine whether an error occurred (see L<HTTP::OAI::Response>).

C<code()> and C<message()> return the error code (200 is success) and a human-readable message respectively. L<Errors|HTTP::OAI::Error> returned by the repository can be retrieved using the C<errors()> method:

	foreach my $error ($r->errors) {
		print $error->code, "\t", $error->message, "\n";
	}

Note: C<is_success()> is true for the OAI Error Code C<noRecordsMatch> (i.e. empty set), although C<errors()> will still contain the OAI error.

=head2 Flow Control

If the response contained a L<resumption token|HTTP::OAI::ResumptionToken> this can be retrieved using the $r->resumptionToken method.

=head2 Methods

These methods return an object subclassed from L<HTTP::Response> (where the class corresponds to the verb requested, e.g. C<GetRecord> requests return an C<HTTP::OAI::GetRecord> object).

=over 4

=item $r = $h->GetRecord( %params )

Get a single record from the repository identified by identifier, in format metadataPrefix.

	$gr = $h->GetRecord(
		identifier	=>	'oai:arXiv:hep-th/0001001', # Required
		metadataPrefix	=>	'oai_dc' # Required
	);
	$rec = $gr->next;
	die $rec->message if $rec->is_error;
	printf("%s (%s)\n", $rec->identifier, $rec->datestamp);
	$dom = $rec->metadata->dom;

=item $r = $h->Identify()

Get information about the repository.

	$id = $h->Identify();
	print join ',', $id->adminEmail;

=item $r = $h->ListIdentifiers( %params )

Retrieve the identifiers, datestamps, sets and deleted status for all records within the specified date range (from/until) and set spec (set). 1.x repositories will only return the identifier. Or, resume an existing harvest by specifying resumptionToken.

	$lr = $h->ListIdentifiers(
		metadataPrefix	=>	'oai_dc', # Required
		from		=>		'2001-10-01',
		until		=>		'2001-10-31',
		set=>'physics:hep-th',
	);
	while($rec = $lr->next)
	{
		{ ... do something with $rec ... }
	}
	die $lr->message if $lr->is_error;

=item $r = $h->ListMetadataFormats( %params )

List available metadata formats. Given an identifier the repository should only return those metadata formats for which that item can be disseminated.

	$lmdf = $h->ListMetadataFormats(
		identifier => 'oai:arXiv.org:hep-th/0001001'
	);
	for($lmdf->metadataFormat) {
		print $_->metadataPrefix, "\n";
	}
	die $lmdf->message if $lmdf->is_error;

=item $r = $h->ListRecords( %params )

Return full records within the specified date range (from/until), set and metadata format. Or, specify a resumption token to resume a previous partial harvest.

	$lr = $h->ListRecords(
		metadataPrefix=>'oai_dc', # Required
		from	=>	'2001-10-01',
		until	=>	'2001-10-01',
		set		=>	'physics:hep-th',
	);
	while($rec = $lr->next)
	{
		{ ... do something with $rec ... }
	}
	die $lr->message if $lr->is_error;

=item $r = $h->ListSets( %params )

Return a list of sets provided by the repository. The scope of sets is undefined by OAI-PMH, so therefore may represent any subset of a collection. Optionally provide a resumption token to resume a previous partial request.

	$ls = $h->ListSets();
	while($set = $ls->next)
	{
		print $set->setSpec, "\n";
	}
	die $ls->message if $ls->is_error;

=back

=head1 AUTHOR

These modules have been written by Tim Brody E<lt>tdb01r@ecs.soton.ac.ukE<gt>.
