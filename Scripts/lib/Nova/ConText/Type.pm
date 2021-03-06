﻿# Copyright (c) 2006 Dave Vasilevsky

package Nova::ConText::Type;
use strict;
use warnings;

use base 'Nova::Base';
__PACKAGE__->fields(qw(type resFields));

use Nova::Util qw(deaccent);
use Nova::ConText::Resource;
use Nova::ConText::Value;

=head1 NAME

Nova::ConText::Type - Deal with type-specific information about resources in
ConText format.

=head1 SYNOPSIS

  my $type = Nova::ConText::Type->new($type);

  my @resFields = $type->inFieldNames(@rawFields);
  my %fields = $type->inFields(@vals);

  my @rawFields = $type->outFieldNames(@resFields);
  my @vals = $type->outFields(%fields);

=cut

our %REGISTERED;

sub init {
	my ($self, $type) = @_;
	$self->type($type);
	
	my $t = deaccent($type);
	if (exists $REGISTERED{$t}) {
		bless $self, $REGISTERED{$t}; # rebless
	}
}

# Get the field names which should be used, given the ones read from the ConText
sub inFieldNames {
	my ($self, @rawFields) = @_;
	$self->resFields(\@rawFields);
	return @rawFields;
}

# Get a hash of fields, given the values to be used for each field name
sub inFields {
	my ($self, @vals) = @_;
	return map { lc ($self->resFields->[$_]) => $vals[$_] } (0..$#vals);
}

# Get the field names to output to ConText, given the fields in a resource
sub outFieldNames {
	my ($self, @resFields) = @_;
	$self->resFields(\@resFields);
	return @resFields;
}

# Get the field values to output, given a hash of fields
sub outFields {
	my ($self, %fields) = @_;
	return map { $fields{lc $_} } @{$self->resFields};
}

# $pkg->register($type);
#
# Register an alternative package to handle the given type.
sub register {
	my ($pkg, $type) = @_;
	$Nova::ConText::Type::REGISTERED{$type} = $pkg;
}


package Nova::ConText::Type::StringList;
use base 'Nova::ConText::Type';
__PACKAGE__->register('str#');

sub inFields {
	my ($self, @vals) = @_;
	my @strings = splice @vals, $#{$self->resFields};
	@strings = map { $_->value } @strings;
	push @vals, Nova::ConText::Value::List->new(\@strings);
	
	return $self->SUPER::inFields(@vals);
}

sub outFields {
	my ($self, %fields) = @_;
	my @strings = @{$fields{strings}->value};
	$fields{n} = Nova::ConText::Value->new(scalar(@strings));
	my @vals = $self->SUPER::outFields(%fields);
	pop @vals;
	
	@strings = map { Nova::ConText::Value::String->new($_) } @strings;
	return (@vals, @strings);
}


package Nova::ConText::Type::Syst;
use base 'Nova::ConText::Type';
__PACKAGE__->register('syst');

# Mis-spelled field
sub inFieldNames {
	my ($self, @fields) = @_;
	map { s/Visiblility/Visibility/ } @fields;
	$self->SUPER::inFieldNames(@fields);
}


package Nova::ConText::Type::Outf;
use base 'Nova::ConText::Type';
__PACKAGE__->register('outf');

# Some things need to be hex
sub inFields {
	my ($self, @vals) = @_;
	my %fields = $self->SUPER::inFields(@vals);
	
	my %forceHex = map { $_ => 1 } (17, 30, 43);
	
	for my $modtype (grep /^modtype/, keys %fields) {
		next unless $forceHex{$fields{$modtype}->value};
		(my $modval = $modtype) =~ s/modtype/modval/;
		my $val = $fields{$modval}->value;
		$fields{$modval} = Nova::ConText::Value::Hex->new($val, 4);
	}
	
	return %fields;
}


package Nova::ConText::Type::Rank;
use base 'Nova::ConText::Type';
__PACKAGE__->register('rank');

# Missing some values in ConText!
sub inFields {
	my ($self, @vals) = @_;
	push @vals, (Nova::ConText::Value::String->new('')) x 2;
	$self->SUPER::inFields(@vals);
}


1;
