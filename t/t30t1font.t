# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager qw(:all);
use Imager::Color;

$loaded = 1;
print "ok 1\n";

#$Imager::DEBUG=1;

init_log("testout/t30t1font.log",1);

if (!(i_has_format("t1")) ) {
  for (2..6) {
    print "ok $_ # skip t1lib unavailable or disabled\n";
  }
} else {

  print "# has t1\n";

  $fontname_pfb=$ENV{'T1FONTTESTPFB'}||'./fontfiles/dcr10.pfb';
  $fontname_afm=$ENV{'T1FONTTESTAFM'}||'./fontfiles/dcr10.afm';

  if (! -f $fontname_pfb) {
    print "# cannot find fontfile for truetype test $fontname_pfb\n";
    skip();	
  }

  if (! -f $fontname_afm) {
    print "# cannot find fontfile for truetype test $fontname_afm\n";
    skip();
  }

  i_init_fonts();
  i_t1_set_aa(1);

  $fnum=Imager::i_t1_new($fontname_pfb,$fontname_afm); # this will load the pfb font
  if ($fnum<0) { die "Couldn't load font $fontname_pfb"; }

  $bgcolor=Imager::Color->new(255,0,0,0);
  $overlay=Imager::ImgRaw::new(200,70,3);
  
  i_t1_cp($overlay,5,50,1,$fnum,50.0,'XMCLH',5,1)
    or print "not ";
  print "ok 2\n";

  i_draw($overlay,0,50,100,50,$bgcolor);

  @bbox=i_t1_bbox(0,50.0,'XMCLH',5);
  print "bbox: ($bbox[0], $bbox[1]) - ($bbox[2], $bbox[3])\n";

  open(FH,">testout/t30t1font.ppm") || die "cannot open testout/t35t1font.ppm\n";
  binmode(FH); # for os2
  $IO = Imager::io_new_fd( fileno(FH) );
  i_writeppm_wiol($overlay,$IO);
  close(FH);

  $bgcolor=Imager::Color::set($bgcolor,200,200,200,0);
  $backgr=Imager::ImgRaw::new(280,150,3);

  i_t1_set_aa(2);
  i_t1_text($backgr,10,100,$bgcolor,$fnum,150.0,'test',4,1)
    or print "not ";
  
  print "ok 3\n";
  
  open(FH,">testout/t30t1font2.ppm") || die "cannot open testout/t35t1font.ppm\n";
  binmode(FH);
  $IO = Imager::io_new_fd( fileno(FH) );
  i_writeppm_wiol($backgr, $IO);
  close(FH);

  $rc=i_t1_destroy($fnum);
  if ($fnum <0) { die "i_t1_destroy failed: rc=$rc\n"; }

  print "ok 4\n";

  print "# debug: ",join(" x ",i_t1_bbox(0,50,"eses",4) ),"\n";
  print "# debug: ",join(" x ",i_t1_bbox(0,50,"llll",4) ),"\n";

  unlink "t1lib.log"; # lose it if it exists
  init(t1log=>0);
  print -e("t1lib.log") ? "not ok 5\n" : "ok 5\n";
  init(t1log=>1);
  print -e("t1lib.log") ? "ok 6\n" : "not ok 6\n";
  init(t1log=>0);
  unlink "t1lib.log";
}

#malloc_state();
