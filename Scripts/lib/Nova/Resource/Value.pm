# Copyright (c) 2006 Dave Vasilevsky
package Nova::Resource::Value;
use strict;
use warnings;

# Wrap shorter pkgnames
sub fromString {
	my ($class, @args) = @_;
	NRV->fromString(@args);
}
sub new {
	my ($class, @args) = @_;
	NRV->fromString(@args);
}

package Nova::Resource::Value::Hex;
sub new {
	my ($class, @args) = @_;
	NRVH->fromString(@args);
}

package Nova::Resource::Value::List;
sub new {
	my ($class, @args) = @_;
	NRVL->fromString(@args);
}


package NRV;
use base 'Nova::Base';

=head1 NAME

Nova::Resource::Value - A typed value in a resource

=head1 SYNOPSIS

  my $value = Nova::Resource::Value->fromString($str);
  my $dump = $value->dump;
  my $value = $value->value;

=cut

# my $value = Nova::Resource::Value->fromString($str);
#
# Parse a string to create a Value.
sub fromString {
	my ($class, $str) = @_;
	
	my ($subclass, @data) = (undef, $str);
	if ($str =~ /^"(.*)"$/) {
		($subclass, @data) = (S => $1);
	} elsif ($str =~ /^#(.*)$/) {
		($subclass, @data) = (C => hex($1));
	} elsif ($str =~ /^0x(.*)$/) {
		($subclass, @data) = (H => hex($1), length($1));
	}
	$subclass = defined $subclass ? "$class$subclass" : $class;
	return $subclass->new(@data);
}

sub _init {
	my ($self, $val) = @_;
	$self->{val} = $val;
}

# Return the value as a scalar
sub value {
	my ($self) = @_;
	return $self->{val};
}

# Return the value in printable format
sub dump {
	my ($self) = @_;
	return $self->{val};
}


package NRVS; # string
use base 'NRV';

sub _init {
	my ($self, $val) = @_;
	$self->SUPER::_init($val);
	
	# Fix escaped values
	$self->{val} =~ s/\\q/\"/g;
	$self->{val} =~ s/\\r/\n/g;
}


package NRVH; # hex
use base 'NRV';

sub _init {
	my ($self, $val, $length) = @_;
	$self->SUPER::_init($val);
	$self->{'length'} = $length;
}

sub dump {
	my ($self) = @_;
	return sprintf "0x%0*x", $self->{'length'}, $self->{val};
}


package NRVC; # color
use base 'NRV';

sub dump {
	my ($self) = @_;
	return sprintf "#%06x", $self->{val};
}


package NRVL; # list
use base 'NRV';

sub _init {
	my ($self, @vals) = @_;
	$self->SUPER::_init(\@vals);
}

sub dump {
	my ($self) = @_;
	return "\n" . join('',
		map { sprintf "  %3d: %s\n", $_, $self->{val}[$_] }
		(0..$#{$self->{val}})
	);
}


1;
