BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
use Config;
$loaded = 1;

$Imager::DEBUG=0;

Imager::init('log'=>'testout/t60dyntest.log');

$img=Imager->new() || die "unable to create image object\n";

$img->open(file=>'testout/t10.ppm',type=>'ppm') || die "failed: ",$img->{ERRSTR},"\n";

$plug='dynfilt/dyntest.'.$Config{'so'};
load_plugin($plug) || die "unable to load plugin\n";

print "ok\nok\n"; exit;

%hsh=(a=>35,b=>200,type=>lin_stretch);
$img->filter(%hsh);
unload_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
$img->write(type=>'ppm',file=>'testout/t60.jpg') || die "error in write()\n";


