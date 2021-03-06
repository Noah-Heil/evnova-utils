﻿# Copyright (c) 2006 Dave Vasilevsky
package Nova::Resource;
use strict;
use warnings;

use Storable;


# Common methods that aren't extremely important to the interface


# Textual representation of the given fields of this resource (or all fields,
# if none are specified).
sub dump {
	my ($self, @fields) = @_;
	@fields = $self->fieldNames unless @fields;
	
	my $dump = '';
	for my $field (@fields) {
		$dump .= sprintf "%s: %s\n", $field, $self->dumpField($field);
	}
	return $dump;
}

# The source file for this resource and friends
sub source { $_[0]->collection->source }

sub _multiFields {
	my ($self, $prefix, %opts) = @_;
	my %defaults = map { $_ => 1 } (
		exists $opts{defaults} ? @{$opts{defaults}} : (0, -1)
	);
	$prefix = qr/^$prefix/i;
	
	my (@fields, @vals);
	for my $field (grep { /$prefix/ } $self->fieldNames) {
		my $val = $self->$field;
		next if exists $defaults{$val};
		push @fields, $field;
		push @vals, $val;
	}
	
	return { fields => \@fields, vals => \@vals };
}

# my @props = $r->multi($prefix, $opts);
#
# Get a list of properties with the same prefix
sub multi {
	my ($self, $prefix, %opts) = @_;
	return @{$self->_multiFields($prefix, %opts)->{vals}};
}

# my @objs = $r->multiObjs($primary, @secondaries, $opts);
#
# Get a list of object-like hashes
sub multiObjs {
	my ($self, $primary, @secondaries) = @_;
	my $opts = { };
	if (ref($secondaries[-1])) {
		$opts = pop @secondaries;
	}
	
	my @k = @{$self->_multiFields($primary, %$opts)->{fields}};
	
	my @ret;
	for my $k (@k) {
		my %h;
		for my $v ($primary, @secondaries) {
			(my $kv = $k) =~ s/^$primary/$v/;
			$h{$v} = $self->$kv;
		}
		push @ret, \%h;
	}
	return @ret;
}

# Load all the results of a precalc (using Storable)
sub precalcAll {
	my ($self, $name, $code) = @_;
	return $self->collection->store($name) if $self->collection->store($name);
	
	my $file = Nova::Cache->storableCache($self->source, $name);
	my $cache;
	eval { $cache = retrieve $file };
	unless (defined $cache) {
		$cache = { };
		$code->($self, $cache);
		store $cache, $file;
	}
	return $self->collection->store($name => $cache);
}

# Wrapper for methods using precalculation optimization
# Load each cached item as it is needed
sub precalc {
	my ($self, $name, $code) = @_;
	return $self->collection->store($name) if $self->collection->store($name);
	
	my $cache = Nova::Cache->cacheForFile($self->source, $name);
	unless (exists $cache->{__FILLED__}) {
		$code->($self, $cache);
		$cache->{__FILLED__} = 1;
	}
	return $self->collection->store($name => $cache);
}

sub _calcDefaults {
	my ($self) = @_;
	
	my $defaults = $self->symref('_DEFAULT_FIELDS');
	unless (defined $$defaults) {
		my %hash = $self->fieldDefaults;
		while (my ($k, $v) = each %hash) {
			$k = lc $k;
			my @d = ref($v) ? @$v : ($v);
			$$defaults->{lc $k} = {
				list	=> \@d,
				hash	=> { map { $_ => 1 } @d },
			};
		}
	}
	return $$defaults;
}

# Get the default values for a field. Returned as a hash-ref, where keys
# exist for only the defaults values.
sub fieldDefault {
	my ($self, $field) = @_;	
	
	my $defaults = $self->_calcDefaults;
	return { '' => 1 } unless exists $defaults->{lc $field};
	return $defaults->{lc $field}{hash};
}

# Get the defaults for all relevant fields
sub fieldDefaults {
	my ($self) = @_;
	return ();
	# Override in subclasses
}

# Return the value of a field, or undef if it's the default value
sub fieldDefined {
	my ($self, $field) = @_;
	my $defaults = $self->fieldDefault($field);
	my $val = $self->$field;
	return undef if exists $defaults->{$val};
	return $val;
}

# Defined earlier
our %TYPES;

# Return a hash of fields for a brand new object
sub newFieldHash {
	my ($class, $type, $id, @fields) = @_;	
	$class = $class->_typeFor($type);
	
	my %hash;
	for my $field (@fields) {
		my $val;
		if (lc $field eq 'type') {
			$val = $type;
		} elsif (lc $field eq 'id') {
			$val = $id;
		} else {
			my $defaults = _calcDefaults($class);
			$val = exists $defaults->{lc $field}
				? $defaults->{lc $field}{list}[0] : '';
		}
		$hash{lc $field} = $val;
	}
	$hash{type} = $type;
	$hash{id} = $id;
	
	return \%hash;
}


1;
