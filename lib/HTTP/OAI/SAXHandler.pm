package HTTP::OAI::SAXHandler;

use strict;
use warnings;

use vars qw($DEBUG @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Data::Dumper; # debugging for here

$DEBUG = 0;

@ISA = qw( Exporter XML::SAX::Base );

@EXPORT_OK = qw( g_start_document g_start_element g_end_element g_data_element );
%EXPORT_TAGS = (SAX=>[qw( g_start_document g_start_element g_end_element g_data_element )]);

=pod

=head1 NAME

HTTP::OAI::SAXHandler - SAX2 utility filter

=head1 DESCRIPTION

This module provides utility methods for SAX2, including collapsing multiple "characters" events into a single event.

This module exports methods for generating SAX2 events with Namespace support. This *isn't* a fully-fledged SAX2 generator!

=over 4

=item $h = HTTP::OAI::SAXHandler->new()

Class constructor.

=cut

sub new {
	my ($class,%args) = @_;
	$class = ref($class) || $class;
	my $self = $class->SUPER::new(%args);
	$self->{Depth} = 0;
	$self;
}

sub g_start_document {
	my ($handler) = @_;
	$handler->start_document();
	$handler->start_prefix_mapping({
			'Prefix'=>'xsi',
			'NamespaceURI'=>'http://www.w3.org/2001/XMLSchema-instance'
	});
	$handler->start_prefix_mapping({
			'Prefix'=>'',
			'NamespaceURI'=>'http://www.openarchives.org/OAI/2.0/'
	});
}

sub g_data_element {
	my ($handler,$uri,$qName,$attr,$value) = @_;
	g_start_element($handler,$uri,$qName,$attr);
	if( ref($value) ) {
		$value->set_handler($handler);
		$value->generate;
	} else {
		$handler->characters({'Data'=>$value});
	}
	g_end_element($handler,$uri,$qName);
}

sub g_start_element {
	my ($handler,$uri,$qName,$attr) = @_;
	$attr ||= {};
	my ($prefix,$localName) = split /:/, $qName;
	unless(defined($localName)) {
		$localName = $prefix;
		$prefix = '';
	}
	$handler->start_element({
		'NamespaceURI'=>$uri,
		'Name'=>$qName,
		'Prefix'=>$prefix,
		'LocalName'=>$localName,
		'Attributes'=>$attr
	});
}

sub g_end_element {
	my ($handler,$uri,$qName) = @_;
	my ($prefix,$localName) = split /:/, $qName;
	unless(defined($localName)) {
		$localName = $prefix;
		$prefix = '';
	}
	$handler->end_element({
		'NamespaceURI'=>$uri,
		'Name'=>$qName,
		'Prefix'=>$prefix,
		'LocalName'=>$localName,
	});
}

sub current_state {
	my $self = shift;
	return $self->{State}->[$#{$self->{State}}];
}

sub current_element {
	my $self = shift;
	return $self->{Elem}->[$#{$self->{Elem}}];
}

sub start_document {
	my $self = shift;
warn "start_document: ".Dumper(shift)."\n" if $DEBUG;
	$self->SUPER::start_document();
}

sub end_document {
	my $self = shift;
	$self->SUPER::end_document();
warn "end_document\n" if $DEBUG;
}

# Char data is rolled together by this module
sub characters {
	my ($self,$hash) = @_;
	$self->{Text} .= $hash->{Data};
warn "characters: ".substr($hash->{Data}||'',0,40)."...\n" if $DEBUG;
}

sub start_element {
	my ($self,$hash) = @_;
	push @{$self->{Attributes}}, $hash->{Attributes};
	
	# Call characters with the joined character data
warn "start_element=>characters: ".substr($self->{Text}||'',0,40)."...\n" if $DEBUG && defined($self->{Text});
	$self->SUPER::characters({Data=>$self->{Text}}) if defined($self->{Text});
	$self->{Text} = undef;

warn "start_element: $hash->{Name}\n" if $DEBUG;
warn "(".Dumper($hash).")\n" if $DEBUG >= 2;
	$hash->{State} = $self;
	$hash->{Depth} = ++$self->{Depth};
	$self->SUPER::start_element($hash);
}

sub end_element {
	my ($self,$hash) = @_;

	# Call characters with the joined character data
warn "end_element=>characters: ".substr($self->{Text}||'',0,40)."...\n" if $DEBUG && defined($self->{Text});
	$self->SUPER::characters({Data=>$self->{Text}}) if defined($self->{Text}) && $self->{Text} =~ /\S/; # Trailing whitespace causes problems
	$hash->{Text} = $self->{Text};
	$self->{Text} = undef;
	
warn "end_element: $hash->{Name}\n" if $DEBUG;
	$hash->{Attributes} = pop @{$self->{Attributes}} || {};
warn "(".Dumper($hash).")\n" if $DEBUG >= 2;
	$hash->{State} = $self;
	$hash->{Depth} = $self->{Depth}--;
	$self->SUPER::end_element($hash);
}

sub entity_reference {
	my ($self,$hash) = @_;
	my $name = $hash->{Name};
warn "entity_reference: $name\n" if $DEBUG;
}

sub start_cdata {
	my $self = shift;
warn "start_cdata\n" if $DEBUG;
}

sub end_cdata {
	my $self = shift;
warn "end_cdata\n" if $DEBUG;
}

sub comment {
	my ($self,$hash) = @_;
	my $data = $hash->{Data};
warn "comment: $data\n" if $DEBUG;
}

sub doctype_decl {
	my ($self,$hash) = @_;
	my $name = $hash->{Name};
	# {SystemId,PublicId,Internal}
warn "doctype_decl: $hash->{Name}\n" if $DEBUG;
}

sub attlist_decl {
	my ($self,$hash) = @_;
	my $elementname = $hash->{ElementName};
	# {ElementName,AttributeName,Type,Default,Fixed}
warn "attlist_decl: $elementname\n" if $DEBUG;
}

sub xml_decl {
	my ($self,$hash) = @_;
#	my $version = $hash->{Version};
#	my $encoding = $hash->{Encoding};
#	my $standalone = $hash->{Standalone};
warn "xml_decl: ".Dumper($hash) if $DEBUG;
}

sub entity_decl {
	my ($self,$hash) = @_;
	my $name = $hash->{Name};
	# {Value,SystemId,PublicId,Notation}
warn "entity_decl: $name\n" if $DEBUG;
}

sub unparsed_decl {
	my ($self,$hash) = @_;
warn "unparsed_decl\n" if $DEBUG;
}

sub element_decl {
	my ($self,$hash) = @_;
	my $name = $hash->{Name};
	# {Model}
warn "element_decl: $name\n" if $DEBUG;
}

sub notation_decl {
	my ($self,$hash) = @_;
	my $name = $hash->{Name};
	# {Name,Base,SystemId,PublicId}
warn "notation_decl: $name\n" if $DEBUG;
}

sub processing_instruction {
	my ($self, $hash) = @_;
	# {Target,Data}
warn "processing_instruction: ".Dumper($hash)."\n" if $DEBUG;
}

package HTTP::OAI::FilterDOMFragment;

use vars qw( @ISA );

@ISA = qw( XML::SAX::Base );

# Trap things that don't apply to a balanced fragment
sub start_document {}
sub end_document {}
sub xml_decl {}

package XML::SAX::Debug;

use Data::Dumper;

use vars qw( @ISA $AUTOLOAD );

@ISA = qw( XML::SAX::Base );

sub DEBUG {
	my ($event,$self,$hash) = @_;
warn "$event(".Dumper($hash).")\n";
	my $superior = "SUPER::$event";
	$self->$superior($hash);
}

sub start_document { DEBUG('start_document',@_) }
sub end_document { DEBUG('end_document',@_) }
sub start_element { DEBUG('start_element',@_) }
sub end_element { DEBUG('end_element',@_) }
sub characters { DEBUG('characters',@_) }
sub xml_decl { DEBUG('xml_decl',@_) }

1;

__END__

=back

=head1 AUTHOR

Tim Brody <tdb01r@ecs.soton.ac.uk>
