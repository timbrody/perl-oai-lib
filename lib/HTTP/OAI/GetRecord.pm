package HTTP::OAI::GetRecord;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw/ :SAX /;

use vars qw(@ISA);

@ISA = qw( HTTP::OAI::Response );

sub new {
	my ($class,%args) = @_;

	$args{handlers} ||= {};
	$args{handlers}->{header} ||= "HTTP::OAI::Header";
	$args{handlers}->{metadata} ||= "HTTP::OAI::Metadata";
	$args{handlers}->{about} ||= "HTTP::OAI::Metadata";

	my $self = $class->SUPER::new(%args);

	$self->verb('GetRecord') unless $self->verb;
	
	$self->{record} ||= [];
	$self->record($args{record}) if defined($args{record});

	return $self;
}

sub record {
	my $self = shift;
	$self->{record} = [shift] if @_;
	return wantarray ?
		@{$self->{record}} :
		$self->{record}->[0];
}
sub next { shift @{shift->{record}} }

sub generate_body {
	my ($self) = @_;

	for( $self->record ) {
		$_->set_handler($self->get_handler);
		$_->generate;
	}
}

sub start_element {
	my ($self,$hash) = @_;
	my $elem = $hash->{LocalName};
	if( $elem eq 'record' && !exists($self->{"in_record"}) ) {
		$self->{OLDHandler} = $self->get_handler;
		my $rec = HTTP::OAI::Record->new(
			version=>$self->version,
			handlers=>$self->{handlers},
		);
		$self->record($rec);
		$self->set_handler($rec);
		$self->{"in_record"} = $hash->{Depth};
	}
	$self->SUPER::start_element($hash);
}

sub end_element {
	my ($self,$hash) = @_;
	$self->SUPER::end_element($hash);
	my $elem = lc($hash->{LocalName});
	if( $elem eq 'record' &&
		exists($self->{"in_record"}) &&
		$self->{"in_record"} == $hash->{Depth} ) {
		$self->set_handler($self->{OLDHandler});
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::GetRecord - An OAI GetRecord response

=head1 DESCRIPTION

HTTP::OAI::GetRecord is derived from L<HTTP::OAI::Response|HTTP::OAI::Response> and provides access to the data contained in an OAI GetRecord response in addition to the header information provided by OAI::Response.

=head1 SYNOPSIS

	use HTTP::OAI::GetRecord();

	$res = new HTTP::OAI::GetRecord();
	$res->record($rec);

=head1 METHODS

=over 4

=item $gr = new HTTP::OAI::GetRecord

This constructor method returns a new HTTP::OAI::GetRecord object.

=item $rec = $gr->next

Returns the next record stored in the response, or undef if no more record are available. The record is returned as an L<OAI::Record|OAI::Record>.

=item @recs = $gr->record([$rec])

Returns the record list, and optionally adds a record to the end of the queue. GetRecord will only store one record at a time, so this method will replace any existing record if called with argument(s).

=item $dom = $gr->toDOM()

Returns an XML::DOM object representing the GetRecord response.

=back
