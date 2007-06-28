package HTTP::OAI::MetadataFormat;

use strict;
use warnings;

use HTTP::OAI::SAXHandler qw/ :SAX /;

use vars qw( @ISA );
@ISA = qw( HTTP::OAI::Encapsulation );

sub new {
	my ($class,%args) = @_;

	my $self = $class->SUPER::new(%args);

	$self->metadataPrefix($args{metadataPrefix}) if $args{metadataPrefix};
	$self->schema($args{schema}) if $args{schema};
	$self->metadataNamespace($args{metadataNamespace}) if $args{metadataNamespace};

	$self;
}

sub metadataPrefix {
	my $self = shift;
	return @_ ? $self->{metadataPrefix} = shift : $self->{metadataPrefix}
}
sub schema {
	my $self = shift;
	return @_ ? $self->{schema} = shift : $self->{schema} }
sub metadataNamespace {
	my $self = shift;
	return @_ ? $self->{metadataNamespace} = shift : $self->{metadataNamespace}
}

sub generate {
	my ($self) = @_;
	return unless defined(my $handler = $self->get_handler);

	g_start_element($handler,'http://www.openarchives.org/OAI/2.0/','metadataFormat',{});
	
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','metadataPrefix',{},$self->metadataPrefix);
	g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','schema',{},$self->schema);
	if( defined($self->metadataNamespace) ) {
		g_data_element($handler,'http://www.openarchives.org/OAI/2.0/','metadataNamespace',{},$self->metadataNamespace);
	}
	
	g_end_element($handler,'http://www.openarchives.org/OAI/2.0/','metadataFormat');
}

sub end_element {
	my ($self,$hash) = @_;
	$self->SUPER::end_element($hash);
	my $elem = lc($hash->{LocalName});
	if( $elem eq 'metadataprefix' ) {
		$self->metadataPrefix($hash->{Text});
	} elsif( $elem eq 'schema' ) {
		$self->schema($hash->{Text});
	} elsif( $elem eq 'metadatanamespace' ) {
		$self->metadataNamespace($hash->{Text});
	}
}

1;

__END__

=head1 NAME

HTTP::OAI::MetadataFormat - Encapsulates OAI metadataFormat XML data

=head1 METHODS

=over 4

=item $mdf = new HTTP::OAI::MetadataFormat

This constructor method returns a new HTTP::OAI::MetadataFormat object.

=item $mdp = $mdf->metadataPrefix([$mdp])

=item $schema = $mdf->schema([$schema])

=item $ns = $mdf->metadataNamespace([$ns])

These methods respectively return and optionally set the metadataPrefix, schema and, metadataNamespace, for the metadataFormat record.

metadataNamespace is optional in OAI 1.x and therefore may be undef when harvesting pre OAI 2 repositories.

=back
