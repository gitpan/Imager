# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..11\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
$loaded = 1;
print "ok 1\n";

init_log("testout/t10formats.log",1);


i_has_format("jpeg") && print "# has jpeg\n";
i_has_format("png") && print "# has png\n";
i_has_format("gif") && print "# has gif\n";

$green=i_color_set(undef,0,255,0,0);
$blue=i_color_set(undef,0,0,255,0);
$red=i_color_set(undef,255,0,0,0);

$img=i_img_empty_ch(undef,150,150,3);
$cmpimg=i_img_empty_ch(undef,150,150,3);

i_box_filled($img,70,25,130,125,$green);
i_box_filled($img,20,25,80,125,$blue);
i_arc($img,75,75,30,0,361,$red);
i_conv($img,[0.1, 0.2, 0.4, 0.2, 0.1]);

if (!i_has_format("jpeg")) {
    print "ok 2 # skip\n";
    print "ok 3 # skip\n";
} else {
    open(FH,">testout/t10.jpg") || die "cannot open testout/t10.jpg for writing\n";
    i_writejpeg($img,fileno(FH),30);
    close(FH);

    print "ok 2\n";

    open(FH,"testout/t10.jpg") || die "cannot open testout/t10.jpg\n";
    ($cmpimg,undef)=i_readjpeg($cmpimg,fileno(FH));
    close(FH);

    print "# jpeg average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
    print "ok 3\n";
}

if (!i_has_format("png")) {
    print "ok 4 # skip\n";
    print "ok 5 # skip\n";
} else {
    open(FH,">testout/t10.png") || die "cannot open testout/t10.png for writing\n";
    i_writepng($img,fileno(FH)) || die "Cannot write testout/t10.png\n";
    close(FH);

    print "ok 4\n";

    open(FH,"testout/t10.png") || die "cannot open testout/t10.png\n";
    $cmpimg=i_readpng($cmpimg,fileno(FH)) || die "Cannot read testout/t10.pmg\n";
    close(FH);

    print "# png average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
    print "ok 5\n";
}

open(FH,">testout/t10.raw") || die "Cannot open testout/t10.raw for writing\n";
i_writeraw($img,fileno(FH)) || die "Cannot write testout/t10.raw\n";
close(FH);

print "ok 6\n";

open(FH,"testout/t10.raw") || die "Cannot open testout/t15.raw\n";
$cmpimg=i_readraw($cmpimg,fileno(FH),150,150,3,3,0) || die "Cannot read testout/t10.raw\n";
close(FH);

print "# raw average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
print "ok 7\n";


open(FH,">testout/t10.ppm") || die "Cannot open testout/t10.ppm\n";
i_writeppm($img,fileno(FH)) || die "Cannot write testout/t10.ppm\n";
close(FH);

print "ok 8\n";

open(FH,"testout/t10.ppm") || die "Cannot open testout/t10.ppm\n";
$cmpimg=i_readppm($cmpimg,fileno(FH)) || die "Cannot read testout/t10.ppm\n";
close(FH);

print "ok 9\n";

if (!i_has_format("gif")) {
    print "ok 10 # skip\n";
    print "ok 11 # skip\n";
} else {
    open(FH,">testout/t10.gif") || die "Cannot open testout/t10.gif\n";
    i_writegif($img,fileno(FH),8) || die "Cannot write testout/t10.gif\n";
    close(FH);

    print "ok 10\n";

    open(FH,"testout/t10.gif") || die "Cannot open testout/t10.gif\n";
    $img=i_readgif(undef,fileno(FH)) || die "Cannot read testout/t10.gif\n";
    close(FH);

    print "ok 11\n";
}

malloc_state();