BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;

$loaded = 1;

$Imager::DEBUG=1;

$ENV{T1LIB_CONFIG}='fonts/t1/t1lib.config';
Imager::init(log=>'testout/t00basic.log');

$img=Imager->new() || die "unable to create image object\n";

$img->open(file=>'testout/t10.ppm',type=>'ppm') || die "failed: ",$img->{ERRSTR},"\n";

load_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";

print "ok\nok\n"; exit;

%hsh=(a=>35,b=>200,type=>lin_stretch);
$img->filter(%hsh);
unload_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
$img->write(type=>'ppm',file=>'testout/t60.jpg') || die "error in write()\n";


