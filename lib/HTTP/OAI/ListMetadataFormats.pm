package HTTP::OAI::ListMetadataFormats;

use strict;
use warnings;

use vars qw( @ISA );

@ISA = qw( HTTP::OAI::Response );

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{'metadataFormat'} ||= [];
	$self->verb('ListMetadataFormats') unless $self->verb;

	$self;
}

sub metadataFormat {
	my $self = shift;
	push(@{$self->{metadataformat}}, @_);
	return wantarray ?
		@{$self->{metadataformat}} :
		$self->{metadataformat}->[0];
}

sub next { shift @{shift->{metadataformat}} }

sub generate_body {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	for( $self->metadataFormat ) {
		$_->set_handler($handler);
		$_->generate;
	}
}

sub start_element {
	my ($self,$hash) = @_;
	if( lc($hash->{LocalName}) eq 'metadataformat' ) {
		my $mdf = new HTTP::OAI::MetadataFormat();
		$self->metadataFormat($mdf);
		$self->set_handler($mdf);
	}
	$self->SUPER::start_element($hash);
}

1;

__END__

=head1 NAME

HTTP::OAI::ListMetadataFormats - Provide access to an OAI ListMetadataFormats response

=head1 SYNOPSIS

	my $r = $h->ListMetadataFormats;

	# ListMetadataFormats doesn't use flow control
	while( my $rec = $r->next ) {
		print $rec->metadataPrefix, "\n";
	}

	die $r->message if $r->is_error;

=head1 METHODS

=over 4

=item $lmdf = new HTTP::OAI::ListMetadataFormats

This constructor method returns a new HTTP::OAI::ListMetadataFormats object.

=item $mdf = $lmdf->next

Returns either an L<HTTP::OAI::MetadataFormat|HTTP::OAI::MetadataFormat> object, or undef, if no more records are available.

=item @mdfl = $lmdf->metadataFormat([$mdf])

Returns the metadataFormat list and optionally adds a new metadataFormat, $mdf. Returns an array ref of L<HTTP::OAI::MetadataFormat|HTTP::OAI::MetadataFormat>s.

=item $dom = $lmdf->toDOM

Returns a XML::DOM object representing the ListMetadataFormats response.

=back
