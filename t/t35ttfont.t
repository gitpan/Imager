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

init_log("testout/t35ttfont.log",1);


if (!(i_has_format("tt")) ) {
    print "ok 2 # skip\n";
    print "ok 3 # skip\n";
} else {

     print "# has tt\n";
     $ENV{'T1LIB_CONFIG'}='fonts/t1/t1lib.config';
     i_init_fonts();
#     i_tt_set_aa(1);

     $bgcolor=i_color_new(255,0,0,0);
     $overlay=i_img_empty_ch(undef,200,70,3);

     @bbox=i_tt_bbox('arial.ttf',50.0,'XMCLH',5);
     print "bbox: ($bbox[0], $bbox[1]) - ($bbox[2], $bbox[3])\n";

     i_tt_cp($overlay,5,50,1,'arial.ttf',50.0,'XMCLH',5,1);
     i_draw($overlay,0,50,100,50,$bgcolor);

     open(FH,">testout/t35ttfont.ppm") || die "cannot open testout/t35ttfont.ppm\n";
     i_writeppm($overlay,fileno(FH));
     close(FH);

     print "ok 2\n";

     $bgcolor=i_color_set($bgcolor,200,200,200,0);
     $backgr=i_img_empty_ch(undef,280,150,3);

#     i_tt_set_aa(2);
     i_tt_text($backgr,10,100,$bgcolor,'arial.ttf',150.0,'test',4,1);

     open(FH,">testout/t35ttfont2.ppm") || die "cannot open testout/t35ttfont.ppm\n";
     i_writeppm($backgr,fileno(FH));
     close(FH);

     print "ok 3\n";

}

malloc_state();