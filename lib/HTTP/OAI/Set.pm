package HTTP::OAI::Set;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw/ :SAX /;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::Encapsulation );

sub new {
	my ($class,%args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->{handlers} = $args{handlers};
	
	$self->setSpec($args{setSpec});
	$self->setName($args{setName});
	$self->{setDescription} = $args{setDescription} || [];
	$self;
}

sub setSpec { shift->_elem('setSpec',@_) }
sub setName { shift->_elem('setName',@_) }
sub setDescription {
	my $self = shift;
	push(@{$self->{setDescription}}, @_);
	return @{$self->{setDescription}};
}
sub next { shift @{shift->{setDescription}} }

sub generate {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);
	g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','set',{});
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','setSpec',{},$self->setSpec);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','setName',{},$self->setName);
	for( $self->setDescription ) {
		$_->set_handler($handler);
		$_->generate;
	}
	g_end_element($handler,'http://www.openarchives.org/OAI/2.0/','set');
}

sub start_element {
	my ($self,$hash) = @_;
	my $elem = lc($hash->{Name});
	if( $elem eq 'setdescription' ) {
		$self->setDescription(my $d = $self->{handlers}->{description}->new(version=>$self->version));
		$self->set_handler($d);
		g_start_document($d);
	}
	$self->SUPER::start_element($hash);
}
sub end_element {
	my ($self,$hash) = @_;
	$self->SUPER::end_element($hash);
	my $elem = lc($hash->{Name});
	if( $elem eq 'setspec' ) {
		die ref($self)." Parse error: Empty setSpec\n" unless $hash->{Text};
		$self->setSpec($hash->{Text});
	} elsif( $elem eq 'setname' ) {
		warn ref($self)." Parse error: Empty setName\n", return
			unless $hash->{Text};
		$self->setName($hash->{Text});
	} elsif( $elem eq 'setdescription' ) {
		$self->SUPER::end_document();
		$self->set_handler(undef);
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::Set - Encapsulates OAI set XML data

=head1 METHODS

=over 4

=item $spec = $s->setSpec([$spec])

=item $name = $s->setName([$name])

These methods return respectively, the setSpec and setName of the OAI Set.

=item $descs = $s->setDescription([$desc])

Returns and optionally adds the list of set descriptions. Returns a reference to an array of L<HTTP::OAI::Description|HTTP::OAI::Description> objects.

=back
