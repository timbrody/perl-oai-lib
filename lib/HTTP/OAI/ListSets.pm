package HTTP::OAI::ListSets;

use strict;
use warnings;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::PartialList );

sub new {
	my ($class,%args) = @_;
	
	$args{handlers} ||= {};
	$args{handlers}->{description} ||= 'HTTP::OAI::Metadata';
	
	my $self = $class->SUPER::new(%args);
	
	$self->{in_set} = 0;

	$self;
}
 
sub set { shift->item(@_) }

sub generate_body {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	for( $self->set ) {
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
	my $elem = lc($hash->{Name});
	if( !$self->{in_set} ) {
		if( $elem eq 'set' ) {
			$self->set_handler(new HTTP::OAI::Set(
				version=>$self->version,
				handlers=>$self->{handlers}
			));
			$self->{'in_set'} = $hash->{Depth};
		} elsif( $elem eq 'resumptiontoken' ) {
			$self->set_handler(new HTTP::OAI::ResumptionToken(
				version=>$self->version
			));
			$self->{'in_set'} = $hash->{Depth};
		}
	}
	$self->SUPER::start_element($hash);
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	$self->SUPER::end_element($hash);
	if( $self->{'in_set'} == $hash->{Depth} )
	{
		if( $elem eq 'set' ) {
			$self->set( $self->get_handler );
			$self->set_handler( undef );
			$self->{in_set} = 0;
		} elsif( $elem eq 'resumptionToken' ) {
			$self->resumptionToken( $self->get_handler );
			$self->set_handler( undef );
			$self->{in_set} = 0;
		}
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::ListSets - Provide access to an OAI ListSets response

=head1 SYNOPSIS

	my $r = $h->ListSets();

	while( my $rec = $r->next ) {
		print $rec->setSpec, "\n";
	}

	die $r->message if $r->is_error;

=head1 METHODS

=over 4

=item $ls = new HTTP::OAI::ListSets

This constructor method returns a new OAI::ListSets object.

=item $set = $ls->next

Returns either an L<HTTP::OAI::Set|HTTP::OAI::Set> object, or undef, if no more records are available. Use $set->is_error to test whether there was an error getting the next record.

If -resume was set to false in the Harvest Agent, next may return a string (the resumptionToken).

=item @setl = $ls->set([$set])

Returns the set list and optionally adds a new set or resumptionToken, $set. Returns an array ref of L<HTTP::OAI::Set|HTTP::OAI::Set>s, with an optional resumptionToken string.

=item $token = $ls->resumptionToken([$token])

Returns and optionally sets the L<HTTP::OAI::ResumptionToken|HTTP::OAI::ResumptionToken>.

=item $dom = $ls->toDOM

Returns a XML::DOM object representing the ListSets response.

=back
