use ExtUtils::MakeMaker;
use Cwd;

$DEB=0;
if ($DEB) { require Data::Dumper; }

print "\n\n";

if ($ENV{IMAGER_NOLOG}) {
   print "*** NOTE: Logging will not be compiled into the module ***\n";
} else { 
   $EXTDEF.=' -DIMAGER_LOG';
}

if ($ENV{IMAGER_DEBUG_MALLOC}) {
   $EXTDEF.=' -DIMAGER_DEBUG_MALLOC';
   print "*** NOTE: Malloc debugging compiled into the module ***\n";
}



# format definition is: 
# defines needed
# default include path
# files needed for include (boolean perl code)
# default lib path
# libs needed
# files needed for link (boolean perl code)
# object files needed for the format

$formats{'jpeg'}={
    order=>'21',
    def=>'HAVE_LIBJPEG',
    incpath=>'/usr/local/include',
    inccheck=>'-f jpeglib.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libjpeg.a || -f libjpeg.so',
    libfiles=>'-ljpeg',
    objfiles=>'jpeg.o',
    docs=>q{
  In order to use jpeg with this module you need to have libjpeg
  installed on your computer}
};

$formats{'png'}={
    order=>'22',
    def=>'HAVE_LIBPNG',
    incpath=>'/usr/local/include',
    inccheck=>'-f png.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libpng.a || -f libpng.so',
    libfiles=>'-lpng -lz',
    objfiles=>'png.o',
    docs=>q{
  Png stands for Portable Network Graphics and is intended as
  a replacement for gif on the web. It is patent free and
  is recommended by the w3c, you need libpng to use these formats}
};

$formats{'gif'}={
    order=>'20',
    def=>'HAVE_LIBGIF',
    incpath=>'/usr/local/include',
    inccheck=>'-f gif_lib.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libgif.a || -f libgif.so',
    libfiles=>'-lgif',
    objfiles=>'gifquant.o gif.o',
    docs=>q{
  gif is the de facto standard for webgraphics at the moment,
  it does have some patent problems. If you have giflib and
  are not in violation with the unisys patent you should use
  this instead of the 'ungif' option ( Note that they cannot
  be in use at the same time )}
};

$formats{'ungif'}={
    order=>'21',
    def=>'HAVE_LIBGIF',
    incpath=>'/usr/local/include',
    inccheck=>'-f gif_lib.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libungif.a || -f libungif.so',
    libfiles=>'-lungif',
    objfiles=>'gifquant.o gif.o',
    docs=>q{
  gif is the de facto standard for webgraphics at the moment,
  it does have some patent problems. If you have libungif and
  want to create images free from LZW patented compression you
  should use this option instead of the 'gif' option}
};

$formats{'T1-fonts'}={
    order=>'30',
    def=>'HAVE_LIBT1',
    incpath=>'/usr/local/include',
    inccheck=>'-f t1lib.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libt1.a || -f libt1.so',
    libfiles=>'-lt1',
    objfiles=>'',
    docs=>q{
  postscript t1 fonts are scalable fonts. They can include 
  ligatures and kerning information and generally yield good
  visual quality. We depend on libt1 to rasterize the fonts
  for use in images.}
};

$formats{'TT-fonts'}={
    order=>'31',
    def=>'HAVE_LIBTT',
    incpath=>'/usr/local/include',
    inccheck=>'-f freetype.h',
    libpath=>'/usr/local/lib',
    libcheck=>'-f libttf.a || -f libttf.so',
    libfiles=>'-lttf',
    objfiles=>'',
    docs=>q{
  Truetype fonts are scalable fonts. They can include 
  kerning and hinting information and generally yield good
  visual quality esp on low resultions. The freetype library is
  used to rasterize for us. The only drawback is that there
  are alot of badly designed fonts out there.}
};



print <<EOF;

      Please answer the following questions about
      which formats are avaliable on your computer

press <return> to continue
EOF

<STDIN>;


for $frm(sort { $formats{$b}{order} <=> $formats{$a}{order} } keys %formats) {
  SWX:
    if ($formats{$frm}{docs}) { print "\n",$formats{$frm}{docs},"\n\n"; }
    print "Enable $frm support: ";
    $gz=<STDIN>;
    chomp($gz);
    if ($gz =~ m/^[yn]$/) {
	if ($gz eq 'n') {
	    delete $formats{$frm};
	}
    } else { goto SWX; }
}



for $frm(values %formats) {
    $F_DEFINE.=' -D'.$frm->{def};
    $F_LIBS.=' -L'.$frm->{libpath}.' '.$frm->{libfiles};
    $F_INC.=' -I'.$frm->{incpath};
    $F_OBJECT.=' '.$frm->{objfiles};
}

$OSLIBS='';

if ($^O eq 'hpux') { $OSLIBS.=' -ldld '; }

%opts=(
    'NAME'	=> 'Imager',
    'VERSION_FROM' => 'Imager.pm', # finds $VERSION
    'LIBS'	=> '-lm '.$OSLIBS.$F_LIBS,
    'DEFINE'	=> ''.$F_DEFINE.$EXTDEF." -DLOSNAME=$^O",
    'INC'	=> ''.$F_INC,
    'OBJECT'    => 'Imager.o draw.o image.o io.o log.o gaussian.o conv.o ppm.o raw.o feat.o font.o filters.o dynaload.o stackmach.o datatypes.o '.$F_OBJECT,
#    'CCFLAGS'   => '-Wall -Wno-unused',
#    'dist'      => {TARFLAGS => 'cvfF',
#		    COMPRESS => 'gzip -9',
#                    SUFFIX   => '.gz',
#                   },
);

if ($DEB) { print Data::Dumper::Dumper(\%opts); }

mkdir('testout',0777); # since we cannot include it in the archive.

WriteMakefile(%opts);
exit;








sub MY::postamble {
'
$(MYEXTLIB): dynfilt/Makefile
	cd dynfilt && $(MAKE) $(PASTHRU)
';
}


sub checkformat {
    my(%frm)=%{$_[0]};
    $incs=1;
    if (!chdir($frm{incpath})) { 
	print "cannot chdir to '",$frm{incpath},"'\n";
    }
    print "incpath: ",$frm{incpath},"\n";
}

