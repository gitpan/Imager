#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use strict;
use Test::More tests => 94;
BEGIN { use_ok(Imager => ':all') }
use Imager::Test qw(diff_text_with_nul is_color3);

#$Imager::DEBUG=1;

init_log("testout/t30t1font.log",1);

my $deffont = './fontfiles/dcr10.pfb';

my $fontname_pfb=$ENV{'T1FONTTESTPFB'}||$deffont;
my $fontname_afm=$ENV{'T1FONTTESTAFM'}||'./fontfiles/dcr10.afm';

SKIP:
{
  if (!(i_has_format("t1")) ) {
    skip("t1lib unavailable or disabled", 93);
  }
  elsif (! -f $fontname_pfb) {
    skip("cannot find fontfile for type 1 test $fontname_pfb", 93);
  }
  elsif (! -f $fontname_afm) {
    skip("cannot find fontfile for type 1 test $fontname_afm", 93);
  }

  print "# has t1\n";

  #i_t1_set_aa(1);

  unlink "t1lib.log"; # lose it if it exists
  init(t1log=>0);
  ok(!-e("t1lib.log"), "disable t1log");
  init(t1log=>1);
  ok(-e("t1lib.log"), "enable t1log");
  init(t1log=>0);
  unlink "t1lib.log";

  my $fnum=Imager::i_t1_new($fontname_pfb,$fontname_afm); # this will load the pfb font
  unless (ok($fnum >= 0, "load font $fontname_pfb")) {
    skip("without the font I can't do a thing", 90);
  }

  my $bgcolor=Imager::Color->new(255,0,0,0);
  my $overlay=Imager::ImgRaw::new(200,70,3);
  
  ok(i_t1_cp($overlay,5,50,1,$fnum,50.0,'XMCLH',5,1), "i_t1_cp");

  i_line($overlay,0,50,100,50,$bgcolor,1);

  my @bbox=i_t1_bbox(0,50.0,'XMCLH',5);
  is(@bbox, 8, "i_t1_bbox");
  print "# bbox: ($bbox[0], $bbox[1]) - ($bbox[2], $bbox[3])\n";

  open(FH,">testout/t30t1font.ppm") || die "cannot open testout/t35t1font.ppm\n";
  binmode(FH); # for os2
  my $IO = Imager::io_new_fd( fileno(FH) );
  i_writeppm_wiol($overlay,$IO);
  close(FH);

  $bgcolor=Imager::Color::set($bgcolor,200,200,200,0);
  my $backgr=Imager::ImgRaw::new(280,300,3);

  i_t1_set_aa(2);
  ok(i_t1_text($backgr,10,100,$bgcolor,$fnum,150.0,'test',4,1), "i_t1_text");

  # "UTF8" tests
  # for perl < 5.6 we can hand-encode text
  # since T1 doesn't support over 256 chars in an encoding we just drop
  # chars over \xFF
  # the following is "A\xA1\x{2010}A"
  # 
  my $text = pack("C*", 0x41, 0xC2, 0xA1, 0xE2, 0x80, 0x90, 0x41);
  my $alttext = "A\xA1A";
  
  my @utf8box = i_t1_bbox($fnum, 50.0, $text, length($text), 1);
  is(@utf8box, 8, "utf8 bbox element count");
  my @base = i_t1_bbox($fnum, 50.0, $alttext, length($alttext), 0);
  is(@base, 8, "alt bbox element count");
  my $maxdiff = $fontname_pfb eq $deffont ? 0 : $base[2] / 3;
  print "# (@utf8box vs @base)\n";
  ok(abs($utf8box[2] - $base[2]) <= $maxdiff, 
      "compare box sizes $utf8box[2] vs $base[2] (maxerror $maxdiff)");

  # hand-encoded UTF8 drawing
  ok(i_t1_text($backgr, 10, 140, $bgcolor, $fnum, 32, $text, length($text), 1,1), "draw hand-encoded UTF8");

  ok(i_t1_cp($backgr, 80, 140, 1, $fnum, 32, $text, length($text), 1, 1), 
      "cp hand-encoded UTF8");

  # ok, try native perl UTF8 if available
 SKIP:
  {
    $] >= 5.006 or skip("perl too old to test native UTF8 support", 5);
    my $text;
    # we need to do this in eval to prevent compile time errors in older
    # versions
    eval q{$text = "A\xA1\x{2010}A"}; # A, a with ogonek, HYPHEN, A in our test font
    #$text = "A".chr(0xA1).chr(0x2010)."A"; # this one works too
    ok(i_t1_text($backgr, 10, 180, $bgcolor, $fnum, 32, $text, length($text), 1),
        "draw UTF8");
    ok(i_t1_cp($backgr, 80, 180, 1, $fnum, 32, $text, length($text), 1),
        "cp UTF8");
    @utf8box = i_t1_bbox($fnum, 50.0, $text, length($text), 0);
    is(@utf8box, 8, "native utf8 bbox element count");
    ok(abs($utf8box[2] - $base[2]) <= $maxdiff, 
      "compare box sizes native $utf8box[2] vs $base[2] (maxerror $maxdiff)");
    eval q{$text = "A\xA1\xA2\x01\x1F\x{0100}A"};
    ok(i_t1_text($backgr, 10, 220, $bgcolor, $fnum, 32, $text, 0, 1, 0, "uso"),
       "more complex output");
  }

  open(FH,">testout/t30t1font2.ppm") || die "cannot open testout/t35t1font.ppm\n";
  binmode(FH);
  $IO = Imager::io_new_fd( fileno(FH) );
  i_writeppm_wiol($backgr, $IO);
  close(FH);

  my $rc=i_t1_destroy($fnum);
  unless (ok($rc >= 0, "i_t1_destroy")) {
    print "# i_t1_destroy failed: rc=$rc\n";
  }

  print "# debug: ",join(" x ",i_t1_bbox(0,50,"eses",4) ),"\n";
  print "# debug: ",join(" x ",i_t1_bbox(0,50,"llll",4) ),"\n";

  # character existance tests - uses the special ExistenceTest font
  my $exists_font = 'fontfiles/ExistenceTest.pfb';
  my $exists_afm = 'fontfiles/ExistenceText.afm';
  
  -e $exists_font or die;
    
  my $font_num = Imager::i_t1_new($exists_font, $exists_afm);
  SKIP: {
    ok($font_num >= 0, 'loading test font')
      or skip('Could not load test font', 6);
    # first the list interface
    my @exists = Imager::i_t1_has_chars($font_num, "!A");
    is(@exists, 2, "return count from has_chars");
    ok($exists[0], "we have an exclamation mark");
    ok(!$exists[1], "we have no uppercase A");

    # then the scalar interface
    my $exists = Imager::i_t1_has_chars($font_num, "!A");
    is(length($exists), 2, "return scalar length");
    ok(ord(substr($exists, 0, 1)), "we have an exclamation mark");
    ok(!ord(substr($exists, 1, 1)), "we have no upper-case A");
    i_t1_destroy($font_num);
  }
  
  my $font = Imager::Font->new(file=>$exists_font, type=>'t1');
  SKIP:
  {
    ok($font, "loaded OO font")
      or skip("Could not load test font", 24);
    my @exists = $font->has_chars(string=>"!A");
    is(@exists, 2, "return count from has_chars");
    ok($exists[0], "we have an exclamation mark");
    ok(!$exists[1], "we have no uppercase A");
    
    # then the scalar interface
    my $exists = $font->has_chars(string=>"!A");
    is(length($exists), 2, "return scalar length");
    ok(ord(substr($exists, 0, 1)), "we have an exclamation mark");
    ok(!ord(substr($exists, 1, 1)), "we have no upper-case A");

    # check the advance width
    my @bbox = $font->bounding_box(string=>'/', size=>100);
    print "# @bbox\n";
    isnt($bbox[2], $bbox[5], "different advance to pos_width");

    # names
    my $face_name = Imager::i_t1_face_name($font->{id});
    print "# face $face_name\n";
    is($face_name, 'ExistenceTest', "face name");
    $face_name = $font->face_name;
    is($face_name, 'ExistenceTest', "face name");

    my @glyph_names = $font->glyph_names(string=>"!J/");
    is($glyph_names[0], 'exclam', "check exclam name OO");
    ok(!defined($glyph_names[1]), "check for no J name OO");
    is($glyph_names[2], 'slash', "check slash name OO");

    # this character chosen since when it's truncated to one byte it
    # becomes 0x21 or '!' which the font does define
    my $text = pack("C*", 0xE2, 0x80, 0xA1); # "\x{2021}" as utf-8
    @glyph_names = $font->glyph_names(string=>$text, utf8=>1);
    is($glyph_names[0], undef, "expect no glyph_name for \\x{20A1}");

    # make sure a missing string parameter is handled correctly
    eval {
      $font->glyph_names();
    };
    is($@, "", "correct error handling");
    cmp_ok(Imager->errstr, '=~', qr/no string parameter/, "error message");

    # test extended bounding box results
    # the test font is known to have a shorter advance width for that char
    @bbox = $font->bounding_box(string=>"/", size=>100);
    is(@bbox, 8, "should be 8 entries");
    isnt($bbox[6], $bbox[2], "different advance width");
    my $bbox = $font->bounding_box(string=>"/", size=>100);
    cmp_ok($bbox->pos_width, '>', $bbox->advance_width, "OO check");

    cmp_ok($bbox->right_bearing, '<', 0, "check right bearing");

    cmp_ok($bbox->display_width, '>', $bbox->advance_width,
           "check display width (roughly)");

    # check with a char that fits inside the box
    $bbox = $font->bounding_box(string=>"!", size=>100);
    print "# pos width ", $bbox->pos_width, "\n";

    # they aren't the same historically for the type 1 driver
    isnt($bbox->pos_width, $bbox->advance_width, 
       "check backwards compatibility");
    cmp_ok($bbox->left_bearing, '>', 0, "left bearing positive");
    cmp_ok($bbox->right_bearing, '>', 0, "right bearing positive");
    cmp_ok($bbox->display_width, '<', $bbox->advance_width,
           "display smaller than advance");
  }

 SKIP:
  { print "# alignment tests\n";
    my $font = Imager::Font->new(file=>$deffont, type=>'t1');
    ok($font, "loaded deffont OO")
      or skip("could not load font:".Imager->errstr, 4);
    my $im = Imager->new(xsize=>140, ysize=>150);
    my %common = 
      (
       font=>$font, 
       size=>40, 
       aa=>1,
      );
    $im->line(x1=>0, y1=>40, x2=>139, y2=>40, color=>'blue');
    $im->line(x1=>0, y1=>90, x2=>139, y2=>90, color=>'blue');
    $im->line(x1=>0, y1=>110, x2=>139, y2=>110, color=>'blue');
    for my $args ([ x=>5,   text=>"A", color=>"white" ],
                  [ x=>40,  text=>"y", color=>"white" ],
                  [ x=>75,  text=>"A", channel=>1 ],
                  [ x=>110, text=>"y", channel=>1 ]) {
      ok($im->string(%common, @$args, 'y'=>40), "A no alignment");
      ok($im->string(%common, @$args, 'y'=>90, align=>1), "A align=1");
      ok($im->string(%common, @$args, 'y'=>110, align=>0), "A align=0");
    }
    ok($im->write(file=>'testout/t30align.ppm'), "save align image");
  }

 SKIP:
  {
    # see http://rt.cpan.org/Ticket/Display.html?id=20555
    print "# bounding box around spaces\n";
    # SpaceTest contains 3 characters, space, ! and .undef
    # only characters that define character zero seem to illustrate
    # the problem we had with spaces
    my $space_fontfile = "fontfiles/SpaceTest.pfb";
    my $font = Imager::Font->new(file => $space_fontfile, type => 't1');
    ok($font, "loaded $deffont")
      or skip("failed to load $deffont" . Imager->errstr, 13);
    my $bbox = $font->bounding_box(string => "", size => 36);
    print "# empty string bbox: @$bbox\n";
    is($bbox->start_offset, 0, "empty string start_offset");
    is($bbox->end_offset, 0, "empty string end_offset");
    is($bbox->advance_width, 0, "empty string advance_width");
    is($bbox->ascent, 0, "empty string ascent");
    is($bbox->descent, 0, "empty string descent");

    # a single space
    my $bbox_space = $font->bounding_box(string => " ", size => 36);
    print "# space bbox: @$bbox_space\n";
    is($bbox_space->start_offset, 0, "single space start_offset");
    is($bbox_space->end_offset, $bbox_space->advance_width, 
       "single space end_offset");
    cmp_ok($bbox_space->ascent, '>=', $bbox_space->descent,
	   "single space ascent/descent");

    my $bbox_bang = $font->bounding_box(string => "!", size => 36);
    print "# '!' bbox: @$bbox_bang\n";

    # space ! space
    my $bbox_spbangsp = $font->bounding_box(string => " ! ", size => 36);
    print "# ' ! ' bbox: @$bbox_spbangsp\n";
    my $exp_advance = $bbox_bang->advance_width + 2 * $bbox_space->advance_width;
    is($bbox_spbangsp->advance_width, $exp_advance, "sp ! sp advance_width");
    is($bbox_spbangsp->start_offset, 0, "sp ! sp start_offset");
    is($bbox_spbangsp->end_offset, $exp_advance, "sp ! sp end_offset");
  }

 SKIP:
  { # http://rt.cpan.org/Ticket/Display.html?id=20554
    # this is "A\xA1\x{2010}A"
    # the t1 driver is meant to ignore any UTF8 characters over 0xff
    print "# issue 20554\n";
    my $text = pack("C*", 0x41, 0xC2, 0xA1, 0xE2, 0x80, 0x90, 0x41);
    my $tran_text = "A\xA1A";
    my $font = Imager::Font->new(file => 'fontfiles/dcr10.pfb', type => 't1');
    $font
      or skip("cannot load font fontfiles/fcr10.pfb:".Imager->errstr, 1);
    my $bbox_utf8 = $font->bounding_box(string => $text, utf8 => 1, size => 36);
    my $bbox_tran = $font->bounding_box(string => $tran_text, size => 36);
    is($bbox_utf8->advance_width, $bbox_tran->advance_width,
       "advance widths should match");
  }
  { # string output cut off at NUL ('\0')
    # https://rt.cpan.org/Ticket/Display.html?id=21770 cont'd
    my $font = Imager::Font->new(file => 'fontfiles/dcr10.pfb', type => 't1');
    ok($font, "loaded dcr10.pfb");

    diff_text_with_nul("a\\0b vs a", "a\0b", "a", 
		       font => $font, color => '#FFFFFF');
    diff_text_with_nul("a\\0b vs a", "a\0b", "a", 
		       font => $font, channel => 1);

    # UTF8 encoded \xBF
    my $pound = pack("C*", 0xC2, 0xBF);
    diff_text_with_nul("utf8 pound\0pound vs pound", "$pound\0$pound", $pound,
		       font => $font, color => '#FFFFFF', utf8 => 1);
    diff_text_with_nul("utf8 dash\0dash vs dash", "$pound\0$pound", $pound,
		       font => $font, channel => 1, utf8 => 1);

  }

  { # RT 11972
    # when rendering to a transparent image the coverage should be
    # expressed in terms of the alpha channel rather than the color
    my $font = Imager::Font->new(file=>'fontfiles/dcr10.pfb', type=>'t1');
    my $im = Imager->new(xsize => 40, ysize => 20, channels => 4);
    ok($im->string(string => "AB", size => 20, aa => 2, color => '#F00',
		   x => 0, y => 15, font => $font),
       "draw to transparent image");
    my $im_noalpha = $im->convert(preset => 'noalpha');
    my $im_pal = $im->to_paletted(make_colors => 'mediancut');
    my @colors = $im_pal->getcolors;
    is(@colors, 2, "should be only 2 colors");
    @colors = sort { ($a->rgba)[0] <=> ($b->rgba)[0] } @colors;
    is_color3($colors[0], 0, 0, 0, "check we got black");
    is_color3($colors[1], 255, 0, 0, "and red");
  }
}

#malloc_state();
