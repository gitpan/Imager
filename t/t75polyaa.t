# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager qw(:all);


$Imager::DEBUG=1;
$loaded = 1;
print "ok 1\n";

init_log("testout/t75aapolyaa.log",1);

$green=i_color_new(0,255,0,0);
$red=i_color_new(255,0,0,0);


#$img=Imager->new(xsize=>400,ysize=>400);
$img=Imager->new(xsize=>20,ysize=>20);

$nums=100;
$rn=120;

@rand=map { rand($rn) } 0..$nums-1;

@angle=sort { $a<=>$b } map { rand(360) } 0..$nums-1;

@x=map { 200+(50+$rand[$_])*cos($angle[$_]/180*3.1415) } 0..$nums-1;
@y=map { 200+(50+$rand[$_])*sin($angle[$_]/180*3.1415) } 0..$nums-1;

#i_poly_aa($img,[50,300,290,200],[50,60,190,220],$green);

@x=(2,5,9);
@y=(2,10,3);

i_poly_aa($img->{IMG},\@x,\@y,$green);

push(@x,$x[0]);
push(@y,$y[0]);

$img->polyline(color=>$red,'x'=>\@x,'y'=>\@y,antialias=>0);
print "ok 2\n";

open(FH,">testout/t75.ppm") || die "Cannot open testout/t75.ppm\n";
i_writeppm($img->{IMG},fileno(FH)) || die "Cannot write testout/t75.ppm\n";
close(FH);

print "ok 3\n";

#malloc_state();
