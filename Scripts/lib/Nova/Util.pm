﻿# Copyright (c) 2006 Dave Vasilevsky

package Nova::Util;
use strict;
use warnings;

use base qw(Exporter);

use List::Util qw(max sum);
use Text::Wrap qw();

our @EXPORT_OK = qw(deaccent commaNum termWidth columns wrap prettyPrint);

=head1 NAME

Nova::Util - Miscellaneous utilities

=head1 SYNOPSIS

  my $str = deaccent($str);
  my $str = commaNum($num);
  my $width = termWidth;

=cut

# $str = deaccent($str);
#
# Remove accents from a resource type, and canonicalizes is to lower-case.
# Eg: mïsn => misn
sub deaccent {
	my ($s) = @_;
use Carp; Carp::confess unless defined $s;
	$s =~ tr/\x{e4}\x{eb}\x{ef}\x{f6}\x{fc}\x{ff}/aeiouy/;
	return lc $s;
}

# Get the comma-delimited form of the given number. Eg: 1234567 => 1,234,567
sub commaNum {
	my ($n) = @_;
	return $n if $n < 1000;
	return commaNum(int($n/1000)) . sprintf ",%03d", $n % 1000;
}

# Get the width of the terminal
sub termWidth {
	if (eval { require Fink::CLI }) {
		return Fink::CLI::get_term_width();
	} elsif (exists $ENV{COLUMNS}) {
		return $ENV{COLUMNS};
	} else {
		return 80;
	}
}

# my $pct = _columnFormat($pct, @col);
#
# Get the %-fmt for a column
sub _columnFormat {
	my ($pct, @col) = @_;
	my $maxlen = max map { length($_) } @col;
	
	if ($pct =~ /\?/) { # Discover justification
		# Numbers justify right, strings left
		my ($tot, $num) = (0, 0);
		for my $item (@col) {
			$tot += length($item);
			$item =~ s/\D//g;
			$num += length($item);
			
			my $just = ($num > $tot / 2) ? '' : '-';
			$pct =~ s/\?/$just/;
		}
	}
	return "$pct$maxlen";
}

# columns($fmt, \@list, $colGen, %opts);
#
# Print something in columns.
# Opts include:
#	rank:	field to rank by
#	total:	last field is a total
sub columns {
	my ($fmt, $list, $colGen, %opts) = @_;
	unless (@$list) {
		print "No items found\n";
		return;
	}
	
	my @data = map { {
		cols => [ $colGen->($_) ],
		($opts{rank} ? (rank => $opts{rank}->($_)) : ()),
	} } @$list;
	@data = sort { $b->{rank} <=> $a->{rank} } @data if $opts{rank};
	
	my $col = 0;
	my $newfmt = '';
	while ($fmt =~ /%[^%]/) {
		(my ($pre, $pct), $fmt) = ($fmt =~ /^(.*?%)([^%\w]*)(.*)$/)
			or die "Bad format\n";
		$pct = _columnFormat($pct, map { $_->{cols}[$col] } @data);
		++$col;
		$newfmt .= "$pre$pct";
	}
	$newfmt .= $fmt;
	
	my $width = termWidth;
	for my $i (0..$#data) {
		my @cols = @{$data[$i]->{cols}};
		my $line = sprintf $newfmt, @cols;
		$width = length($line);
		
		print '-' x $width, "\n" if $i == $#data && $opts{total};
		printf "$line\n";
	}
}

# wrap($text, $first, $rest);
# 
# Wrap a line of text.
sub wrap {
	my ($text, $first, $rest) = @_;
	$first = '' unless defined $first;
	$rest = '' unless defined $rest;
	local $Text::Wrap::columns = termWidth;	return Text::Wrap::wrap($first, $rest, $text);
}

# prettyPrint($text);
#
# Print some text nicely
sub prettyPrint {
	my ($text) = @_;
	print wrap($text);
}

1;