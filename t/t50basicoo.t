# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
#use Data::Dumper;
$loaded = 1;

print "ok 1\n";

init_log("testout/t00basicoo.log",1);

#list_formats();

%hsh=%Imager::formats;

print "# avaliable formats:\n";
for(keys %hsh) { print "# $_\n"; }

#print Dumper(\%hsh);

$img = Imager->new();

$img->open(file=>'testout/t10.jpg',type=>'jpeg') || print "failed: ",$img->{ERRSTR},"\n";
$img->open(file=>'testout/t10.png',type=>'png') || print "failed: ",$img->{ERRSTR},"\n";
$img->open(file=>'testout/t10.raw',type=>'raw',xsize=>150,ysize=>150) || print "failed: ",$img->{ERRSTR},"\n";
$img->open(file=>'testout/t10.ppm',type=>'ppm') || print "failed: ",$img->{ERRSTR},"\n";
$img->open(file=>'testout/t10.gif',type=>'gif') || print "failed: ",$img->{ERRSTR},"\n";

undef($img);

malloc_state();


print "ok 2\n";