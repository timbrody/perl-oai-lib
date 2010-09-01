package HTTP::OAI::Identify;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw( :SAX );

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::Response );

sub new {
	my ($class,%args) = @_;
	delete $args{'harvestAgent'}; # Otherwise we get a memory cycle with $h->repository($id)!
	for(qw( adminEmail compression description )) {
		$args{$_} ||= [];
	}
	$args{handlers}->{description} ||= "HTTP::OAI::Metadata";
	my $self = $class->SUPER::new(%args);

	$self->verb('Identify') unless $self->verb;
	$self->baseURL($args{baseURL}) unless $self->baseURL;
	$self->adminEmail($args{adminEmail}) if !ref($args{adminEmail}) && !$self->adminEmail;
	$self->protocolVersion($args{protocolVersion} || '2.0') unless $self->protocolVersion;
	$self->repositoryName($args{repositoryName}) unless $self->repositoryName;
	$self->earliestDatestamp($args{earliestDatestamp}) unless $self->earliestDatestamp;
	$self->deletedRecord($args{deletedRecord}) unless $self->deletedRecord;
	$self->granularity($args{granularity}) unless $self->granularity;

	$self;
}

sub adminEmail {
	my $self = shift;
	push @{$self->{adminEmail}}, @_;
	return wantarray ?
		@{$self->{adminEmail}} :
		$self->{adminEmail}->[0]
}
sub baseURL { shift->headers->header('baseURL',@_) }
sub compression {
	my $self = shift;
	push @{$self->{compression}}, @_;
	return wantarray ?
		@{$self->{compression}} :
		$self->{compression}->[0];
}
sub deletedRecord { return shift->headers->header('deletedRecord',@_) }
sub description {
	my $self = shift;
	push(@{$self->{description}}, @_);
	return wantarray ?
		@{$self->{description}} :
		$self->{description}->[0];
};
sub earliestDatestamp { return shift->headers->header('earliestDatestamp',@_) }
sub granularity { return shift->headers->header('granularity',@_) }
sub protocolVersion { return shift->headers->header('protocolVersion',@_) };
sub repositoryName { return shift->headers->header('repositoryName',@_) };

sub next {
	my $self = shift;
	return shift @{$self->{description}};
}

sub generate_body {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','repositoryName',{},$self->repositoryName);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','baseURL',{},"".$self->baseURL);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','protocolVersion',{},$self->protocolVersion);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','adminEmail',{},$_) for $self->adminEmail;
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','earliestDatestamp',{},$self->earliestDatestamp||'0001-01-01');
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','deletedRecord',{},$self->deletedRecord||'no');
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','granularity',{},$self->granularity) if defined($self->granularity);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','compression',{},$_) for $self->compression;

	for($self->description) {
		g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','description',{},$_);
	}
}

sub start_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	$self->SUPER::start_element($hash);
	if( $elem eq 'description' && !$self->{"in_$elem"} ) {
		$self->{OLDHandler} = $self->get_handler();
		$self->set_handler(my $handler = $self->{handlers}->{$elem}->new());
		$self->description($handler);
		$self->{"in_$elem"} = $hash->{Depth};
		g_start_document($handler);
	}
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = $hash->{LocalName};
	my $text = $hash->{Text};
	if( defined($self->get_handler) ) {
		if( $elem eq 'description' && $self->{"in_$elem"} == $hash->{Depth} ) {
			$self->SUPER::end_document();
			$self->set_handler($self->{OLDHandler});
			$self->{"in_$elem"} = undef;
		}
	} elsif( $elem eq 'adminEmail' ) {
		$self->adminEmail($text);
	} elsif( $elem eq 'compression' ) {
		$self->compression($text);
	} elsif( $elem eq 'baseURL' ) {
		$self->baseURL($text);
	} elsif( $elem eq 'protocolVersion' ) {
		$text = '2.0' if $text =~ /\D/ or $text < 2.0;
		$self->protocolVersion($text);
	} elsif( defined($text) && length($text) ) {
		$self->headers->header($elem,$text);
	}
	$self->SUPER::end_element($hash);
}

1;

__END__

=head1 NAME

HTTP::OAI::Identify - Provide access to an OAI Identify response

=head1 SYNOPSIS

	use HTTP::OAI::Identify;

	my $i = new HTTP::OAI::Identify(
		adminEmail=>'billg@microsoft.com',
		baseURL=>'http://www.myarchives.org/oai',
		repositoryName=>'www.myarchives.org'
	);

	for( $i->adminEmail ) {
		print $_, "\n";
	}

=head1 METHODS

=over 4

=item $i = new HTTP::OAI::Identify(-baseURL=>'http://arXiv.org/oai1'[, adminEmail=>$email, protocolVersion=>'2.0', repositoryName=>'myarchive'])

This constructor method returns a new instance of the OAI::Identify module.

=item $i->version

Return the original version of the OAI response, according to the given XML namespace.

=item $i->headers

Returns an HTTP::OAI::Headers object. Use $headers->header('headername') to retrive field values.

=item $burl = $i->baseURL([$burl])

=item $eds = $i->earliestDatestamp([$eds])

=item $gran = $i->granularity([$gran])

=item $version = $i->protocolVersion($version)

=item $name = $i->repositoryName($name)

Returns and optionally sets the relevent header. NOTE: protocolVersion will always be '2.0'. Use $i->version to find out the protocol version used by the repository.

=item @addys = $i->adminEmail([$email])

=item @cmps = $i->compression([$cmp])

Returns and optionally adds to the multi-value headers.

=item @dl = $i->description([$d])

Returns the description list and optionally appends a new description $d. Returns an array ref of L<HTTP::OAI::Description|HTTP::OAI::Description>s, or an empty ref if there are no description.

=item $d = $i->next

Returns the next description or undef if no more description left.

=item $dom = $i->toDOM

Returns a XML::DOM object representing the Identify response.

=back
