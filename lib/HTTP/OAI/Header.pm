package HTTP::OAI::Header;

use strict;
use warnings;

use POSIX qw/strftime/;

use vars qw(@ISA);

use HTTP::OAI::SAXHandler qw( :SAX );

@ISA = qw(HTTP::OAI::Encapsulation);

sub new {
	my ($class,%args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->identifier($args{identifier}) unless $self->identifier;
	$self->datestamp($args{datestamp}) unless $self->datestamp;
	$self->status($args{status}) unless $self->status;
	$self->{setSpec} ||= $args{setSpec} || [];

	$self;
}

sub identifier { shift->_elem('identifier',@_) }
sub now { return strftime("%Y-%m-%dT%H:%M:%SZ",gmtime()) }
sub datestamp {
	my $self = shift;
	return $self->_elem('datestamp') unless @_;
	my $ds = shift or return $self->_elem('datestamp',undef);
	if( $ds =~ /^(\d{4})(\d{2})(\d{2})$/ ) {
		$ds = "$1-$2-$3";
	} elsif( $ds =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/ ) {
		$ds = "$1-$2-$3T$4:$5:$6Z";
	}
	return $self->_elem('datestamp',$ds);
}
sub status { shift->_attr('status',@_) }
sub is_deleted { my $s = shift->status(); return defined($s) && $s eq 'deleted'; }

sub setSpec {
	my $self = shift;
	push(@{$self->{setSpec}},@_);
	@{$self->{setSpec}};
}

sub dom {
	my $self = shift;
	if( my $dom = shift ) {
		my $driver = XML::LibXML::SAX::Parser->new(
			Handler=>HTTP::OAI::SAXHandler->new(
				Handler=>$self
		));
		$driver->generate($dom->ownerDocument);
	} else {
		$self->set_handler(my $builder = XML::LibXML::SAX::Builder->new());
		g_start_document($self);
		$self->xml_decl({'Version'=>'1.0','Encoding'=>'UTF-8'});
		$self->characters({'Data'=>"\n"});
		$self->generate();
		$self->end_document();
		return $builder->result;
	}
}

sub generate {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	if( defined($self->status) ) {
		g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','header',
			{
				"{}status"=>{
					'Name'=>'status',
					'LocalName'=>'status',
					'Value'=>$self->status,
					'Prefix'=>'',
					'NamespaceURI'=>''
				}
			});
	} else {
		g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','header',{});
	}
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','identifier',{},$self->identifier);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','datestamp',{},($self->datestamp || $self->now));
	for($self->setSpec) {
		g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','setSpec',{},$_);
	}
	g_end_element($handler,'http://www.openarchives.org/OAI/2.0/','header');
}

sub end_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{LocalName});
	my $text = $hash->{Text};
	if( defined $text )
	{
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
	}
	if( $elem eq 'identifier' ) {
		die "HTTP::OAI::Header parse error: Empty identifier\n" unless $text;
		$self->identifier($text);
	} elsif( $elem eq 'datestamp' ) {
		warn "HTTP::OAI::Header parse warning: Empty datestamp for ".$self->identifier."\n" unless $text;
		$self->datestamp($text);
	} elsif( $elem eq 'setspec' ) {
		$self->setSpec($text);
	} elsif( $elem eq 'header' ) {
		$self->status($hash->{Attributes}->{'{}status'}->{Value});
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::Header - Encapsulates an OAI header structure

=head1 SYNOPSIS

	use HTTP::OAI::Header;

	my $h = new HTTP::OAI::Header(
		identifier=>'oai:myarchive.org:2233-add',
		datestamp=>'2002-04-12T20:31:00Z',
	);

	$h->setSpec('all:novels');

=head1 METHODS

=over 4

=item $h = new HTTP::OAI::Header

This constructor method returns a new C<HTTP::OAI::Header object>.

=item $h->identifier([$identifier])

Get and optionally set the record OAI identifier.

=item $h->datestamp([$datestamp])

Get and optionally set the record datestamp (OAI 2.0+).

=item $h->status([$status])

Get and optionally set the record status (valid values are 'deleted' or undef).

=item $h->is_deleted()

Returns whether this record's status is deleted.

=item @sets = $h->setSpec([$setSpec])

Returns the list of setSpecs and optionally appends a new setSpec C<$setSpec> (OAI 2.0+).

=item $dom_fragment = $id->generate()

Act as a SAX driver (use C<< $h->set_handler() >> to specify the filter to pass events to).

=back
