
use ExtUtils::MakeMaker;
use Cwd;
use Config;

$lext=$Config{'so'};


#
# IM_INCPATH      colon seperated list of paths to extra include paths
# IM_LIBPATH      colon seperated list of paths to extra library paths
#
# IM_VERBOSE      turns on verbose mode for the library finding and such
# IM_MANUAL       to manually select which libraries are used and which not
# IM_NOLOG        if true logging will not be compiled into the module
# IM_DEBUG_MALLOC if true malloc debbuging will be compiled into the module
#                 do not use IM_DEBUG_MALLOC in production - this slows
#                 everything down


$DEB=(exists $ENV{'IM_VERBOSE'} && $ENV{'IM_VERBOSE'}) ? 1:0;

if ($DEB) { print "Verbose mode\n\n"; require Data::Dumper; }

if ($ENV{IM_NOLOG}) {
   print "*** NOTE: Logging will not be compiled into the module ***\n";
} else { 
   $EXTDEF.=' -DIMAGER_LOG';
}

if ($ENV{IM_DEBUG_MALLOC}) {
   $EXTDEF.=' -DIMAGER_DEBUG_MALLOC';
   print "*** NOTE: Malloc debugging compiled into the module ***\n";
}

init();
pathcheck();

goto AUTOM unless exists $ENV{'IM_MANUAL'};

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

AUTOM:
    
for $frm(keys %formats) {
  delete $formats{$frm} if !checkformat($frm);	
}

if ($formats{'gif'} and $formats{'ungif'}) { 
  print "ungif and gif can not coexist - removing ungif support\n";
  delete $formats{'ungif'};
}

for $frm(values %formats) {
    $F_DEFINE.=' -D'.$frm->{def};
    $F_LIBS.=' '.$frm->{libfiles};
    $F_OBJECT.=' '.$frm->{objfiles};
}

$F_INC=join(" ",map { (exists $definc{$_})?'':'-I'.$_ } @incs);
$F_LIBS=join(" ",map { '-L'.$_ } @libs).' '.$F_LIBS;


$OSLIBS='';
$OSINC='';

if ($^O eq 'hpux') { $OSLIBS.=' -ldld '; }
if (defined $Config{'d_dlsymun'}) { $OSINC=' -DDLSYMUN'; }


%opts=(
    'NAME'	=> 'Imager',
    'VERSION_FROM' => 'Imager.pm', # finds $VERSION
    'LIBS'	=> '-lm '.$OSLIBS.$F_LIBS,
    'DEFINE'	=> ''.$F_DEFINE.$EXTDEF." -DOS_$^O".$OSINC,
    'INC'	=> ''.$F_INC,
    'OBJECT'    => 'Imager.o draw.o image.o io.o log.o gaussian.o conv.o ppm.o raw.o feat.o font.o filters.o dynaload.o stackmach.o datatypes.o '.$F_OBJECT,
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

sub gd {
    my($path,$chk)=@_;

#    print "checking path $path\n";
    if ( !opendir(DH,$path) ) {
	warn "Cannot open dir $path: $!\n";
	return;
    }
    my @l=grep { $chk->($_) } readdir(DH);
#    print @l;
    close(DH);
    return @l;
}


sub checkformat {
    my $frm=shift;
    my $libchk=$formats{$frm}{'libcheck'};
    my $incchk=$formats{$frm}{'inccheck'};
    
    my $l=0;
    for my $lp (@libs) {
	$l+=gd($lp,$libchk);
    }

    my $i=0;
    for my $ip (@incs) {
	$i+=gd($ip,$incchk);
    }
    
    printf("%10s: includes %s - libraries %s\n",$frm,($i?'found':'not found'),($l?'found':'not found'));
    return $i&&$l;
}




sub pathcheck {
    print "pathcheck: ";
    @incs=grep { -d $_ or ( print("$_ doesnt exist - ignored."),0) } @incs;
    @libs=grep { -d $_ or ( print("$_ doesnt exist - ignored."),0) } @libs;
    print "\ndone.\n";
}


# Format data initialization

# format definition is: 
# defines needed
# default include path
# files needed for include (boolean perl code)
# default lib path
# libs needed
# files needed for link (boolean perl code)
# object files needed for the format



sub init {

@definc{'/usr/include'}=();
@incs=('/usr/include','/usr/local/include',split(/:/,$ENV{'IM_INCPATH'}));
#@incs=(split(/:/,$ENV{'IM_INCPATH'}) );

@libs=(split(/ /,$Config{'libpth'}), split(/:/,$ENV{'IM_LIBPATH'}));

$formats{'jpeg'}={
    order=>'21',
    def=>'HAVE_LIBJPEG',
    inccheck=>sub { $_[0] eq 'jpeglib.h' },
    libcheck=>sub { $_[0] eq 'libjpeg.a' or $_ eq "libjpeg.$lext" },
    libfiles=>'-ljpeg',
    objfiles=>'jpeg.o',
    docs=>q{
  In order to use jpeg with this module you need to have libjpeg
  installed on your computer}
};

$formats{'png'}={
    order=>'22',
    def=>'HAVE_LIBPNG',
    inccheck=>sub { $_[0] eq 'png.h' },
    libcheck=>sub { $_[0] eq 'libpng.a' or $_[0] eq "libpng.$lext" },
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
    inccheck=>sub { $_[0] eq 'gif_lib.h' },
    libcheck=>sub { $_[0] eq 'libgif.a' or $_[0] eq "libgif.$lext" },
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
    inccheck=>sub { $_[0] eq 'gif_lib.h' },
    libcheck=>sub { $_[0] eq 'libungif.a' or $_[0] eq "libungif.$lext" },
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
    inccheck=>sub { $_[0] eq 't1lib.h' },
    libcheck=>sub { $_[0] eq 'libt1.a' or $_[0] eq "libt1.$lext" },
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
    inccheck=>sub { $_[0] eq 'freetype.h' },
    libcheck=>sub { $_[0] eq 'libttf.a' or $_[0] eq "libttf.$lext" },
    libfiles=>'-lttf',
    objfiles=>'',
    docs=>q{
  Truetype fonts are scalable fonts. They can include 
  kerning and hinting information and generally yield good
  visual quality esp on low resultions. The freetype library is
  used to rasterize for us. The only drawback is that there
  are alot of badly designed fonts out there.}
};
 
}
