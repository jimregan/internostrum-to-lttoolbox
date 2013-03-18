#!/usr/bin/perl
# This program is free software, you can redistribute it 
# and/or modify it under the same terms as Perl itself.

use warnings;
use strict;
use utf8;

use Parse::RecDescent;
use Data::Dumper;
use File::Slurp;

binmode(STDOUT, ":utf8");

open(my $infile, "<", $ARGV[0]) or die "$!";
open(my $outfile, ">", "$ARGV[0].dix") or die "$!";

binmode($outfile, ":utf8");

my $input = read_file($infile) or die "Failed to read file";

$::RD_ERRORS = 1;
$::RD_WARN   = 1;
$::RD_HINT   = 1;

our %acute = (
	'a' => 'á',
	'e' => 'é',
	'i' => 'í',
	'o' => 'ó',
	'u' => 'ú'
);

our $header = "<dictionary>\n  <alphabet>abcedefghijklmnopqrstuvwxyzáéíóú</alphabet>\n";
our $footer = "  </section>\n</dictionary>\n";
our $sect = "  <section id=\"main\" type=\"standard\">\n";

my $gram = q {
 	eol: '\\n' | "\\r\\n"
	char: "'" /[aeiou]/ 
	{ $return = exists $main::acute{"$item[2]"} ? $main::acute{"$item[2]"} : "'" . $item[2] }
	| /[A-Za-z0-9]/ 
	{ $return = $item[1] }
	name: char(s)
	{ $return = join("", @{$item[1]}) }
	emptyline: /^$/

	sdef: "%symbol" '<' name '>' ';' '#' /.*/
	{ $return = '    <sdef n="' . $item[3] . '" c="' . $item[7] .'"/>' . "\n" }
	| "%symbol" '<' name '>' ';'
	{ $return = '    <sdef n="' . $item[3] . '"/>' . "\n" }
	sdefs: sdef(s)
	{ $return = "  <sdefs>\n" .  join("",@{$item[1]}) .  "  </sdefs>\n" }

	s: '<' name '>'
	{ $return = '<s n="' . $item[2] . '"/>' }

	plus: '+'
	{ $return = "<j/>" }

	left: char(s)
	{ my $out = join("",@{$item[1]}); $out =~ s/0*$//; $return = $out }

	rightpart: char | s | plus
	right: rightpart(s)
	{ $return = join("",@{$item[1]}) }

	pair: '(' left ':' right ')'	
	{ $return = "<p><l>" . $item[2] . "</l><r>" . $item[4] . "</r></p>" }

	par: '[' name ']'
	{ $return = '<par n="' . $item[2] . '"/>' }

	pairpar: pair | par

	parefirst:  '>' pairpar(s) '#' /.*/
	{ $return = "      <e>" . join("",@{$item[2]}) . '</e>' . '<!--' . $item[4] . '-->' . "\n" }
	| '>' pairpar(s)
	{ $return = "      <e>" . join("",@{$item[2]}) . "</e>\n" }
	| '#' /.*/
	{ $return = '<!--' . $item[2] . '-->' . "\n" }

	parectd: '|' pairpar(s) '#' /.*/
	{ $return = "      <e>" . join("",@{$item[2]}) . "</e>" . '<!--' . $item[4] . '-->' . "\n" }
	| '|' pairpar(s)
	{ $return = "      <e>" . join("",@{$item[2]}) . "</e>\n" }

	pardef: '[' name ']' parefirst parectd(s) ';' '#' /.*/ 
	{ $return = main::pardef($item[2]) . $item[4] . join("", @{$item[5]}) . "    </pardef> <!--" . $item[8] . "-->\n" } 
	| '[' name ']' parefirst parectd(s) ';' 
	{ $return = main::pardef($item[2]) . $item[4] . join("", @{$item[5]}) . "    </pardef>\n" } 

	pardefs: pardef(s)
	{ $return = "  <pardefs>\n" . join("", @{$item[1]}) . "  </pardefs>\n" }

	comment: '#' /.*/
	{ $return = "<!-- " . $item[2] . "-->\n" }

	comments: comment(s)
	{ $return = join("", @{$item[1]}) }

	dich: "%dic"

	dicent: pairpar(s) ';' '#' /.*/
	{ $return = "    <e>" . join("", @{$item[1]}) . "</e><!--" . $item[4] . "-->\n" }
	| pairpar(s) ';'
	{ $return = "    <e>" . join("", @{$item[1]}) . "</e>\n" }

	dict: comments(s?) sdefs comments(s?) pardefs comments(s?) dich dicent(s)
	{ $return =  join("",@{$item[1]}) . $main::header . $item[2] . join("",@{$item[3]}) . $item[4] . join("",@{$item[5]}) . $main::sect . join("",@{$item[7]}) . $main::footer }

};


sub pardef {
	return "    <pardef n=\"$_[0]\">\n";
}

my $parser = Parse::RecDescent->new($gram);

my $output = $parser->dict($input) or die "Failed to parse!";

print $outfile $output or die "$!";

