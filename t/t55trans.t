BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;

$loaded = 1;

#$Imager::DEBUG=1;

Imager::init(log=>'testout/t55trans.log');

$img=Imager->new() || die "unable to create image object\n";

print "ok 1\n";

$img->open(file=>'testimg/scale.ppm',type=>'ppm');
#$img->open(file=>'testimg/stor.jpg',type=>'jpeg');

$nimg=$img->transform(xexpr=>'x',yexpr=>'y+10*sin((x+y)/10)') || die "print $img->{'ERRSTR'}";

#	xopcodes=>[qw( x y Add)],yopcodes=>[qw( x y Sub)],parm=>[]


print "ok 2\n";
$nimg->write(type=>'ppm',file=>'testout/t55.ppm') || die "error in write()\n";

print "ok 3\n";