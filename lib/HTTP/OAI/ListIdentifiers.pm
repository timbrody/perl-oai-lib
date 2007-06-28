package HTTP::OAI::ListIdentifiers;

use strict;
use warnings;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::PartialList );

sub new {
	my $class = shift;
	my %args = @_;
	
	my $self = $class->SUPER::new(@_);

	$self->{in_record} = 0;

	$self;
}

sub identifier { shift->item(@_) }

sub generate_body {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	for($self->identifier) {
		$_->set_handler($handler);
		$_->generate;
	}
	if( defined($self->resumptionToken) ) {
		$self->resumptionToken->set_handler($handler);
		$self->resumptionToken->generate;
	}
}

sub start_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	if( $elem eq 'header' ) {
		$self->set_handler(new HTTP::OAI::Header(
			version=>$self->version
		));
	} elsif( $elem eq 'resumptiontoken' ) {
		$self->set_handler(new HTTP::OAI::ResumptionToken(
			version=>$self->version
		));
	}
	$self->SUPER::start_element($hash);
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	$self->SUPER::end_element($hash);
	if( $elem eq 'header' ) {
		$self->identifier( $self->get_handler );
		$self->set_handler( undef );
	} elsif( $elem eq 'resumptiontoken' ) {
		$self->resumptionToken( $self->get_handler );
		$self->set_handler( undef );
	}
	# OAI 1.x
	if( $self->version eq '1.1' && $elem eq 'identifier' ) {
		$self->identifier(new HTTP::OAI::Header(
			version=>$self->version,
			identifier=>$hash->{Text},
			datestamp=>'0000-00-00',
		));
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::ListIdentifiers - Provide access to an OAI ListIdentifiers response

=head1 SYNOPSIS

	my $r = $h->ListIdentifiers;

	while(my $rec = $r->next) {
		print "identifier => ", $rec->identifier, "\n",
		print "datestamp => ", $rec->datestamp, "\n" if $rec->datestamp;
		print "status => ", ($rec->status || 'undef'), "\n";
	}
	
	die $r->message if $r->is_error;

=head1 METHODS

=over 4

=item $li = new OAI::ListIdentifiers

This constructor method returns a new OAI::ListIdentifiers object.

=item $rec = $li->next

Returns either an L<HTTP::OAI::Header|HTTP::OAI::Header> object, or undef, if there are no more records. Use $rec->is_error to test whether there was an error getting the next record (otherwise things will break).

If -resume was set to false in the Harvest Agent, next may return a string (the resumptionToken).

=item @il = $li->identifier([$idobj])

Returns the identifier list and optionally adds an identifier or resumptionToken, $idobj. Returns an array ref of L<HTTP::OAI::Header|HTTP::OAI::Header>s.

=item $dom = $li->toDOM

Returns a XML::DOM object representing the ListIdentifiers response.

=item $token = $li->resumptionToken([$token])

Returns and optionally sets the L<HTTP::OAI::ResumptionToken|HTTP::OAI::ResumptionToken>.

=back
