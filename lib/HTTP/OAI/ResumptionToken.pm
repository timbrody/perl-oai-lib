package HTTP::OAI::ResumptionToken;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw/ :SAX /;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::Encapsulation );

use overload "bool" => \&not_empty;

sub new {
	my ($class,%args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->resumptionToken($args{resumptionToken}) unless $self->resumptionToken;
	$self->expirationDate($args{expirationDate}) unless $self->expirationDate;
	$self->completeListSize($args{completeListSize}) unless $self->completeListSize;
	$self->cursor($args{cursor}) unless $self->cursor;

	$self;
}

sub resumptionToken { shift->_elem('resumptionToken',@_) }
sub expirationDate { shift->_attr('expirationDate',@_) }
sub completeListSize { shift->_attr('completeListSize',@_) }
sub cursor { shift->_attr('cursor',@_) }

sub not_empty { defined($_[0]->resumptionToken) and length($_[0]->resumptionToken) > 0 }
sub is_empty { !not_empty(@_) }

sub generate {
	my ($self) = @_;
	return unless (my $handler = $self->get_handler);
	my $attr;
	while(my ($key,$value) = each %{$self->_attr}) {
		$attr->{"{}$key"} = {'Name'=>$key,'LocalName'=>$key,'Value'=>$value,'Prefix'=>'','NamespaceURI'=>'http://www.openarchives.org/OAI/2.0/'};
	}
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','resumptionToken',$attr,$self->resumptionToken);
}

sub end_element {
	my ($self,$hash) = @_;
	$self->SUPER::end_element($hash);
	if( lc($hash->{Name}) eq 'resumptiontoken' ) {
		my $attr = $hash->{Attributes};
		$self->resumptionToken($hash->{Text});

		$self->expirationDate($attr->{'{}expirationDate'}->{'Value'});
		$self->completeListSize($attr->{'{}completeListSize'}->{'Value'});
		$self->cursor($attr->{'{}cursor'}->{'Value'});
	}
#warn "Got RT: $hash->{Text}";
}

1;

__END__

=head1 NAME

HTTP::OAI::ResumptionToken - Encapsulates an OAI resumption token

=head1 METHODS

=over 4

=item $rt = new HTTP::OAI::ResumptionToken

This constructor method returns a new HTTP::OAI::ResumptionToken object.

=item $token = $rt->resumptionToken([$token])

Returns and optionally sets the resumption token string.

=item $ed = $rt->expirationDate([$rt])

Returns and optionally sets the expiration date of the resumption token.

=item $cls = $rt->completeListSize([$cls])

Returns and optionally sets the cardinality of the result set.

=item $cur = $rt->cursor([$cur])

Returns and optionally sets the index of the first record (of the current page) in the result set.

=back

=head1 NOTE - Completing incomplete list

The final page of a record list which has been split using resumption tokens must contain an empty resumption token.
