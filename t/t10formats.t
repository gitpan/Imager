# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use lib qw(blib/lib blib/arch);

BEGIN { $| = 1; print "1..25\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager qw(:all);

$loaded = 1;
print "ok 1\n";



init_log("testout/t10formats.log",1);

i_has_format("jpeg") && print "# has jpeg\n";
i_has_format("tiff") && print "# has tiff\n";
i_has_format("png") && print "# has png\n";
i_has_format("gif") && print "# has gif\n";

$green=i_color_new(0,255,0,255);
$blue=i_color_new(0,0,255,255);
$red=i_color_new(255,0,0,255);

$img=Imager::ImgRaw::new(150,150,3);
$cmpimg=Imager::ImgRaw::new(150,150,3);

i_box_filled($img,70,25,130,125,$green);
i_box_filled($img,20,25,80,125,$blue);
i_arc($img,75,75,30,0,361,$red);
i_conv($img,[0.1, 0.2, 0.4, 0.2, 0.1]);

if (!i_has_format("jpeg")) {
  print "ok 2 # skip\n";
  print "ok 3 # skip\n";
} else {
  open(FH,">testout/t10.jpg") || die "cannot open testout/t10.jpg for writing\n";
  binmode(FH);
  i_writejpeg($img,fileno(FH),30);
  close(FH);

  print "ok 2\n";
  
  open(FH,"testout/t10.jpg") || die "cannot open testout/t10.jpg\n";
  binmode(FH);

  ($cmpimg,undef)=i_readjpeg(fileno(FH));
  close(FH);

  print "# jpeg average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
  print "ok 3\n";
}

if (!i_has_format("png")) {
  print "ok 4 # skip\n";
  print "ok 5 # skip\n";
} else {
  open(FH,">testout/t10.png") || die "cannot open testout/t10.png for writing\n";
  binmode(FH);
  i_writepng($img,fileno(FH)) || die "Cannot write testout/t10.png\n";
  close(FH);

  print "ok 4\n";

  open(FH,"testout/t10.png") || die "cannot open testout/t10.png\n";
  binmode(FH);
  $cmpimg=i_readpng(fileno(FH)) || die "Cannot read testout/t10.pmg\n";
  close(FH);

  print "# png average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
  print "ok 5\n";
}

open(FH,">testout/t10.raw") || die "Cannot open testout/t10.raw for writing\n";
binmode(FH);
i_writeraw($img,fileno(FH)) || die "Cannot write testout/t10.raw\n";
close(FH);

print "ok 6\n";

open(FH,"testout/t10.raw") || die "Cannot open testout/t15.raw\n";
binmode(FH);
$cmpimg=i_readraw(fileno(FH),150,150,3,3,0) || die "Cannot read testout/t10.raw\n";
close(FH);

print "# raw average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
print "ok 7\n";

open(FH,">testout/t10.ppm") || die "Cannot open testout/t10.ppm\n";
binmode(FH);
i_writeppm($img,fileno(FH)) || die "Cannot write testout/t10.ppm\n";
close(FH);

print "ok 8\n";

open(FH,"testout/t10.ppm") || die "Cannot open testout/t10.ppm\n";
binmode(FH);
$cmpimg=i_readppm(fileno(FH)) || die "Cannot read testout/t10.ppm\n";
close(FH);

print "ok 9\n";

if (!i_has_format("gif")) {
	for (10..23) { print "ok $_ # skip\n"; }
} else {
    open(FH,">testout/t10.gif") || die "Cannot open testout/t10.gif\n";
    binmode(FH);
    i_writegifmc($img,fileno(FH),7) || die "Cannot write testout/t10.gif\n";
    close(FH);

    print "ok 10\n";

    open(FH,"testout/t10.gif") || die "Cannot open testout/t10.gif\n";
    binmode(FH);
    $img=i_readgif(fileno(FH)) || die "Cannot read testout/t10.gif\n";
    close(FH);

    print "ok 11\n";

    open(FH,"testout/t10.gif") || die "Cannot open testout/t10.gif\n";
    binmode(FH);
    ($img, $palette)=i_readgif(fileno(FH));
    $img || die "Cannot read testout/t10.gif\n";
    close(FH);

    $palette=''; # just to skip a warning.

    print "ok 12\n";
    
    # check that reading interlaced/non-interlaced versions of 
    # the same GIF produce the same image
    open(FH, "<testimg/scalei.gif") || die "Cannot open testimg/scalei.gif";
    binmode FH;
    ($imgi) = i_readgif(fileno(FH));
    $imgi || die "Cannot read testimg/scalei.gif";
    close FH;
    print "ok 13\n";
    open FH, "<testimg/scale.gif" or die "Cannot open testimg/scale.gif";
    binmode FH;
    ($imgni) = i_readgif(fileno(FH));
    $imgni or die "Cannot read testimg/scale.gif";
    close FH;
    print "ok 14\n";

    open FH, ">testout/t10i.ppm" or die "Cannot create testout/t10i.ppm";
    binmode FH;
    i_writeppm($imgi, fileno(FH)) or die "Cannot write testout/t10i.ppm";
    close FH;

    open FH, ">testout/t10ni.ppm" or die "Cannot create testout/t10ni.ppm";
    binmode FH;
    i_writeppm($imgni, fileno(FH)) or die "Cannot write testout/t10ni.ppm";
    close FH;

    # compare them
    open FH, "<testout/t10i.ppm" or die "Cannot open testout/t10i.ppm";
    $datai = do { local $/; <FH> };
    close FH;
    open FH, "<testout/t10ni.ppm" or die "Cannot open testout/t10ni.ppm";
    $datani = do { local $/; <FH> };
    close FH;
    if ($datai eq $datani) {
      print "ok 15\n";
    }
    else {
      print "not ok 15\n";
    }

    # reading with a callback
    # various sizes to make sure the buffering works
    # requested size
    open FH, "<testimg/scale.gif" or die "Cannot open testimg/scale.gif";
    binmode FH;
    $img = i_readgif_callback(sub { my $tmp; read(FH, $tmp, $_[0]) and $tmp });
    close FH; 
    print $img ? "ok 16\n" : "not ok 16\n";

    print test_readgif_cb(1) ? "ok 17\n" : "not ok 17\n";
    print test_readgif_cb(512) ? "ok 18\n" : "not ok 18\n";
    print test_readgif_cb(1024) ? "ok 19\n" : "not ok 19\n";

    open FH, ">testout/t10_mc.gif" or die "Cannot open testout/t10_mc.gif";
    binmode FH;
    i_writegifmc($img, fileno(FH), 7) or die "Cannot write testout/t10_mc.gif";
    close(FH);

    # new writegif_gen
    # test webmap, custom errdiff map
    # (looks fairly awful)
    open FH, ">testout/t10_gen.gif" or die $!;
    binmode FH;
    i_writegif_gen(fileno(FH), { make_colors=>'webmap',
	                         translate=>'errdiff',
				 errdiff=>'custom',
				 errdiff_width=>2,
				 errdiff_height=>2,
				 errdiff_map=>[0, 1, 1, 0]}, $img)
      or die "Cannot writegif_gen";
    close FH;
    print "ok 20\n";    

    print "# the following tests are fairly slow\n";
    
    # test animation, mc_addi, error diffusion, ordered transparency
    my @imgs;
    my $sortagreen = i_color_new(0, 255, 0, 63);
    for my $i (0..4) {
      my $im = Imager::ImgRaw::new(200, 200, 4);
      for my $j (0..$i-1) {
	my $fill = i_color_new(0, 128, 0, 255 * ($i-$j)/$i);
	i_box_filled($im, 0, $j*40, 199, $j*40+40, $fill);
      }
      i_box_filled($im, 0, $i*40, 199, 199, $blue);
      push(@imgs, $im);
    }
    my @gif_delays = (10) x 5;
    my @gif_disposal = (2) x 5;
    open FH, ">testout/t10_anim.gif" or die $!;
    binmode FH;
    i_writegif_gen(fileno(FH), { make_colors=>'addi',
				 translate=>'closest',
				 gif_delays=>\@gif_delays,
				 gif_disposal=>\@gif_disposal,
				 transp=>'ordered',
				 tr_orddith=>'dot8'}, @imgs)
      or die "Cannot write anim gif";
    close FH;
    print "ok 21\n";

    unless (fork) {
      # this can SIGSEGV with some versions of giflib
      open FH, ">testout/t10_anim_cb.gif" or die $!;
      i_writegif_callback(sub { 
				print FH $_[0] 
			      },
			  -1, # max buffering
			  { make_colors=>'webmap',	
			    translate=>'closest',
			    gif_delays=>\@gif_delays,
			    gif_disposal=>\@gif_disposal,
			    #transp=>'ordered',
			    tr_orddith=>'dot8'}, @imgs)
	or die "Cannot write anim gif";
      close FH;
      print "ok 22\n";
      exit;
    }
    if (wait > 0 && $?) {
      print "not ok 22 # you probably need to patch giflib\n";
      print <<EOS;
#--- egif_lib.c	2000/12/11 07:33:12	1.1
#+++ egif_lib.c	2000/12/11 07:33:48
#@@ -167,6 +167,12 @@
#         _GifError = E_GIF_ERR_NOT_ENOUGH_MEM;
#         return NULL;
#     }
#+    if ((Private->HashTable = _InitHashTable()) == NULL) {
#+        free(GifFile);
#+        free(Private);
#+        _GifError = E_GIF_ERR_NOT_ENOUGH_MEM;
#+        return NULL;
#+    }
#
#     GifFile->Private = (VoidPtr) Private;
#     Private->FileHandle = 0;
EOS
    }
    @imgs = ();
    for $g (0..3) {
      my $im = Imager::ImgRaw::new(200, 200, 3);
      for my $x (0 .. 39) {
	for my $y (0 .. 39) {
	  my $c = i_color_new($x * 12, $y * 12, 32*$g+2*($x+$y), 255);
	  i_box_filled($im, $x*10, $y*10, $x*10+9, $y*10+9, $c);
	}
      }
      push(@imgs, $im);
    }
    # test giflib with multiple palettes
    # (it was meant to test the NS loop extension too, but that's broken)
    # this looks better with make_colors=>'addi', translate=>'errdiff'
    open FH, ">testout/t10_mult_pall.gif" or die "Cannot create file: $!";
    binmode FH;
    i_writegif_gen(fileno(FH), { make_colors=>'webmap',
				 translate=>'giflib',
				 gif_delays=>[ 50, 50, 50, 50 ],
				 #gif_loop_count => 50,
				 gif_each_palette => 1,
			       }, @imgs);
    close FH;
    print "ok 23\n";
				
}



if (!i_has_format("tiff")) {
  print "ok 24 # skip\n";
  print "ok 25 # skip\n";
} else {
  open(FH,">testout/t10.tiff") || die "cannot open testout/t10.jpg for writing\n";
  binmode(FH); 
  my $IO = Imager::io_new_fd(fileno(FH));
  i_writetiff_wiol($img, $IO);
  close(FH);

  print "ok 24\n";
  
  open(FH,"testout/t10.tiff") || die "cannot open testout/t10.jpg\n";
  binmode(FH);
  $IO = Imager::io_new_fd(fileno(FH));
  $cmpimg = i_readtiff_wiol($IO, -1);

  close(FH);

  print "# tiff average mean square pixel difference: ",sqrt(i_img_diff($img,$cmpimg))/150*150,"\n";
  print "ok 25\n";
}



sub test_readgif_cb {
  my ($size) = @_;

  open FH, "<testimg/scale.gif" or die "Cannot open testimg/scale.gif";
  binmode FH;
  my $img = i_readgif_callback(sub { my $tmp; read(FH, $tmp, $size) and $tmp });
  close FH; 
  return $img;
}

# malloc_state();
