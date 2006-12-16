#!perl -w
use strict;
use Test::More tests => 23;

BEGIN { use_ok("Imager") }

#$Imager::DEBUG=1;

Imager::init('log'=>'testout/t66paste.log');

# the original smoke tests
my $img=Imager->new() || die "unable to create image object\n";

ok($img->open(file=>'testimg/scale.ppm',type=>'pnm'), "load test img");

my $nimg=Imager->new() or die "Unable to create image object\n";
ok($nimg->open(file=>'testimg/scale.ppm',type=>'pnm'), "load test img again");

ok($img->paste(img=>$nimg, top=>30, left=>30), "paste it")
  or print "# ", $img->errstr, "\n";;

ok($img->write(type=>'pnm',file=>'testout/t66.ppm'), "save it")
  or print "# ", $img->errstr, "\n";

# more stringent tests
{
  my $src = Imager->new(xsize => 100, ysize => 110);
  $src->box(filled=>1, color=>'FF0000');

  $src->box(filled=>1, color=>'0000FF', xmin => 20, ymin=>20,
            xmax=>79, ymax=>79);

  my $targ = Imager->new(xsize => 100, ysize => 110);
  $targ->box(filled=>1, color =>'00FFFF');
  $targ->box(filled=>1, color=>'00FF00', xmin=>20, ymin=>20, xmax=>79,
             ymax=>79);
  my $work = $targ->copy;
  ok($work->paste(src=>$src, left => 15, top => 10), "paste whole image");
  # build comparison image
  my $cmp = $targ->copy;
  $cmp->box(filled=>1, xmin=>15, ymin => 10, color=>'FF0000');
  $cmp->box(filled=>1, xmin=>35, ymin => 30, xmax=>94, ymax=>89, 
            color=>'0000FF');

  is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
     "compare pasted and expected");

  $work = $targ->copy;
  ok($work->paste(src=>$src, left=>2, top=>7, src_minx => 10, src_miny => 15),
     "paste from inside src");
  $cmp = $targ->copy;
  $cmp->box(filled=>1, xmin=>2, ymin=>7, xmax=>91, ymax=>101, color=>'FF0000');
  $cmp->box(filled=>1, xmin=>12, ymin=>12, xmax=>71, ymax=>71, 
            color=>'0000FF');
  is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
     "compare pasted and expected");

  # paste part source
  $work = $targ->copy;
  ok($work->paste(src=>$src, left=>15, top=>20, 
                  src_minx=>10, src_miny=>15, src_maxx=>80, src_maxy =>70),
     "paste src cropped all sides");
  $cmp = $targ->copy;
  $cmp->box(filled=>1, xmin=>15, ymin=>20, xmax=>84, ymax=>74, 
            color=>'FF0000');
  $cmp->box(filled=>1, xmin=>25, ymin=>25, xmax=>84, ymax=>74,
            color=>'0000FF');
  is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
     "compare pasted and expected");

  # go by width instead
  $work = $targ->copy;
  ok($work->paste(src=>$src, left=>15, top=>20,
                  src_minx=>10, src_miny => 15, width => 70, height => 55),
     "same but specify width/height instead");
  is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
     "compare pasted and expected");

  # use src_coords
  $work = $targ->copy;
  ok($work->paste(src=>$src, left => 15, top => 20,
                  src_coords => [ 10, 15, 80, 70 ]),
     "using src_coords");
  is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
     "compare pasted and expected");

  {
    # Issue #18712
    # supplying just src_maxx would set the internal maxy to undef
    # supplying just src_maxy would be ignored
    # src_maxy (or it's derived value) was being bounds checked against 
    # the image width instead of the image height
    $work = $targ->copy;
    my @warns;
    local $SIG{__WARN__} = sub { push @warns, "@_"; print "# @_"; };
    
    ok($work->paste(src=>$src, left => 15, top => 20,
		    src_maxx => 50),
       "paste with just src_maxx");
    ok(!@warns, "shouldn't warn");
    my $cmp = $targ->copy;
    $cmp->box(filled=>1, color => 'FF0000', xmin => 15, ymin => 20,
	      xmax => 64, ymax => 109);
    $cmp->box(filled=>1, color => '0000FF', xmin => 35, ymin => 40,
	      xmax => 64, ymax => 99);
    is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
       "check correctly pasted");

    $work = $targ->copy;
    @warns = ();
    ok($work->paste(src=>$src, left=>15, top=>20,
		    src_maxy => 60),
       "paste with just src_maxy");
    ok(!@warns, "shouldn't warn");
    $cmp = $targ->copy;
    $cmp->box(filled => 1, color => 'FF0000', xmin => 15, ymin => 20,
	      xmax => 99, ymax => 79);
    $cmp->box(filled => 1, color => '0000FF', xmin => 35, ymin => 40,
	      xmax => 94, ymax => 79);
    is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
       "check pasted correctly");

    $work = $targ->copy;
    @warns = ();
    ok($work->paste(src=>$src, left=>15, top=>20,
		    src_miny => 20, src_maxy => 105),
       "paste with src_maxy > source width");

    $cmp = $targ->copy;
    $cmp->box(filled => 1, color => 'FF0000', xmin => 15, ymin => 20,
	      ymax => 104);
    $cmp->box(filled => 1, color => '0000FF', xmin => 35, ymin => 20,
	      xmax => 94, ymax => 79);
    is(Imager::i_img_diff($work->{IMG}, $cmp->{IMG}), 0,
       "check pasted correctly");
  }
}
