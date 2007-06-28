package HTTP::OAI::PartialList;

use strict;
use warnings;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::Response );

sub new {
	my( $class, %args ) = @_;
	my $self = $class->SUPER::new(%args);
	$self->{onRecord} = delete $args{onRecord};
	$self->{item} ||= [];
	return $self;
}

sub resumptionToken { shift->headers->header('resumptionToken',@_) }

sub item {
	my $self = shift;
	if( defined($self->{onRecord}) ) {
		$self->{onRecord}->($_) for @_;
	} else {
		push(@{$self->{item}}, @_);
	}
	return wantarray ?
		@{$self->{item}} :
		$self->{item}->[0];
}

sub next {
	my $self = shift;
	return shift @{$self->{item}} if @{$self->{item}};
	return undef unless $self->{'resume'} and $self->resumptionToken;

	do {
		$self->resume(resumptionToken=>$self->resumptionToken);
	} while( $self->{onRecord} and $self->is_success and $self->resumptionToken );

	return $self->is_success ? $self->next : undef;
}

1;
