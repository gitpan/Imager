#!perl -w
use strict;
use Data::Dumper;
my $in = shift or die "No input name";
my $out = shift or die "No output name";
open(IN, $in) or die "Cannot open input $in: $!";
open(OUT, "> $out") or die "Cannot create $out: $!";
print OUT <<'EOS';
# AUTOMATICALLY GENERATED BY regops.perl
package Imager::Regops;
use strict;
require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK %Attr $MaxOperands $PackCode);
@ISA = qw(Exporter);
@EXPORT_OK = qw(%Attr $MaxOperands $PackCode);

EOS
my @ops;
my %attr;
my $opcode = 0;
my $max_opr = 0;
my $reg_pack;
while (<IN>) {
  if (/^\s*rbc_(\w+)/) {
    my $op = $1;
    push(@ops, uc "RBC_$op");
    # each line has a comment with the registers used - find the maximum
    # I could probably do this as one line, but let's not
    my @parms = /\b([rp][a-z])\b/g;
    $max_opr = @parms if @parms > $max_opr;
    my $types = join("", map {substr($_,0,1)} @parms);
    my ($result) = /->\s*([rp])/;
    $attr{$op} = { parms=>scalar @parms,
		   types=>$types,
		   func=>/\w+\(/?1:0,
		   opcode=>$opcode,
		   result=>$result
		 };
    print OUT "use constant RBC_\U$op\E => $opcode;\n";
    ++$opcode;
  }
  if (/^\#define RM_WORD_PACK \"(.)\"/) {
    $reg_pack = $1; 
  }
}
print OUT "\n\@EXPORT = qw(@ops);\n\n";
print OUT Data::Dumper->Dump([\%attr],["*Attr"]);
print OUT "\$MaxOperands = $max_opr;\n";
print OUT qq/\$PackCode = "$reg_pack";\n/;
print OUT <<'EOS';
1;

__END__

=head1 NAME

Imager::Regops - generated information about the register based VM

=head1 SYNOPSIS

  use Imager::Regops;
  $Imager::Regops::Attr{$opname}->{opcode} # opcode for given operator
  $Imager::Regops::Attr{$opname}->{parms} # number of parameters
  $Imager::Regops::Attr{$opname}->{types} # types of parameters
  $Imager::Regops::Attr{$opname}->{func} # operator is a function
  $Imager::Regops::Attr{$opname}->{result} # r for numeric, p for pixel result
  $Imager::Regops::MaxOperands; # maximum number of operands

=head1 DESCRIPTION

This module is generated automatically from regmach.h so we don't need to 
maintain the same information in at least one extra place.

At least that's the idea.

=head1 AUTHOR

Tony Cook, tony@develop-help.com

=head1 SEE ALSO

perl(1), Imager(3), http://www.eecs.umich.edu/~addi/perl/Imager/

=cut

EOS
close(OUT) or die "Cannot close $out: $!";
close IN;
