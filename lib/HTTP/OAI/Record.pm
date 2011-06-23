package HTTP::OAI::Record;

use strict;
use warnings;

use vars qw(@ISA);

use HTTP::OAI::SAXHandler qw/ :SAX /;

@ISA = qw(HTTP::OAI::Encapsulation);

sub new {
	my ($class,%args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->{handlers} = $args{handlers};

	$self->header($args{header}) unless defined($self->header);
	$self->metadata($args{metadata}) unless defined($self->metadata);
	$self->{about} = $args{about} || [] unless defined($self->{about});

	$self->{in_record} = 0;

	$self->header(new HTTP::OAI::Header(%args)) unless defined $self->header;

	$self;
}

sub header { shift->_elem('header',@_) }
sub metadata { shift->_elem('metadata',@_) }
sub about {
	my $self = shift;
	push @{$self->{about}}, @_ if @_;
	return @{$self->{about}};
}

sub identifier { shift->header->identifier(@_) }
sub datestamp { shift->header->datestamp(@_) }
sub status { shift->header->status(@_) }
sub is_deleted { shift->header->is_deleted(@_) }

sub generate {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','record',{});
	$self->header->set_handler($handler);
	$self->header->generate;
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','metadata',{},$self->metadata) if defined($self->metadata);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','about',{},$_) for $self->about;
	g_end_element($handler,'http://www.openarchives.org/OAI/2.0/','record');
}

sub start_element {
	my ($self,$hash) = @_;
	return $self->SUPER::start_element( $hash ) if $self->{in_record};
	my $elem = lc($hash->{LocalName});
	if( $elem eq 'record' && $self->version eq '1.1' ) {
		$self->status($hash->{Attributes}->{'{}status'}->{Value});
	}
	elsif( $elem =~ /^header|metadata|about$/ ) {
		my $handler = $self->{handlers}->{$elem}->new()
			or die "Error getting handler for <$elem> (failed to create new $self->{handlers}->{$elem})";
		$self->set_handler($handler);
		$self->{in_record} = $hash->{Depth};
		g_start_document( $handler );
		$self->SUPER::start_element( $hash );
	}
}

sub end_element {
	my ($self,$hash) = @_;
	$self->SUPER::end_element($hash);
	if( $self->{in_record} == $hash->{Depth} ) {
		$self->SUPER::end_document();

		my $elem = lc ($hash->{LocalName});
		$self->$elem ($self->get_handler);
		$self->set_handler ( undef );
		$self->{in_record} = 0;
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::Record - Encapsulates an OAI record

=head1 SYNOPSIS

	use HTTP::OAI::Record;

	# Create a new HTTP::OAI Record
	my $r = new HTTP::OAI::Record();

	$r->header->identifier('oai:myarchive.org:oid-233');
	$r->header->datestamp('2002-04-01');
	$r->header->setSpec('all:novels');
	$r->header->setSpec('all:books');

	$r->metadata(new HTTP::OAI::Metadata(dom=>$md));
	$r->about(new HTTP::OAI::Metadata(dom=>$ab));

=head1 METHODS

=over 4

=item $r = new HTTP::OAI::Record( %opts )

This constructor method returns a new L<HTTP::OAI::Record> object.

Options (see methods below):

	header => $header
	metadata => $metadata
	about => [$about]

=item $r->header([HTTP::OAI::Header])

Returns and optionally sets the record header (an L<HTTP::OAI::Header> object).

=item $r->metadata([HTTP::OAI::Metadata])

Returns and optionally sets the record metadata (an L<HTTP::OAI::Metadata> object).

=item $r->about([HTTP::OAI::Metadata])

Optionally adds a new About record (an L<HTTP::OAI::Metadata> object) and returns an array of objects (may be empty).

=back

=head2 Header Accessor Methods

These methods are equivalent to C<< $rec->header->$method([$value]) >>.

=over 4

=item $r->identifier([$identifier])

Get and optionally set the record OAI identifier.

=item $r->datestamp([$datestamp])

Get and optionally set the record datestamp.

=item $r->status([$status])

Get and optionally set the record status (valid values are 'deleted' or undef).

=item $r->is_deleted()

Returns whether this record's status is deleted.

=back
