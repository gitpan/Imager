package Imager::Color;

# This is not a container class as such.
# It's just a front end to the XS creation functions.

use strict;
use vars qw();

sub new {
  shift; # get rid of class name.
#  print "@_: ".@_."\n";

  if (@_ == 3) {
    return Imager::i_color_new($_[0],$_[1],$_[2],255);
  }

  if (@_ == 4) {
    return Imager::i_color_new($_[0],$_[1],$_[2],$_[3]);
  }

  if ($_[0] =~ /^\#?([\da-f][\da-f])([\da-f][\da-f])([\da-f][\da-f])/i) {
    return Imager::i_color_new($1,$2,$3,255);
  }

  return ();
}


package Imager::Font;

# This class is a container
# and works for both truetype and t1 fonts.

use strict;
use vars qw(%T1_Paths %TT_Paths %T1_Cache %TT_Cache $TT_CSize $TT_CSize $T1AA);

# $T1AA is in there because for some reason (probably cache related) antialiasing
# is a system wide setting in t1 lib.

sub t1_set_aa_level {
  if (!defined $T1AA or $_[0] != $T1AA) {
    Imager::i_t1_set_aa($_[0]);
    $T1AA=$_[0];
  }
}

# search method
# 1. start by checking if file is the parameter
# 1a. if so qualify path and compare to the cache.
# 2a. if in cache - take it's id from there and increment count.
# 

sub new {
  my $class = shift;
  my $self ={};
  my ($file,$type,$id);
  my %hsh=(color=>Imager::Color->new(255,0,0,0),
	   size=>15,
	   @_);

  bless $self,$class;
#  use Data::Dumper;
#  print Dumper(\%hsh);

  if ($hsh{'file'}) { 
    $file=$hsh{'file'};
    if ( $file !~ m/^\// ) {
      $file='./'.$file;
      if (! -e $file) {
	$Imager::ERRSTR="Font $file not found";
	return();
      }
    }

#    warn "file=$file\n";

    $type=$hsh{'type'};
    if (!defined($type) or $type !~ m/^(t1|tt)/) {
      $type='tt' if $file =~ m/\.ttf$/i;
      $type='t1' if $file =~ m/\.pfb$/i;
    }
    if (!defined($type)) {
      $Imager::ERRSTR="Font type not found";
      return;
    }
  } else {
    $Imager::ERRSTR="No font file specified";
    return;
  }

  if (!$Imager::formats{$type}) { 
    $Imager::ERRSTR="`$type' not enabled";
    return;
  }

  # here we should have the font type or be dead already.

  if ($type eq 't1') {
    $id=Imager::i_t1_new($file);
  }

  if ($type eq 'tt') {
    $id=Imager::i_tt_new($file);
  }

  $self->{'aa'}=$hsh{'aa'}||'0';
  $self->{'file'}=$file;
  $self->{'id'}=$id;
  $self->{'type'}=$type;
  $self->{'size'}=$hsh{'size'};
  $self->{'color'}=$hsh{'color'};
  return $self;
}


sub bounding_box {
  my $self=shift;
  my %input=@_;
  my @box;

  if (!exists $input{'string'}) { $Imager::ERRSTR='string parameter missing'; return; }

  if ($self->{type} eq 't1') {
    @box=Imager::i_t1_bbox($self->{id}, defined($input{size}) ? $input{size} :$self->{size},
			   $input{string}, length($input{string}));
  }
  if ($self->{type} eq 'tt') {
    @box=Imager::i_tt_bbox($self->{id}, defined($input{size}) ? $input{size} :$self->{size},
			   $input{string}, length($input{string}));
  }

  if(exists $input{'x'} and exists $input{'y'}) {
    my($descent, $ascent)=@box[1,3];
    $box[1]=$input{'y'}-$ascent;      # top = base - ascent (Y is down)
    $box[3]=$input{'y'}-$descent;     # bottom = base - descent (Y is down, descent is negative)
    $box[0]+=$input{'x'};
    $box[2]+=$input{'x'};
  } elsif (exists $input{'canon'}) {
    $box[3]-=$box[1];    # make it cannoical (ie (0,0) - (width, height))
    $box[2]-=$box[0];
  }
  return @box;
}






package Imager;

# The main class

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %formats $DEBUG %filters %DSOs $ERRSTR $fontstate %OPCODES $I2P $FORMATGUESS);
use IO::File;

@EXPORT_OK = qw(
		init_log
		DSO_open
		DSO_close
		DSO_funclist
		DSO_call
		
		load_plugin
		unload_plugin
		
		i_list_formats
		i_has_format
		
		i_color_new
		i_color_set
		i_color_info
		
		i_img_empty
		i_img_empty_ch
		i_img_exorcise
		i_img_destroy

		i_img_info

		i_img_setmask
		i_img_getmask

		i_draw
		i_line_aa
		i_box
		i_box_filled
		i_arc
		
		i_bezier_multi
		i_poly_aa

		i_copyto
		i_rubthru
		i_scaleaxis
		i_scale_nn
		i_haar
		i_count_colors
		
		
		i_gaussian
		i_conv
		
		i_img_diff

		i_init_fonts
		i_t1_new
		i_t1_destroy
		i_t1_set_aa
		i_t1_cp
		i_t1_text
		i_t1_bbox


		i_tt_set_aa
		i_tt_cp
		i_tt_text
		i_tt_bbox

		i_readjpeg
		i_writejpeg

		i_readjpeg_wiol
		i_writejpeg_wiol

		i_readtiff_wiol
		i_writetiff_wiol

		i_readpng
		i_writepng

		i_readgif
		i_readgif_callback
		i_writegif
		i_writegifmc
		i_writegif_gen
		i_writegif_callback

		i_readppm
		i_writeppm

		i_readraw
		i_writeraw

		i_contrast
		i_hardinvert
		i_noise
		i_bumpmap
		i_postlevels
		i_mosaic
		i_watermark
		
		malloc_state

		list_formats
		
		i_gifquant

		newfont
		newcolor
		newcolour
		NC
		NF
		
); 



@EXPORT=qw( 
	   init_log
	   i_list_formats
	   i_has_format
	   malloc_state
	   i_color_new

	   i_img_empty
	   i_img_empty_ch
	  );

%EXPORT_TAGS=
  (handy => [qw(
		newfont
		newcolor
		NF
		NC
	       )],
   all => [@EXPORT_OK],
   default => [qw(
		  load_plugin
		  unload_plugin
		 )]);


BEGIN { 
  require Exporter;
  require DynaLoader;

  $VERSION = '0.36';
  @ISA = qw(Exporter DynaLoader);
  bootstrap Imager $VERSION;
}

BEGIN {
  i_init_fonts(); # Initialize font engines
  for(i_list_formats()) { $formats{$_}++; }

  if ($formats{'t1'}) {
    i_t1_set_aa(1);
  }

  if (!$formats{'t1'} and !$formats{'tt'}) {
    $fontstate='no font support';
  }

  %OPCODES=(Add=>[0],Sub=>[1],Mult=>[2],Div=>[3],Parm=>[4],'sin'=>[5],'cos'=>[6],'x'=>[4,0],'y'=>[4,1]);

  $DEBUG=0;

  $filters{contrast}={ 
		      callseq => ['image','intensity'],
		      callsub => sub { my %hsh=@_; i_contrast($hsh{image},$hsh{intensity}); } 
		     };

  $filters{noise} ={
		    callseq => ['image', 'amount', 'subtype'],
		    defaults => { amount=>3,subtype=>0 },
		    callsub => sub { my %hsh=@_; i_noise($hsh{image},$hsh{amount},$hsh{subtype}); }
		   };

  $filters{hardinvert} ={
			 callseq => ['image'],
			 defaults => { },
			 callsub => sub { my %hsh=@_; i_hardinvert($hsh{image}); }
			};

  $filters{autolevels} ={
			 callseq => ['image','lsat','usat','skew'],
			 defaults => { lsat=>0.1,usat=>0.1,skew=>0.0 },
			 callsub => sub { my %hsh=@_; i_autolevels($hsh{image},$hsh{lsat},$hsh{usat},$hsh{skew}); }
			};

  $filters{turbnoise} ={
			callseq => ['image'],
			defaults => { xo=>0.0,yo=>0.0,scale=>10.0 },
			callsub => sub { my %hsh=@_; i_turbnoise($hsh{image},$hsh{xo},$hsh{yo},$hsh{scale}); }
		       };

  $filters{radnoise} ={
		       callseq => ['image'],
		       defaults => { xo=>100,yo=>100,ascale=>17.0,rscale=>0.02 },
		       callsub => sub { my %hsh=@_; i_radnoise($hsh{image},$hsh{xo},$hsh{yo},$hsh{rscale},$hsh{ascale}); }
		      };

  $filters{conv} ={
		       callseq => ['image', 'coef'],
		       defaults => { },
		       callsub => sub { my %hsh=@_; i_conv($hsh{image},$hsh{coef}); }
		      };

  $FORMATGUESS=\&def_guess_type;
}

#
# Non methods
#

# initlize Imager
# NOTE: this might be moved to an import override later on

#sub import {
#  my $pack = shift;
#  (look through @_ for special tags, process, and remove them);   
#  use Data::Dumper;
#  print Dumper($pack);
#  print Dumper(@_);
#}

sub init {
  my %parms=(loglevel=>1,@_);
  if ($parms{'log'}) {
    init_log($parms{'log'},$parms{loglevel});
  }

#    if ($parms{T1LIB_CONFIG}) { $ENV{T1LIB_CONFIG}=$parms{T1LIB_CONFIG}; }
#    if ( $ENV{T1LIB_CONFIG} and ( $fontstate eq 'missing conf' )) {
#	i_init_fonts();
#	$fontstate='ok';
#    }
}

END {
  if ($DEBUG) {
    print "shutdown code\n";
    #	for(keys %instances) { $instances{$_}->DESTROY(); }
    malloc_state(); # how do decide if this should be used? -- store something from the import
    print "Imager exiting\n";
  }
}

# Load a filter plugin 

sub load_plugin {
  my ($filename)=@_;
  my $i;
  my ($DSO_handle,$str)=DSO_open($filename);
  if (!defined($DSO_handle)) { $Imager::ERRSTR="Couldn't load plugin '$filename'\n"; return undef; }
  my %funcs=DSO_funclist($DSO_handle);
  if ($DEBUG) { print "loading module $filename\n"; $i=0; for(keys %funcs) { printf("  %2d: %s\n",$i++,$_); } }
  $i=0;
  for(keys %funcs) { if ($filters{$_}) { $ERRSTR="filter '$_' already exists\n"; DSO_close($DSO_handle); return undef; } }

  $DSOs{$filename}=[$DSO_handle,\%funcs];

  for(keys %funcs) { 
    my $evstr="\$filters{'".$_."'}={".$funcs{$_}.'};';
    $DEBUG && print "eval string:\n",$evstr,"\n";
    eval $evstr;
    print $@ if $@;
  }
  return 1;
}

# Unload a plugin

sub unload_plugin {
  my ($filename)=@_;

  if (!$DSOs{$filename}) { $ERRSTR="plugin '$filename' not loaded."; return undef; }
  my ($DSO_handle,$funcref)=@{$DSOs{$filename}};
  for(keys %{$funcref}) {
    delete $filters{$_};
    $DEBUG && print "unloading: $_\n";
  }
  my $rc=DSO_close($DSO_handle);
  if (!defined($rc)) { $ERRSTR="unable to unload plugin '$filename'."; return undef; }
  return 1;
}


#
# Methods to be called on objects.
#

# Create a new Imager object takes very few parameters.
# usually you call this method and then call open from
# the resulting object

sub new {
  my $class = shift;
  my $self ={};
  my %hsh=@_;
  bless $self,$class;
  $self->{IMG}=undef;    # Just to indicate what exists
  $self->{ERRSTR}=undef; #
  $self->{DEBUG}=$DEBUG;
  $self->{DEBUG} && print "Initialized Imager\n";
  if ($hsh{xsize} && $hsh{ysize}) { $self->img_set(%hsh); }
  return $self;
}


# Copy an entire image with no changes 
# - if an image has magic the copy of it will not be magical

sub copy {
  my $self = shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $newcopy=Imager->new();
  $newcopy->{IMG}=i_img_new();
  i_copy($newcopy->{IMG},$self->{IMG});
  return $newcopy;
}

# Paste a region

sub paste {
  my $self = shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %input=(left=>0, top=>0, @_);
  unless($input{img}) {
    $self->{ERRSTR}="no source image";
    return;
  }
  $input{left}=0 if $input{left} <= 0;
  $input{top}=0 if $input{top} <= 0;
  my $src=$input{img};
  my($r,$b)=i_img_info($src->{IMG});

  i_copyto($self->{IMG}, $src->{IMG}, 
	   0,0, $r, $b, $input{left}, $input{top});
  return $self;  # What should go here??
}

# Crop an image - i.e. return a new image that is smaller

sub crop {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %hsh=(left=>0,right=>0,top=>0,bottom=>0,@_);

  my ($w,$h,$l,$r,$b,$t)=($self->getwidth(),$self->getheight(),
				@hsh{qw(left right bottom top)});
  $l=0 if not defined $l;
  $t=0 if not defined $t;
  $r=$self->getwidth if not defined $r;
  $b=$self->getheight if not defined $b;

  ($l,$r)=($r,$l) if $l>$r;
  ($t,$b)=($b,$t) if $t>$b;

  if ($hsh{'width'}) { 
    $l=int(0.5+($w-$hsh{'width'})/2); 
    $r=$l+$hsh{'width'}; 
  } else {
    $hsh{'width'}=$r-$l;
  }
  if ($hsh{'height'}) { 
    $b=int(0.5+($h-$hsh{'height'})/2); 
    $t=$h+$hsh{'height'}; 
  } else {
    $hsh{'height'}=$b-$t;
  }

#    print "l=$l, r=$r, h=$hsh{'width'}\n";
#    print "t=$t, b=$b, w=$hsh{'height'}\n";

  my $dst=Imager->new(xsize=>$hsh{'width'},ysize=>$hsh{'height'},channels=>$self->getchannels());

  i_copyto($dst->{IMG},$self->{IMG},$l,$t,$r,$b,0,0);
  return $dst;
}

# Sets an image to a certain size and channel number
# if there was previously data in the image it is discarded

sub img_set {
  my $self=shift;

  my %hsh=(xsize=>100,ysize=>100,channels=>3,@_);

  if (defined($self->{IMG})) {
    i_img_destroy($self->{IMG});
    undef($self->{IMG});
  }

  $self->{IMG}=Imager::ImgRaw::new($hsh{'xsize'},$hsh{'ysize'},$hsh{'channels'});
}

# Read an image from file

sub read {
  my $self = shift;
  my %input=@_;
  my ($fh, $fd, $IO);

  if (defined($self->{IMG})) {
    i_img_destroy($self->{IMG});
    undef($self->{IMG});
  }

  if (!$input{fd} and !$input{file} and !$input{data}) { $self->{ERRSTR}='no file, fd or data parameter'; return undef; }
  if ($input{file}) {
    $fh = new IO::File($input{file},"r");
    if (!defined $fh) { $self->{ERRSTR}='Could not open file'; return undef; }
    binmode($fh);
    $fd = $fh->fileno();
  }
  if ($input{fd}) { $fd=$input{fd} };

  # FIXME: Find the format here if not specified
  # yes the code isn't here yet - next week maybe?

  if (!$input{type} and $input{file}) { $input{type}=$FORMATGUESS->($input{file}); }
  if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }

  my %iolready=(jpeg=>1, tiff=>1);

  if ($iolready{$input{type}}) {
  # Setup data source
  $IO = Imager::io_new_fd($fd); # sort of simple for now eh?



  if ( $input{type} eq 'jpeg' ) {
    ($self->{IMG},$self->{IPTCRAW})=i_readjpeg_wiol( $IO );
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read jpeg image'; return undef; }
    $self->{DEBUG} && print "loading a jpeg file\n";
    return $self;
  }

  if ( $input{type} eq 'tiff' ) {
    $self->{IMG}=i_readtiff_wiol( $IO, -1 ); # Fixme, check if that length parameter is ever needed
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read tiff image'; return undef; }
    $self->{DEBUG} && print "loading a tiff file\n";
    return $self;
  }
  } else {

  # Old code for reference while changing the new stuff


  if (!$input{type} and $input{file}) { $input{type}=$FORMATGUESS->($input{file}); }
  if (!$input{type}) { $self->{ERRSTR}='type parameter missing and not possible to guess from extension'; return undef; }

  if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }

  if ($input{file}) {
    $fh = new IO::File($input{file},"r");
    if (!defined $fh) { $self->{ERRSTR}='Could not open file'; return undef; }
    binmode($fh);
    $fd = $fh->fileno();
  }
  if ($input{fd}) { $fd=$input{fd} };

  if ( $input{type} eq 'gif' ) {
    if (exists $input{data}) { $self->{IMG}=i_readgif_scalar($input{data}); }
    else { $self->{IMG}=i_readgif( $fd ) }
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read gif image'; return undef; }
    $self->{DEBUG} && print "loading a gif file\n";
  } elsif ( $input{type} eq 'jpeg' ) {
    if (exists $input{data}) { ($self->{IMG},$self->{IPTCRAW})=i_readjpeg_scalar($input{data}); }
    else { ($self->{IMG},$self->{IPTCRAW})=i_readjpeg( $fd ); }
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read jpeg image'; return undef; }
    $self->{DEBUG} && print "loading a jpeg file\n";
  } elsif ( $input{type} eq 'png' ) {
    if (exists $input{data}) { $self->{IMG}=i_readpng_scalar($input{data}); }
    else { $self->{IMG}=i_readpng( $fd ); }
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read png image'; return undef; }
    $self->{DEBUG} && print "loading a png file\n";
  } elsif ( $input{type} eq 'ppm' ) { 
    $self->{IMG}=i_readppm( $fd );
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read ppm image'; return undef; }
    $self->{DEBUG} && print "loading a ppm file\n";
  } elsif ( $input{type} eq 'raw' ) {
    my %params=(datachannels=>3,storechannels=>3,interleave=>1);
    for(keys(%input)) { $params{$_}=$input{$_}; }

    if ( !($params{xsize} && $params{ysize}) ) { $self->{ERRSTR}='missing xsize or ysize parameter for raw'; return undef; }
    $self->{IMG}=i_readraw( $fd, $params{xsize}, $params{ysize},
			   $params{datachannels}, $params{storechannels}, $params{interleave});
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read raw image'; return undef; }
    $self->{DEBUG} && print "loading a raw file\n";
  }
  return $self;
  }
}


# Write an image to file

sub write {
  my $self = shift;
  my %input=(jpegquality=>75,gifquant=>'mc',lmdither=>6.0,lmfixed=>[],@_);
  my ($fh,$rc,$fd);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (!$input{file} and !$input{'fd'}) { $self->{ERRSTR}='file parameter missing'; return undef; }
  if (!$input{type}) { $input{type}=$FORMATGUESS->($input{file}); }
  if (!$input{type}) { $self->{ERRSTR}='type parameter missing and not possible to guess from extension'; return undef; }

  if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }

  if (exists $input{'fd'}) {
    $fd=$input{'fd'};
  } else {
    $fh = new IO::File($input{file},"w+");
    if (!defined $fh) { $self->{ERRSTR}='Could not open file'; return undef; }
    binmode($fh);
    $fd=$fh->fileno();
  }

  if ( $input{type} eq 'gif' ) {
    if (not $input{gifplanes}) {
        my $gp;
        my $count=i_count_colors($self->{IMG}, 256);
        $gp=8 if $count==-1;
        $gp=1 if not $gp and $count <= 2;
        $gp=2 if not $gp and $count <= 4;
        $gp=3 if not $gp and $count <= 8;
        $gp=4 if not $gp and $count <= 16;
        $gp=5 if not $gp and $count <= 32;
        $gp=6 if not $gp and $count <= 64;
        $gp=7 if not $gp and $count <= 128;
        $input{gifplanes}=$gp||8;
    }

    if ($input{gifplanes}>8) { $input{gifplanes}=8; }
    if ($input{gifquant} eq 'gen' || $input{callback}) {
      if ($input{gifquant} eq 'lm') {
	$input{make_colors} = 'addi';
	$input{translate} = 'perturb';
	$input{perturb} = $input{lmdither};
      }
      elsif ($input{gifquant} eq 'gen') {
	# just pass options through
      }
      else {
	$input{make_colors} = 'webmap'; # ignored
	$input{translate} = 'giflib';
      }
      if ($input{callback}) {
	defined $input{maxbuffer} or $input{maxbuffer} = -1;
	$rc = i_writegif_callback($input{callback}, $input{maxbuffer},
				  \%input, $self->{IMG});
      }
      else {
	$rc = i_writegif_gen($fd, \%input, $self->{IMG});
      }
    }
    elsif ($input{gifquant} eq 'lm') {
      $rc=i_writegif($self->{IMG},$fd,$input{gifplanes},$input{lmdither},$input{lmfixed});
    } else {
      $rc=i_writegifmc($self->{IMG},$fd,$input{gifplanes});
    }
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write gif image'; return undef; }
    $self->{DEBUG} && print "writing a gif file\n";

  } elsif ( $input{type} eq 'jpeg' ) {
    $rc=i_writejpeg($self->{IMG},$fd,$input{jpegquality});
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write jpeg image'; return undef; }
    $self->{DEBUG} && print "writing a jpeg file\n";
  } elsif ( $input{type} eq 'png' ) { 
    $rc=i_writepng($self->{IMG},$fd);
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write png image'; return undef; }
    $self->{DEBUG} && print "writing a png file\n";
  } elsif ( $input{type} eq 'ppm' ) { 
    $rc=i_writeppm($self->{IMG},$fd);
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write ppm image'; return undef; }
    $self->{DEBUG} && print "writing a ppm file\n";
  } elsif ( $input{type} eq 'raw' ) {
    $rc=i_writeraw($self->{IMG},$fd);
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write raw image'; return undef; }
    $self->{DEBUG} && print "writing a raw file\n";
  } elsif ( $input{type} eq 'tiff' ) {
    $rc=i_writetiff_wiol($self->{IMG},io_new_fd($fd) );
    if ( !defined($rc) ) { $self->{ERRSTR}='unable to write tiff image'; return undef; }
    $self->{DEBUG} && print "writing a tiff file\n";
  }


  return $self;
}

sub write_multi {
  my ($class, $opts, @images) = @_;

  if ($opts->{type} eq 'gif') {
    # translate to ImgRaw
    if (grep !UNIVERSAL::isa($_, 'Imager') || !$_->{IMG}, @images) {
      $ERRSTR = "Usage: Imager->write_anim({ options }, @images)";
      return 0;
    }
    my @work = map $_->{IMG}, @images;
    if ($opts->{callback}) {
      # Note: you may need to fix giflib for this one to work
      my $maxbuffer = $opts->{maxbuffer};
      defined $maxbuffer or $maxbuffer = -1; # max by default
      return i_writegif_callback($opts->{callback}, $maxbuffer,
				 $opts, @work);
    }
    if ($opts->{fd}) {
      return i_writegif_gen($opts->{fd}, $opts, @work);
    }
    else {
      my $fh = IO::File->new($opts->{file}, "w+");
      unless ($fh) {
	$ERRSTR = "Error creating $opts->{file}: $!";
	return 0;
      }
      binmode($fh);
      return i_writegif_gen(fileno($fh), $opts, @work);
    }
  }
  else {
    $ERRSTR = "Sorry, write_anim doesn't support $opts->{type} yet";
    return 0;
  }
}

# Destroy an Imager object

sub DESTROY {
  my $self=shift;
  #    delete $instances{$self};
  if (defined($self->{IMG})) {
    i_img_destroy($self->{IMG});
    undef($self->{IMG});
  } else {
#    print "Destroy Called on an empty image!\n"; # why did I put this here??
  }
}

# Perform an inplace filter of an image
# that is the image will be overwritten with the data

sub filter {
  my $self=shift;
  my %input=@_;
  my %hsh;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (!$input{type}) { $self->{ERRSTR}='type parameter missing'; return undef; }

  if ( (grep { $_ eq $input{type} } keys %filters) != 1) {
    $self->{ERRSTR}='type parameter not matching any filter'; return undef;
  }

  if (defined($filters{$input{type}}{defaults})) {
    %hsh=('image',$self->{IMG},%{$filters{$input{type}}{defaults}},%input);
  } else {
    %hsh=('image',$self->{IMG},%input);
  }

  my @cs=@{$filters{$input{type}}{callseq}};

  for(@cs) {
    if (!defined($hsh{$_})) {
      $self->{ERRSTR}="missing parameter '$_' for filter ".$input{type}; return undef;
    }
  }

  &{$filters{$input{type}}{callsub}}(%hsh);

  my @b=keys %hsh;

  $self->{DEBUG} && print "callseq is: @cs\n";
  $self->{DEBUG} && print "matching callseq is: @b\n";

  return $self;
}

# Scale an image to requested size and return the scaled version

sub scale {
  my $self=shift;
  my %opts=(scalefactor=>0.5,type=>'max',qtype=>'normal',@_);
  my $img = Imager->new();
  my $tmp = Imager->new();

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if ($opts{xpixels} and $opts{ypixels} and $opts{type}) {
    my ($xpix,$ypix)=( $opts{xpixels}/$self->getwidth() , $opts{ypixels}/$self->getheight() );
    if ($opts{type} eq 'min') { $opts{scalefactor}=min($xpix,$ypix); }
    if ($opts{type} eq 'max') { $opts{scalefactor}=max($xpix,$ypix); }
  } elsif ($opts{xpixels}) { $opts{scalefactor}=$opts{xpixels}/$self->getwidth(); }
  elsif ($opts{ypixels}) { $opts{scalefactor}=$opts{ypixels}/$self->getheight(); }

  if ($opts{qtype} eq 'normal') {
    $tmp->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},0);
    if ( !defined($tmp->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    $img->{IMG}=i_scaleaxis($tmp->{IMG},$opts{scalefactor},1);
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
  }
  if ($opts{'qtype'} eq 'preview') {
    $img->{IMG}=i_scale_nn($self->{IMG},$opts{'scalefactor'},$opts{'scalefactor'}); 
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
  }
  $self->{ERRSTR}='scale: invalid value for qtype'; return undef;
}

# Scales only along the X axis

sub scaleX {
  my $self=shift;
  my %opts=(scalefactor=>0.5,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $img = Imager->new();

  if ($opts{pixels}) { $opts{scalefactor}=$opts{pixels}/$self->getwidth(); }

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},0);

  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
  return $img;
}

# Scales only along the Y axis

sub scaleY {
  my $self=shift;
  my %opts=(scalefactor=>0.5,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my $img = Imager->new();

  if ($opts{pixels}) { $opts{scalefactor}=$opts{pixels}/$self->getheight(); }

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},1);

  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
  return $img;
}


# Transform returns a spatial transformation of the input image
# this moves pixels to a new location in the returned image.
# NOTE - should make a utility function to check transforms for
# stack overruns

sub transform {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my %opts=@_;
  my (@op,@ropx,@ropy,$iop,$or,@parm,$expr,@xt,@yt,@pt,$numre);

#  print Dumper(\%opts);
#  xopcopdes

  if ( $opts{'xexpr'} and $opts{'yexpr'} ) {
    if (!$I2P) {
      eval ("use Affix::Infix2Postfix;");
      print $@;
      if ( $@ ) {
	$self->{ERRSTR}='transform: expr given and Affix::Infix2Postfix is not avaliable.'; 
	return undef;
      }
      $I2P=Affix::Infix2Postfix->new('ops'=>[{op=>'+',trans=>'Add'},
					     {op=>'-',trans=>'Sub'},
					     {op=>'*',trans=>'Mult'},
					     {op=>'/',trans=>'Div'},
					     {op=>'-',type=>'unary',trans=>'u-'},
					     {op=>'**'},
					     {op=>'func',type=>'unary'}],
				     'grouping'=>[qw( \( \) )],
				     'func'=>[qw( sin cos )],
				     'vars'=>[qw( x y )]
				    );
    }

    @xt=$I2P->translate($opts{'xexpr'});
    @yt=$I2P->translate($opts{'yexpr'});

    $numre=$I2P->{'numre'};
    @pt=(0,0);

    for(@xt) { if (/$numre/) { push(@pt,$_); push(@{$opts{'xopcodes'}},'Parm',$#pt); } else { push(@{$opts{'xopcodes'}},$_); } }
    for(@yt) { if (/$numre/) { push(@pt,$_); push(@{$opts{'yopcodes'}},'Parm',$#pt); } else { push(@{$opts{'yopcodes'}},$_); } }
    @{$opts{'parm'}}=@pt;
  }

#  print Dumper(\%opts);

  if ( !exists $opts{'xopcodes'} or @{$opts{'xopcodes'}}==0) {
    $self->{ERRSTR}='transform: no xopcodes given.';
    return undef;
  }

  @op=@{$opts{'xopcodes'}};
  for $iop (@op) { 
    if (!defined ($OPCODES{$iop}) and ($iop !~ /^\d+$/) ) {
      $self->{ERRSTR}="transform: illegal opcode '$_'.";
      return undef;
    }
    push(@ropx,(exists $OPCODES{$iop}) ? @{$OPCODES{$iop}} : $iop );
  }


# yopcopdes

  if ( !exists $opts{'yopcodes'} or @{$opts{'yopcodes'}}==0) {
    $self->{ERRSTR}='transform: no yopcodes given.';
    return undef;
  }

  @op=@{$opts{'yopcodes'}};
  for $iop (@op) { 
    if (!defined ($OPCODES{$iop}) and ($iop !~ /^\d+$/) ) {
      $self->{ERRSTR}="transform: illegal opcode '$_'.";
      return undef;
    }
    push(@ropy,(exists $OPCODES{$iop}) ? @{$OPCODES{$iop}} : $iop );
  }

#parameters

  if ( !exists $opts{'parm'}) {
    $self->{ERRSTR}='transform: no parameter arg given.';
    return undef;
  }

#  print Dumper(\@ropx);
#  print Dumper(\@ropy);
#  print Dumper(\@ropy);

  my $img = Imager->new();
  $img->{IMG}=i_transform($self->{IMG},\@ropx,\@ropy,$opts{'parm'});
  if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='transform: failed'; return undef; }
  return $img;
}


{
  my $got_expr;
  sub transform2 {
    my ($opts, @imgs) = @_;

    if (!$got_expr) {
      # this is fairly big, delay loading it
      eval "use Imager::Expr";
      die $@ if $@;
      ++$got_expr;
    }

    $opts->{variables} = [ qw(x y) ];
    my ($width, $height) = @{$opts}{qw(width height)};
    if (@imgs) {
	$width ||= $imgs[0]->getwidth();
	$height ||= $imgs[0]->getheight();
	my $img_num = 1;
	for my $img (@imgs) {
	    $opts->{constants}{"w$img_num"} = $img->getwidth();
	    $opts->{constants}{"h$img_num"} = $img->getheight();
	    $opts->{constants}{"cx$img_num"} = $img->getwidth()/2;
	    $opts->{constants}{"cy$img_num"} = $img->getheight()/2;
	    ++$img_num;
	}
    }
    if ($width) {
      $opts->{constants}{w} = $width;
      $opts->{constants}{cx} = $width/2;
    }
    else {
      $Imager::ERRSTR = "No width supplied";
      return;
    }
    if ($height) {
      $opts->{constants}{h} = $height;
      $opts->{constants}{cy} = $height/2;
    }
    else {
      $Imager::ERRSTR = "No height supplied";
      return;
    }
    my $code = Imager::Expr->new($opts);
    if (!$code) {
      $Imager::ERRSTR = Imager::Expr::error();
      return;
    }

    my $img = Imager->new();
    $img->{IMG} = i_transform2($opts->{width}, $opts->{height}, $code->code(), 
			       $code->nregs(), $code->cregs(), 
			       [ map { $_->{IMG} } @imgs ]);
    if (!defined $img->{IMG}) {
      $Imager::ERRSTR = "transform2 failed";
      return;
    }

    return $img;
  }
}








sub rubthrough {
  my $self=shift;
  my %opts=(tx=>0,ty=>0,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  unless ($opts{src} && $opts{src}->{IMG}) { $self->{ERRSTR}='empty input image for source'; return undef; }

  i_rubthru($self->{IMG},$opts{src}->{IMG},$opts{tx},$opts{ty});
  return $self;
}







# Draws a box between the specified corner points.

sub box {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my $dflcl=i_color_new(255,255,255,255);
  my %opts=(color=>$dflcl,xmin=>0,ymin=>0,xmax=>$self->getwidth()-1,ymax=>$self->getheight()-1,@_);

  if (exists $opts{'box'}) { 
    $opts{'xmin'}=min($opts{'box'}->[0],$opts{'box'}->[2]);
    $opts{'xmax'}=max($opts{'box'}->[0],$opts{'box'}->[2]);
    $opts{'ymin'}=min($opts{'box'}->[1],$opts{'box'}->[3]);
    $opts{'ymax'}=max($opts{'box'}->[1],$opts{'box'}->[3]);
  }

  if ($opts{filled}) { i_box_filled($self->{IMG},$opts{xmin},$opts{ymin},$opts{xmax},$opts{ymax},$opts{color}); }
  else { i_box($self->{IMG},$opts{xmin},$opts{ymin},$opts{xmax},$opts{ymax},$opts{color}); }
  return $self;
}

# Draws an arc - this routine SUCKS and is buggy - it sometimes doesn't work when the arc is a convex polygon

sub arc {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
  my $dflcl=i_color_new(255,255,255,255);
  my %opts=(color=>$dflcl,
	    'r'=>min($self->getwidth(),$self->getheight())/3,
	    'x'=>$self->getwidth()/2,
	    'y'=>$self->getheight()/2,
	    'd1'=>0, 'd2'=>361, @_);
  i_arc($self->{IMG},$opts{'x'},$opts{'y'},$opts{'r'},$opts{'d1'},$opts{'d2'},$opts{'color'}); 
  return $self;
}

# Draws a line from one point to (but not including) the destination point

sub line {
  my $self=shift;
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  unless (exists $opts{x1} and exists $opts{y1}) { $self->{ERRSTR}='missing begining coord'; return undef; }
  unless (exists $opts{x2} and exists $opts{y2}) { $self->{ERRSTR}='missing ending coord'; return undef; }

  if ($opts{antialias}) {
    i_line_aa($self->{IMG},$opts{x1}, $opts{y1}, $opts{x2}, $opts{y2}, $opts{color});
  } else {
    i_draw($self->{IMG},$opts{x1}, $opts{y1}, $opts{x2}, $opts{y2}, $opts{color});
  }
  return $self;
}

# Draws a line between an ordered set of points - It more or less just transforms this
# into a list of lines.

sub polyline {
  my $self=shift;
  my ($pt,$ls,@points);
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (exists($opts{points})) { @points=@{$opts{points}}; }
  if (!exists($opts{points}) and exists($opts{'x'}) and exists($opts{'y'}) ) {
    @points=map { [ $opts{'x'}->[$_],$opts{'y'}->[$_] ] } (0..(scalar @{$opts{'x'}}-1));
    }

#  print Dumper(\@points);

  if ($opts{antialias}) {
    for $pt(@points) {
      if (defined($ls)) { i_line_aa($self->{IMG},$ls->[0],$ls->[1],$pt->[0],$pt->[1],$opts{color}); }
      $ls=$pt;
    }
  } else {
    for $pt(@points) {
      if (defined($ls)) { i_draw($self->{IMG},$ls->[0],$ls->[1],$pt->[0],$pt->[1],$opts{color}); }
      $ls=$pt;
    }
  }
  return $self;
}

# this the multipoint bezier curve 
# this is here more for testing that actual usage since
# this is not a good algorithm.  Usually the curve would be
# broken into smaller segments and each done individually.

sub polybezier {
  my $self=shift;
  my ($pt,$ls,@points);
  my $dflcl=i_color_new(0,0,0,0);
  my %opts=(color=>$dflcl,@_);

  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  if (exists $opts{points}) {
    $opts{'x'}=map { $_->[0]; } @{$opts{'points'}};
    $opts{'y'}=map { $_->[1]; } @{$opts{'points'}};
  }

  unless ( @{$opts{'x'}} and @{$opts{'x'}} == @{$opts{'y'}} ) {
    $self->{ERRSTR}='Missing or invalid points.';
    return;
  }

  i_bezier_multi($self->{IMG},$opts{'x'},$opts{'y'},$opts{'color'});
  return $self;
}


# destructive border - image is shrunk by one pixel all around

sub border {
  my ($self,%opts)=@_;
  my($tx,$ty)=($self->getwidth()-1,$self->getheight()-1);
  $self->polyline('x'=>[0,$tx,$tx,0,0],'y'=>[0,0,$ty,$ty,0],%opts);
}


# Get the width of an image

sub getwidth {
  my $self=shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  return (i_img_info($self->{IMG}))[0];
}

# Get the height of an image

sub getheight {
  my $self=shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  return (i_img_info($self->{IMG}))[1];
}

# Get number of channels in an image

sub getchannels {
  my $self=shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  return i_img_getchannels($self->{IMG});
}

# Get channel mask

sub getmask {
  my $self=shift;
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  return i_img_getmask($self->{IMG});
}

# Set channel mask

sub setmask {
  my $self=shift;
  my %opts=@_;
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  i_img_setmask( $self->{IMG} , $opts{mask} );
}

# Get number of colors in an image

sub getcolorcount {
  my $self=shift;
  my %opts=(maxcolors=>2**30,@_);
  if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
  my $rc=i_count_colors($self->{IMG},$opts{'maxcolors'});
  return ($rc==-1? undef : $rc);
}

# draw string to an image

sub string {
  my $self=shift;
  unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }

  my %input=('x'=>0, 'y'=>0, @_);
  $input{string}||=$input{text};

  unless(exists $input{string}) {
    $self->{ERRSTR}="missing required parameter 'string'";
    return;
  }

  unless($input{font}) {
    $self->{ERRSTR}="missing required parameter 'font'";
    return;
  }

  my $aa=1;
  my $font=$input{'font'};
  my $align=$font->{'align'} unless exists $input{'align'};
  my $color=$input{'color'}||$font->{'color'};
  my $size=$input{'size'}||$font->{'size'};

  if (!defined($size)) { $self->{ERRSTR}='No size parameter and no default in font'; return undef; }

  $aa=$font->{'aa'} if exists $font->{'aa'};
  $aa=$input{'aa'} if exists $input{'aa'};



#  unless($font->can('text')) {
#    $self->{ERRSTR}="font is unable to do what we need";
#    return;
#  }

#  use Data::Dumper; 
#  warn Dumper($font);

#  print "Channel=".$input{'channel'}."\n";

  if ( $font->{'type'} eq 't1' ) {
    if ( exists $input{'channel'} ) {
      Imager::Font::t1_set_aa_level($aa);
      i_t1_cp($self->{IMG},$input{'x'},$input{'y'},
	      $input{'channel'},$font->{'id'},$size,
	      $input{'string'},length($input{'string'}),1);
    } else {
      Imager::Font::t1_set_aa_level($aa);
      i_t1_text($self->{IMG},$input{'x'},$input{'y'},
		$color,$font->{'id'},$size,
		$input{'string'},length($input{'string'}),1);
    }
  }

  if ( $font->{'type'} eq 'tt' ) {
    if ( exists $input{'channel'} ) {
      i_tt_cp($font->{'id'},$self->{IMG},$input{'x'},$input{'y'},$input{'channel'},
	      $size,$input{'string'},length($input{'string'}),$aa); 
    } else {
      i_tt_text($font->{'id'},$self->{IMG},$input{'x'},$input{'y'},$color,$size,
		$input{'string'},length($input{'string'}),$aa); 
    }
  }

  return $self;
}





# Shortcuts that can be exported

sub newcolor { Imager::Color->new(@_); }
sub newfont  { Imager::Font->new(@_); }

*NC=*newcolour=*newcolor;
*NF=*newfont;

*open=\&read;
*circle=\&arc;


#### Utility routines

sub errstr { $_[0]->{ERRSTR} }






# Default guess for the type of an image from extension

sub def_guess_type {
  my $name=lc(shift);
  my $ext;
  $ext=($name =~ m/\.([^\.]+)$/)[0];
  return 'tiff' if ($ext =~ m/^tiff?$/);
  return 'jpeg' if ($ext =~ m/^jpe?g$/);
  return 'png' if ($ext eq "png");
  return 'gif' if ($ext eq "gif");
  return 'ppm' if ($ext eq "ppm");
  return ();
}

# get the minimum of a list

sub min {
  my $mx=shift;
  for(@_) { if ($_<$mx) { $mx=$_; }}
  return $mx;
}

# get the maximum of a list

sub max {
  my $mx=shift;
  for(@_) { if ($_>$mx) { $mx=$_; }}
  return $mx;
}

# string stuff for iptc headers

sub clean {
  my($str)=$_[0];
  $str = substr($str,3);
  $str =~ s/[\n\r]//g;
  $str =~ s/\s+/ /g;
  $str =~ s/^\s//;
  $str =~ s/\s$//;
  return $str;
}

# A little hack to parse iptc headers.

sub parseiptc {
  my $self=shift;
  my(@sar,$item,@ar);
  my($caption,$photogr,$headln,$credit);

  my $str=$self->{IPTCRAW};

  #print $str;

  @ar=split(/8BIM/,$str);

  my $i=0;
  foreach (@ar) {
    if (/^\004\004/) {
      @sar=split(/\034\002/);
      foreach $item (@sar) {
	if ($item =~ m/^x/) { 
	  $caption=&clean($item);
	  $i++;
	}
	if ($item =~ m/^P/) { 
	  $photogr=&clean($item);
	  $i++;
	}
	if ($item =~ m/^i/) { 
	  $headln=&clean($item);
	  $i++;
	}
	if ($item =~ m/^n/) { 
	  $credit=&clean($item);
	  $i++;
	}
      }
    }
  }
  return (caption=>$caption,photogr=>$photogr,headln=>$headln,credit=>$credit);
}






# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Imager - Perl extension for Generating 24 bit Images

=head1 SYNOPSIS

  use Imager;

  init();
  $img = Imager->new();
  $img->open(file=>'image.ppm',type=>'ppm')
    || print "failed: ",$img->{ERRSTR},"\n";
  $scaled=$img->scale(xpixels=>400,ypixels=>400);
  $scaled->write(file=>'sc_image.ppm',type=>'ppm')
    || print "failed: ",$scaled->{ERRSTR},"\n";

=head1 DESCRIPTION

Imager is a module for creating and altering images - It is not meant
as a replacement or a competitor to ImageMagick or GD. Both are
excellent packages and well supported.

=head2 API

Almost all functions take the parameters in the hash fashion.
Example: 

  $img->open(file=>'lena.png',type=>'png');

or just:

  $img->open(file=>'lena.png');

=head2 Basic concept

An Image object is created with C<$img = Imager-E<gt>new()> Should
this fail for some reason an explanation can be found in
C<$Imager::ERRSTR> usually error messages are stored in
C<$img-E<gt>{ERRSTR}>, but since no object is created this is the only
way to give back errors.  C<$Imager::ERRSTR> is also used to report
all errors not directly associated with an image object. Examples:

    $img=Imager->new(); # This is an empty image (size is 0 by 0)
    $img->open(file=>'lena.png',type=>'png'); # initializes from file

or if you want to create an empty image:

    $img=Imager->new(xsize=>400,ysize=>300,channels=>3);

The latter example creates a completely black image of width 400 and
height 300 and 4 channels.

To create a color object call the function i_color_new,
C<$color=i_color_new($r,$g,$b,$a)>. The parameters are all from 0 to
255 and are all converted to integers. Each is the red, green, blue,
and alpha component of the color respectively.  This object can then
be passed to functions that require a color parameter.

Coordinates in Imager have the origin in the upper left corner.  The
horizontal coordinate increases to the left and the vertical downwards.

=head2 Reading and writing images

C<$img-E<gt>read()> generally takes two parameters, 'file' and
'type'.  If the type of the file can be determined from the suffix of
the file it can be omitted.  Format dependant parameters are: For
images of type 'raw' two extra parameters are needed 'xsize' and
'ysize', if the 'channel' parameter is omitted for type 'raw' it is
assumed to be 3.  gif and png images might have a palette are
converted to truecolor bit when read.  Alpha channel is preserved for
png images irregardless of them being in RGB or gray colorspace.
Similarly grayscale jpegs are one channel images after reading them.
For jpeg images the iptc header information (stored in the APP13
header) is avaliable to some degree. You can get the raw header with
C<$img-E<gt>{IPTCRAW}>, but you can also retrieve the most basic
information with C<%hsh=$img-E<gt>parseiptc()> as always patches are
welcome.  Neither ppm nor tiff have extra options. Examples:

  $img = Imager->new();
  $img->read(file=>"cover.jpg") or die $img->errstr; # gets type from name

  $img = Imager->new();
  { local(*FH,$/); open(FH,"file.gif") or die $!; $a=<FH>; }
  $img->read(data=>$a,type=>'gif') or die $img->errstr;

The second example shows how to read an image from a scalar, this is
usefull if your data originates from somewhere else than a filesystem
such as a database over a DBI connection.

*Note that load() is now an alias for read but will be removed later*

C<$img-E<gt>write> has the same interface as C<read()>.  The earlier
comments on C<read()> for autodetecting filetypes apply.  For jpegs
quality can be adjusted via the 'jpegquality' parameter (0-100).  The
number of colorplanes in gifs are set with 'gifplanes' and should be
between 1 (2 color) and 8 (256 colors).  It is also possible to choose
between two quantizing methods with the parameter 'gifquant'. If set
to mc it uses the mediancut algorithm from either giflibrary. If set
to lm it uses a local means algorithm. It is then possible to give
some extra settings. lmdither is the dither deviation amount in pixels
(manhattan distance).  lmfixed can be an array ref who holds an array
of i_color objects.  Note that the local means algorithm needs much
more cpu time but also gives considerable better results than the
median cut algorithm.

Currently just for gif files, you can specify various options for the
conversion from Imager's internal RGB format to the target's indexed
file format.  If you set the gifquant option to 'gen', you can use the
options specified under L<Quantization options>.

To see what Imager is compiled to support the following code snippet
is sufficient:

  use Imager;
  print "@{[keys %Imager::formats]}";

=head2 Multi-image files

Currently just for gif files, you can create files that contain more
than one image.

To do this:

  Imager->write_multi(\%opts, @images)

Where %opts describes 3 possible types of outputs:

=over 4

=item callback

A code reference which is called with a single parameter, the data to
be written.  You can also specify $opts{maxbuffer} which is the
maximum amount of data buffered.  Note that there can be larger writes
than this if the file library writes larger blocks.  A smaller value
maybe useful for writing to a socket for incremental display.

=item fd

The file descriptor to save the images to.

=item file

The name of the file to write to.

%opts may also include the keys from L<Gif options> and L<Quantization
options>.

=back

The current aim is to support other multiple image formats in the
future, such as TIFF, and to support reading multiple images from a
single file.

=head2 Gif options

These options can be specified when calling write_multi() for gif
files, when writing a single image with the gifquant option set to
'gen', or for direct calls to i_writegif_gen and i_writegif_callback.

Note that some viewers will ignore some of these options
(gif_user_input in particular).

=over 4

=item gif_each_palette

Each image in the gif file has it's own palette if this is non-zero.
All but the first image has a local colour table (the first uses the
global colour table.

=item interlace

The images are written interlaced if this is non-zero.

=item gif_delays

A reference to an array containing the delays between images, in 1/100
seconds.

=item gif_user_input

A reference to an array contains user input flags.  If the given flag
is non-zero the image viewer should wait for input before displaying
the next image.

=item gif_disposal

A reference to an array of image disposal methods.  These define what
should be done to the image before displaying the next one.  These are
integers, where 0 means unspecified, 1 means the image should be left
in place, 2 means restore to background colour and 3 means restore to
the previous value.

=item gif_tran_color

A reference to an Imager::Color object, which is the colour to use for
the palette entry used to represent transparency in the palette.

=item gif_positions

A reference to an array of references to arrays which represent screen
positions for each image.

=item gif_loop_count

If this is non-zero the Netscape loop extension block is generated,
which makes the animation of the images repeat.

This is currently unimplemented due to some limitations in giflib.

=back

=head2 Quantization options

These options can be specified when calling write_multi() for gif
files, when writing a single image with the gifquant option set to
'gen', or for direct calls to i_writegif_gen and i_writegif_callback.

=over 4

=item colors

A arrayref of colors that are fixed.  Note that some color generators
will ignore this.

=item transp

The type of transparency processing to perform for images with an
alpha channel where the output format does not have a proper alpha
channel (eg. gif).  This can be any of:

=over 4

=item none

No transparency processing is done. (default)

=item threshold

Pixels more transparent that tr_threshold are rendered as transparent.

=item errdiff

An error diffusion dither is done on the alpha channel.  Note that
this is independent of the translation performed on the colour
channels, so some combinations may cause undesired artifacts.

=item ordered

The ordered dither specified by tr_orddith is performed on the alpha
channel.

=back

=item tr_threshold

The highest alpha value at which a pixel will be made transparent when
transp is 'threshold'. (0-255, default 127)

=item tr_errdiff

The type of error diffusion to perform on the alpha channel when
transp is 'errdiff'.  This can be any defined error diffusion type
except for custom (see errdiff below).

=item tr_ordered

The type of ordered dither to perform on the alpha channel when transp
is 'orddith'.  Possible values are:

=over 4

=item random

A semi-random map is used.  The map is the same each time.  Currently
the default (which may change.)

=item dot8

8x8 dot dither.

=item dot4

4x4 dot dither

=item hline

horizontal line dither.

=item vline

vertical line dither.

=item "/line"

=item slashline

diagonal line dither

=item '\line'

=item backline

diagonal line dither

=item custom

A custom dither matrix is used - see tr_map

=back

=item tr_map

When tr_orddith is custom this defines an 8 x 8 matrix of integers
representing the transparency threshold for pixels corresponding to
each position.  This should be a 64 element array where the first 8
entries correspond to the first row of the matrix.  Values should be
betweern 0 and 255.

=item make_colors

Defines how the quantization engine will build the palette(s).
Currently this is ignored if 'translate' is 'giflib', but that may
change.  Possible values are:

=over 4

=item none

Only colors supplied in 'colors' are used.

=item webmap

The web color map is used (need url here.)

=item addi

The original code for generating the color map (Addi's code) is used.

=back

Other methods may be added in the future.

=item colors

A arrayref containing Imager::Color objects, which represents the
starting set of colors to use in translating the images.  webmap will
ignore this.  The final colors used are copied back into this array
(which is expanded if necessary.)

=item max_colors

The maximum number of colors to use in the image.

=item translate

The method used to translate the RGB values in the source image into
the colors selected by make_colors.  Note that make_colors is ignored
whene translate is 'giflib'.

Possible values are:

=over 4

=item giflib

The giflib native quantization function is used.

=item closest

The closest color available is used.

=item perturb

The pixel color is modified by perturb, and the closest color is chosen.

=item errdiff

An error diffusion dither is performed.

=back

It's possible other transate values will be added.

=item errdiff

The type of error diffusion dither to perform.  These values (except
for custom) can also be used in tr_errdif.

=over 4

=item floyd

Floyd-Steinberg dither

=item jarvis

Jarvis, Judice and Ninke dither

=item stucki

Stucki dither

=item custom

Custom.  If you use this you must also set errdiff_width,
errdiff_height and errdiff_map.

=back

=item errdiff_width

=item errdiff_height

=item errdiff_orig

=item errdiff_map

When translate is 'errdiff' and errdiff is 'custom' these define a
custom error diffusion map.  errdiff_width and errdiff_height define
the size of the map in the arrayref in errdiff_map.  errdiff_orig is
an integer which indicates the current pixel position in the top row
of the map.

=item perturb

When translate is 'perturb' this is the magnitude of the random bias
applied to each channel of the pixel before it is looked up in the
color table.

=back

=head2 Obtaining/setting attributes of images

To get the size of an image in pixels the C<$img-E<gt>getwidth()> and
C<$img-E<gt>getheight()> are used.  

To get the number of channels in
an image C<$img-E<gt>getchannels()> is used.  $img-E<gt>getmask() and
$img-E<gt>setmask() are used to get/set the channel mask of the image.

  $mask=$img->getmask();
  $img->setmask(mask=>1+2); # modify red and green only
  $img->setmask(mask=>8); # modify alpha only
  $img->setmask(mask=>$mask); # restore previous mask

The mask of an image describes which channels are updated when some
operation is performed on an image.  Naturally it is not possible to
apply masks to operations like scaling that alter the dimensions of
images.

It is possible to have Imager find the number of colors in an image
by using C<$img-E<gt>getcolorcount()>. It requires memory proportionally
to the number of colors in the image so it is possible to have it
stop sooner if you only need to know if there are more than a certain number
of colors in the image.  If there are more colors than asked for
the function return undef.  Examples:

  if (!defined($img->getcolorcount(maxcolors=>512)) {
    print "Less than 512 colors in image\n";
  }

=head2 Drawing Methods

IMPLEMENTATION MORE OR LESS DONE CHECK THE TESTS

DOCUMENTATION OF THIS SECTION OUT OF SYNC

It is possible to draw with graphics primitives onto images.  Such
primitives include boxes, arcs, circles and lines.  A reference
oriented list follows.

Box:
  $img->box(color=>$blue,xmin=>10,ymin=>30,xmax=>200,ymax=>300,filled=>1);

The Above example calls the C<box> method for the image and the box
covers the pixels with in the rectangle specified.  If C<filled> is
ommited it is drawn as an outline.  If any of the edges of the box are
ommited it will snap to the outer edge of the image in that direction.
Also if a color is omitted a color with (255,255,255,255) is used
instead.

Arc:
  $img->arc(color=>$red, r=20, x=>200, y=>100, d1=>10, d2=>20 );

This creates a red arc with a 'center' at (200, 100) and spans 10
degrees and the slice has a radius of 20. SEE section on BUGS.

Circle:
  $img->circle(color=>$green, r=50, x=>200, y=>100);

This creates a green circle with its center at (200, 100) and has a
radius of 20.

Line:
  $img->line(color=>$green, x1=10, x2=>100, 
                            y1=>20, y2=>50, antialias=>1 );

That draws an antialiased line from (10,100) to (20,50).

Polyline:
  $img->polyline(points=>[[$x0,$y0],[$x1,$y1],[$x2,$y2]],color=>$red);
  $img->polyline(x=>[$x0,$x1,$x2], y=>[$y0,$y1,$y2], antialias=>1);

Polyline is used to draw multilple lines between a series of points.
The point set can either be specified as an arrayref to an array of
array references (where each such array represents a point).  The
other way is to specify two array references.

=head2 Text rendering

To create a font object you can use:

  $t1font = Imager::Font->new(file=>'pathtofont.pfb');
  $ttfont = Imager::Font->new(file=>'pathtofont.ttf');

As is two types of font types are supported t1 postscript
fonts and truetype fonts.  You can see if they are supported
in your binary with the C<%Imager::formats> hash.  It is possible
to control other attributes the font such as default color, size
and anti aliasing.

  $blue = Imager::Color->new(10,10,255,0);
  $t1font = Imager::Font->new(file=>'pathtofont.pfb',
                              color=>$blue,
                              size=30);

To draw text on images the string method of the images is used.
A font must be passed to the method.

  $img=Imager->new();
  $img=read(file=>"test.jpg");
  $img->string(font=>$t1font,
               text=>"Model-XYZ",
               x=>0,
               y=>40,
               size=>40,
               color=>$red);
  $img->write(file=>"testout.jpg");

This would put a 40 pixel high text in the top left corner of an
image.  If you measure the actuall pixels it varies since the fonts
usually do not use their full height.  It seems that the color and
size can be specified twice.  When a font is created only the actual
font specified matters.  It his however convenient to store default
values in a font, such as color and size.  If parameters are passed to
the string function they are used instead of the defaults stored in
the font.

If string() is called with the C<channel> parameter then the color
isn't used and the font is drawn in only one channel.  This can
be quite handy to create overlays.  See the examples for tips about
this.

Sometimes it is necessary to know how much space a string takes before
rendering it.  The bounding_box() method of a font can be used for that.
examples:

  @bbox=$font->bounding_box(string=>"testing",size=>15);
  @bbox=$font->bounding_box(string=>"testing",size=>15,canon=>1);
  @bbox=$font->bounding_box(string=>"testing",size=>15,x=50,y=>20);

The first example gets the so called glyph metrics.  First is the



=head2 Image resizing

To scale an image so porportions are maintained use the
C<$img-E<gt>scale()> method.  if you give either a xpixels or ypixels
parameter they will determine the width or height respectively.  If
both are given the one resulting in a larger image is used.  example:
C<$img> is 700 pixels wide and 500 pixels tall.

  $img->scale(xpixels=>400); # 400x285
  $img->scale(ypixels=>400); # 560x400

  $img->scale(xpixels=>400,ypixels=>400); # 560x400
  $img->scale(xpixels=>400,ypixels=>400,type=>min); # 400x285

  $img->scale(scalefactor=>0.25); 175x125 $img->scale(); # 350x250

if you want to create low quality previews of images you can pass
C<qtype=E<gt>'preview'> to scale and it will use nearest neighbor
sampling instead of filtering. It is much faster but also generates
worse looking images - especially if the original has a lot of sharp
variations and the scaled image is by more than 3-5 times smaller than
the original.

If you need to scale images per axis it is best to do it simply by
calling scaleX and scaleY.  You can pass either 'scalefactor' or
'pixels' to both functions.

Another way to resize an image size is to crop it.  The parameters
to crop are the edges of the area that you want in the returned image.
If a parameter is omited a default is used instead.

  $img->crop(left=>50, right=>100, top=>10, bottom=>100); 
  $img->crop(left=>50, top=>10, width=>50, height=>90);
  $img->crop(left=>50, right=>100); # top 


=head2 Copying images

To create a copy of an image use the C<copy()> method.  This is usefull
if you want to keep an original after doing something that changes the image
inplace like writing text.

  $img=$orig->copy();

To copy an image to onto another image use the C<paste()> method.

  $dest->paste(left=>40,top=>20,img=>$logo);

That copies the entire C<$logo> image onto the C<$dest> image so that the
upper left corner of the C<$logo> image is at (40,20).

=head2 Blending Images
 
To put an image or a part of an image directly into another it is
best to call the C<paste()> method on the image you want to add to.

  $img->paste(img=>$srcimage,left=>30,top=>50);

That will take paste C<$srcimage> into C<$img> with the upper
left corner at (30,50).  If no values are given for C<left>
or C<top> they will default to 0.

A more complicated way of blending images is where one image is 
put 'over' the other with a certain amount of opaqueness.  The
method that does this is rubthrough.

  $img->rubthrough(src=>$srcimage,tx=>30,ty=>50); 

That will take the image C<$srcimage> and overlay it with the 
upper left corner at (30,50).  The C<$srcimage> must be a 4 channel
image.  The last channel is used as an alpha channel.


=head2 Filters

A special image method is the filter method. An example is:

  $img->filter(type=>'autolevels');

This will call the autolevels filter.  Here is a list of the filters
that are always avaliable in Imager.  This list can be obtained by
running the C<filterlist.perl> script that comes with the module
source.

  Filter          Arguments
  turbnoise
  autolevels      lsat(0.1) usat(0.1) skew(0)
  radnoise
  noise           amount(3) subtype(0)
  contrast        intensity
  hardinvert

The default values are in parenthesis.  All parameters must have some
value but if a parameter has a default value it may be omitted when
calling the filter function.

=head2 Transformations

Another special image method is transform.  It can be used to generate
warps and rotations and such features.  It can be given the operations
in postfix notation or the module Affix::Infix2Postfix can be used.
Look in the test case t/t55trans.t for an example.

Later versions of Imager also support a transform2() class method
which allows you perform a more general set of operations, rather than
just specifying a spatial transformation as with the transform()
method, you can also perform colour transformations, image synthesis
and image combinations.

transform2() takes an reference to an options hash, and a list of
images to operate one (this list may be empty):

  my %opts;
  my @imgs;
  ...
  my $img = Imager::transform2(\%opts, @imgs)
      or die "transform2 failed: $Imager::ERRSTR";

The options hash may define a transformation function, and optionally:

=over 4

=item *

width - the width of the image in pixels.  If this isn't supplied the
width of the first input image is used.  If there are no input images
an error occurs.

=item *

height - the height of the image in pixels.  If this isn't supplied
the height of the first input image is used.  If there are no input
images an error occurs.

=item *

constants - a reference to hash of constants to define for the
expression engine.  Some extra constants are defined by Imager

=back

The tranformation function is specified using either the expr or
rpnexpr member of the options.

=over 4

=item Infix expressions

You can supply infix expressions to transform 2 with the expr keyword.

$opts{expr} = 'return getp1(w-x, h-y)'

The 'expression' supplied follows this general grammar:

   ( identifier '=' expr ';' )* 'return' expr

This allows you to simplify your expressions using variables.

A more complex example might be:

$opts{expr} = 'pix = getp1(x,y); return if(value(pix)>0.8,pix*0.8,pix)'

Currently to use infix expressions you must have the Parse::RecDescent
module installed (available from CPAN).  There is also what might be a
significant delay the first time you run the infix expression parser
due to the compilation of the expression grammar.

=item Postfix expressions

You can supply postfix or reverse-polish notation expressions to
transform2() through the rpnexpr keyword.

The parser for rpnexpr emulates a stack machine, so operators will
expect to see their parameters on top of the stack.  A stack machine
isn't actually used during the image transformation itself.

You can store the value at the top of the stack in a variable called
foo using !foo and retrieve that value again using @foo.  The !foo
notation will pop the value from the stack.

An example equivalent to the infix expression above:

 $opts{rpnexpr} = 'x y getp1 !pix @pix value 0.8 gt @pix 0.8 * @pix ifp'

=back

transform2() has a fairly rich range of operators.

=over 4

=item +, *, -, /, %, **

multiplication, addition, subtraction, division, remainder and
exponentiation.  Multiplication, addition and subtraction can be used
on colour values too - though you need to be careful - adding 2 white
values together and multiplying by 0.5 will give you grey, not white.

Division by zero (or a small number) just results in a large number.
Modulo zero (or a small number) results in zero.

=item sin(N), cos(N), atan2(y,x)

Some basic trig functions.  They work in radians, so you can't just
use the hue values.

=item distance(x1, y1, x2, y2)

Find the distance between two points.  This is handy (along with
atan2()) for producing circular effects.

=item sqrt(n)

Find the square root.  I haven't had much use for this since adding
the distance() function.

=item abs(n)

Find the absolute value.

=item getp1(x,y), getp2(x,y), getp3(x, y)

Get the pixel at position (x,y) from the first, second or third image
respectively.  I may add a getpn() function at some point, but this
prevents static checking of the instructions against the number of
images actually passed in.

=item value(c), hue(c), sat(c), hsv(h,s,v)

Separates a colour value into it's value (brightness), hue (colour)
and saturation elements.  Use hsv() to put them back together (after
suitable manipulation).

=item red(c), green(c), blue(c), rgb(r,g,b)

Separates a colour value into it's red, green and blue colours.  Use
rgb(r,b,g) to put it back together.

=item int(n)

Convert a value to an integer.  Uses a C int cast, so it may break on
large values.

=item if(cond,ntrue,nfalse), if(cond,ctrue,cfalse)

A simple (and inefficient) if function.

=item <=,<,==,>=,>,!=

Relational operators (typically used with if()).  Since we're working
with floating point values the equalities are 'near equalities' - an
epsilon value is used.

=item &&, ||, not(n)

Basic logical operators.

=back

A few examples:

=over 4

=item rpnexpr=>'x 25 % 15 * y 35 % 10 * getp1 !pat x y getp1 !pix @pix sat 0.7 gt @pat @pix ifp'

tiles a smaller version of the input image over itself where the colour has a saturation over 0.7.

=item rpnexpr=>'x 25 % 15 * y 35 % 10 * getp1 !pat y 360 / !rat x y getp1 1 @rat - pmult @pat @rat pmult padd'

tiles the input image over itself so that at the top of the image the
full-size image is at full strength and at the bottom the tiling is
most visible.

=item rpnexpr=>'x y getp1 !pix @pix value 0.96 gt @pix sat 0.1 lt and 128 128 255 rgb @pix ifp'

replace pixels that are white or almost white with a palish blue

=item rpnexpr=>'x 35 % 10 * y 45 % 8 * getp1 !pat x y getp1 !pix @pix sat 0.2 lt @pix value 0.9 gt and @pix @pat @pix value 2 / 0.5 + pmult ifp'

Tiles the input image overitself where the image isn't white or almost
white.

=item rpnexpr=>'x y 160 180 distance !d y 180 - x 160 - atan2 !a @d 10 / @a + 3.1416 2 * % !a2 @a2 180 * 3.1416 / 1 @a2 sin 1 + 2 / hsv'

Produces a spiral.

=item rpnexpr=>'x y 160 180 distance !d y 180 - x 160 - atan2 !a @d 10 / @a + 3.1416 2 * % !a2 @a 180 * 3.1416 / 1 @a2 sin 1 + 2 / hsv'

A spiral built on top of a colour wheel.

=back

For details on expression parsing see L<Imager::Expr>.  For details on
the virtual machine used to transform the images, see
L<Imager::regmach.pod>.

=head2 Plugins

It is possible to add filters to the module without recompiling the
module itself.  This is done by using DSOs (Dynamic shared object)
avaliable on most systems.  This way you can maintain our own filters
and not have to get me to add it, or worse patch every new version of
the Module.  Modules can be loaded AND UNLOADED at runtime.  This
means that you can have a server/daemon thingy that can do something
like:

  load_plugin("dynfilt/dyntest.so")  || die "unable to load plugin\n";
  %hsh=(a=>35,b=>200,type=>lin_stretch);
  $img->filter(%hsh);
  unload_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
  $img->write(type=>'ppm',file=>'testout/t60.jpg') 
    || die "error in write()\n";

Someone decides that the filter is not working as it should -
dyntest.c modified and recompiled.

  load_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
  $img->filter(%hsh); 

An example plugin comes with the module - Please send feedback to 
addi@umich.edu if you test this.

Note: This seems to test ok on the following systems:
Linux, Solaris, HPUX, OpenBSD, FreeBSD, TRU64/OSF1, AIX.
If you test this on other systems please let me know.

=head1 BUGS

box, arc, circle do not support antialiasing yet.  arc, is only filled
as of yet.  Some routines do not return $self where they should.  This
affects code like this, C<$img-E<gt>box()-E<gt>arc()> where an object
is expected.

When saving Gif images the program does NOT try to shave of extra
colors if it is possible.  If you specify 128 colors and there are
only 2 colors used - it will have a 128 colortable anyway.

=head1 AUTHOR

Arnar M. Hrafnkelsson, addi@umich.edu
And a great deal of help from others - see the README for a complete
list.
=head1 SEE ALSO

perl(1), Affix::Infix2Postfix(3).
http://www.eecs.umich.edu/~addi/perl/Imager/


=cut
