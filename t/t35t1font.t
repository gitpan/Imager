# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
$loaded = 1;
print "ok 1\n";

init_log("testout/t35t1font.log",1);


if (!(i_has_format("t1")) ) {
    print "ok 2 # skip\n";
    print "ok 3 # skip\n";
} else {

     print "# has t1\n";
     $ENV{'T1LIB_CONFIG'}='fonts/t1/t1lib.config';
     i_init_fonts();
     i_t1_set_aa(1);


     $bgcolor=i_color_set(undef,255,0,0,0);
     $overlay=i_img_empty_ch(undef,100,70,3);

     i_t1_cp($overlay,5,50,1,0,50.0,'test',4,1);
     i_draw($overlay,0,50,100,50,$bgcolor);

     open(FH,">testout/t35t1font.ppm") || die "cannot open testout/t35t1font.ppm\n";
     i_writeppm($overlay,fileno(FH));
     close(FH);

     print "ok 2\n";

     $bgcolor=i_color_set($bgcolor,200,200,200,0);
     $backgr=i_img_empty_ch(undef,280,150,3);

     i_t1_set_aa(2);
     i_t1_text($backgr,10,100,$bgcolor,0,150.0,'test',4,1);

     open(FH,">testout/t35t1font2.ppm") || die "cannot open testout/t35t1font.ppm\n";
     i_writeppm($backgr,fileno(FH));
     close(FH);

     print "ok 3\n";

     print "# debug: ",join(" x ",i_t1_bbox(0,50,"eses",4) ),"\n";
     print "# debug: ",join(" x ",i_t1_bbox(0,50,"llll",4) ),"\n";
}

malloc_state();