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

# cache structure
# ['name','filename','references']

sub add_to_cache {


}

sub t1_set_aa_level {
  if ($_[0] != $T1AA) {
    i_t1_set_aa($_[0]);
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
  
  $self->{'aa'}=$hsh{'aa'}||"0";
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
  if ($self->{type} eq 't1') {
    @box=Imager::i_t1_bbox($self->{id}, $self->{size},
			   $input{string}, length($input{string}));
  }
  if ($self->{type} eq 'tt') {
    @box=Imager::i_tt_bbox($self->{id}, $self->{size},
			   $input{string}, length($input{string}));
  }
  
  if(exists $input{'x'} and exists $input{'y'}) {
    my($descent, $ascent)=@box[1,3];
    $box[1]=$input{'y'}-$ascent;      # top = base - ascent (Y is down)
    $box[3]=$input{'y'}-$descent;     # bottom = base - descent (Y is down, descent is negative)
    $box[0]+=$input{'x'};
    $box[2]+=$input{'x'};
  } else {
    $box[3]-=$box[1];    # make it cannoical (ie (0,0) - (width, height))
    $box[1]-=$box[1];
  }
  return @box;
}               





# Leolo's function

# sub font {
#     my $self=shift;
#     my %input=@_;

#     $input{type}||='T1' if $input{number};
#     if(not $input{file} and not $input{number}) {
#         $self->{ERRSTR}="missing required parameter 'file' or 'number'";
#         return;
#     }
    
#     my $type=$input{type};
#     $type||=$1 if not $type and $input{file}=~/\.([^.]+)$/;

#     unless($type) {
#         $self->{ERRSTR}="missing required parameter 'type'";
#         return;
#     }
    
#     $type=uc $type;
#     $type='TTF' if $type eq "TRUETYPE";
    
#     $input{size}||=8;
#     $input{colour}||=$input{color}||i_color_new(0,0,0,255);
#     delete $input{color};

#     if($type eq 'TTF') {
#         require Imager::TTF;
#         return Imager::TTF->new(%input);
#     } elsif($type eq 'T1') {
#         require Imager::T1;
#         return Imager::T1->new(%input);
#     } else {
#         $self->{ERRSTR}="unknown font type : '$type'";
#         return;
#     }
# }





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

		i_readpng
		i_writepng

		i_readgif
		i_writegif
		i_writegifmc

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
  
  $VERSION = '0.32';
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
# MISSING FEAT - if an image has magic the copy of it will not be magical

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
  return 1;  # What should go here??
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

  my $stuff;
    
  if (defined($self->{IMG})) {
    i_img_destroy($self->{IMG});
    undef($self->{IMG});
  }
    
  if (!$input{file}) { $self->{ERRSTR}='file parameter missing'; return undef; }
  if (!$input{type}) { $input{type}=$FORMATGUESS->($input{file}); }
  if (!$input{type}) { $self->{ERRSTR}='type parameter missing and not possible to guess from extension'; return undef; }
  
  if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }
  
  my $fh = new IO::File($input{file},"r");
  binmode($fh);
  if (!defined $fh) {	$self->{ERRSTR}='Could not open file'; return undef; }
  
  if ( $input{type} eq 'gif' ) {
    $self->{IMG}=i_readgif($fh->fileno());
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read gif image'; return undef; }
    $self->{DEBUG} && print "loading a gif file\n";
  } elsif ( $input{type} eq 'jpeg' ) {
    ($self->{IMG},$self->{IPTCRAW})=i_readjpeg($fh->fileno());
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read jpeg image'; return undef; }
    $self->{DEBUG} && print "loading a jpeg file\n";
  } elsif ( $input{type} eq 'png' ) {
    $self->{IMG}=i_readpng($fh->fileno());
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read png image'; return undef; }
    $self->{DEBUG} && print "loading a png file\n";
  } elsif ( $input{type} eq 'ppm' ) { 
    $self->{IMG}=i_readppm($fh->fileno());
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read ppm image'; return undef; }
    $self->{DEBUG} && print "loading a ppm file\n";
  } elsif ( $input{type} eq 'raw' ) {
    my %params=(datachannels=>3,storechannels=>3,interleave=>1);
    for(keys(%input)) { $params{$_}=$input{$_}; }
    
    if ( !($params{xsize} && $params{ysize}) ) { $self->{ERRSTR}='missing xsize or ysize parameter for raw'; return undef; }
    $self->{IMG}=i_readraw($fh->fileno(),$params{xsize},$params{ysize},
			   $params{datachannels},$params{storechannels},$params{interleave});
    if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read raw image'; return undef; }
    $self->{DEBUG} && print "loading a raw file\n";
  }
  return $self;
}


# Write an image to file

sub write {
  my $self = shift;
  my %input=(gifplanes=>8,jpegquality=>75,gifquant=>'mc',lmdither=>6.0,lmfixed=>[],@_);
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
    if ($input{gifplanes}>8) { $input{gifplanes}=8; }
    if ($input{gifquant} eq 'lm') {
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
  }
  return $self;
}

# Destroy an Imager object

sub DESTROY {
  my $self=shift;
  #    delete $instances{$self};
  if (defined($self->{IMG})) {
    i_img_destroy($self->{IMG});
    undef($self->{IMG});
  } else {
    print "Destroy Called on an empty image!\n";
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
  
  unless($input{string}) {
    $self->{ERRSTR}="missing required parameter 'string'";
    return;
  }

  unless($input{font}) {
    $self->{ERRSTR}="missing required parameter 'font'";
    return;
  }
  
  my $font=$input{'font'};
  my $align=$font->{'align'} unless exists $input{'align'};
  my $color=$input{'color'}||$font->{'color'};
  my $size=$input{'size'}||$font->{'size'};

  if (!defined($size)) { $self->{ERRSTR}='No size parameter and no default in font'; return undef; }

#  unless($font->can('text')) {
#    $self->{ERRSTR}="font is unable to do what we need";
#    return;
#  }
  
#  use Data::Dumper; 
#  warn Dumper($font);

#  print "Channel=".$input{'channel'}."\n";
  
  if ( $font->{'type'} eq 't1' ) {
    if ( exists $input{'channel'} ) {
      i_t1_cp($self->{IMG},$input{'x'},$input{'y'},
	      $input{'channel'},$font->{'id'},$size,
	      $input{'string'},length($input{'string'}),1);
    } else {
      i_t1_text($self->{IMG},$input{'x'},$input{'y'},
		$color,$font->{'id'},$size,
		$input{'string'},length($input{'string'}),1);
    }
  }
  
  if ( $font->{'type'} eq 'tt' ) {
    if ( exists $input{'channel'} ) {
      i_tt_cp($font->{'id'},$self->{IMG},$input{'x'},$input{'y'},$input{'channel'},
	      $size,$input{'string'},length($input{'string'}),1); 
      # FIXME: Smoothing hardcoded for the time being (who wants unsmoothed anyway)
    } else {
      i_tt_text($font->{'id'},$self->{IMG},$input{'x'},$input{'y'},$color,$size,
		$input{'string'},length($input{'string'}),1); 
      # FIXME: Smoothing hardcoded for the time being (who wants unsmoothed anyway)
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

# Default guess for the type of an image from extension

sub def_guess_type {
  my $name=lc(shift);
  my $ext;
  $ext=($name =~ m/\.([^\.]+)$/)[0];
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

Why a new module? Compiling PerlMagick can be complicated, and it
lacks drawing functions. GD.pm has those but only supports gif and
png.  I like studying graphics, so why not let others in a similar
situation benefit?  The basis for this module is code written to
preprocess remote sensing data.

Note: Documentation is ordered in:

API

Basic concepts

Reading and writing images

Obtaining/setting attributes of images

Drawing Methods

Text rendering

Image resizing

Filters

Transformations

Plugins

Internals

Functional interface

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

or if you want to start clean image:

    $img=Imager->new(xsize=>400,ysize=>300,channels=>3);

The latter example creates a completely black image of width 400 and
height 300 and 4 channels.

To create a color object call the function i_color_new,
C<$color=i_color_new($r,$g,$b,$a)>. The parameters are all from 0 to
255 and are all converted to integers. Each is the red, green, blue,
and alpha component of the color respectively.  This object can then
be passed to functions that require a color parameter.

=head2 Reading and writing images

C<$img-E<gt>read()> has generally has two parameters, 'file' and
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
welcome.

*Note that load() is now an alias for read but will be removed later*

C<$img-E<gt>write> has the same interface as C<open()>.  The earlier
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
  $img->circle(color=>$green, r=50, x=>200, y=>100 );

This creates a green circle with its center at (200, 100) and has a
radius of 20.

  $img->polyline(points=>[[$x0,$y0],[$x1,$y1],[$x2,$y2]],color=>$red);
  $img->polyline(x=>[$x0,$x1,$x2],y=>[$y0,$y1,$y2],antialias=>1);

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

  $blue = Imager::Color(10,10,255,0);
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
image.  You see that it seems that the color and size can be
specified twice.  When a font is created only the actual font specified
matters.  It his however convenient to store default values in
a font.  If parameters are passed to the string function they are
used.  If a parameter is not supplied then the font is searched for
the parameter instead.

If string() is called with the C<channel> parameter then the color 
isn't used and the font is drawn in only one channel.  This can
be quite handy to create overlays.

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
Linux, Solaris, HPUX, OpenBSD, FreeBSD, TRU64/OSF1.
If you test this on other systems please let me know.

=head2 Internals

DOCUMENTATION OF THIS SECTION INCOMPLETE

An image object is a wrapper around the raw handle to an image.  It is
stored in the IMG value of the object hash.  When C<Imager-E<gt>new()> is
called the IMG member is set to undef by default but if you give it
arguments like C<$img=Imager-E<gt>new(xsize=E<gt>100,ysize=E<gt>100)> then it
will return a 3 channel image of size 100 x 100..


=head1 Functional interface

DOCUMENTATION OF THIS SECTION OUT OF SYNC WITH CODE

NO I MEAN IT'S REALLY OUTDATED!!!

Use only if you cannot do what you need to do with
the OO interface. This is mostly intended for 
people who want to develop the OO interface or
the XS part of the module.

  $bool   = i_has_format($str);
  
  $colref = i_color_set($colref,$r,$g,$b,$a);
  
  $imref  = i_img_empty($imref,$x,$y);
  $imref  = i_img_empty_ch($imref,$x,$y,$channels);
  
  @iminfo = i_img_info($imref);
  
            i_img_setmask($imref,$channel_mask);
  $ch_msk = i_img_getmask($imref);

            i_draw($imref,$x1,$y1,$x2,$y2,$colref);
            i_box($imref,$x1,$y1,$x2,$y2,$colref);
            i_box_filled($imref,$x1,$y1,$x2,$y2,$colref);
            i_arc($imref,$x,$y,$rad,$deg1,$deg2,$colref);
  
            i_copyto($imref,$srcref,$x1,$y1,$x2,$y2,$tx,$ty,
  		   $trans_cl_ref);
            i_rubthru($imref,$srcref,$tx,$ty);
   $imref = i_scaleaxis($imref,$scale_factor,$axis);
  
            i_gaussian($imref,$stdev);
            i_conv($imref,$arrayref,$array_len);
  
            i_img_diff($imref1,$imref2);
  
            i_init_fonts();
  
            i_t1_set_aa($level);
            i_t1_cp($imref,$xb,$yb,$channel,$fontnum,
  		  $pts,$str,$strlen,$align);
            i_t1_text($imref,$xb,$yb,$colorref,
		      $fontnum,$pts,$str,$strlen,$align);

            i_tt_set_aa($level);
            i_tt_cp($imref,$xb,$yb,$channel,$fontname,
  	          $pts,$str,$strlen,$align);
            i_tt_text($imref,$xb,$yb,$colorref,
		      $fontname,$pts,$str,$strlen,$align);


   @bbox  = i_t1_bbox($fontnum,$pts,$str,$strlen);
  
   $imref = i_readjpeg($imref,$fd);
   ($imref, 
   $CPTI) = i_readjpeg($imref,$fd);
            i_writejpeg($imref,$fd,$qfactor);
  
   $imref = i_readpng($imref,$fd);
            i_writepng($imref,$fd);
  
   $imref = i_readgif($imref,$fd);
   ($imref, 
 $colour_list) = i_readgif($imref,$fd);
            i_writegif($imref,$fd,$planes,$lmdither,$lmfixed);
            i_writegifmc($imref,$fd,$planes);

   $imref = i_readppm($imref,$fd);
            i_writeppm($imref,$fd);
  
            i_readraw($imref,$fd,$xsize,$ysize,$datachannels,
  		    $storechannels,$interleave);
            i_writeraw($imref,$fd);
  

=head1 BUGS

This documentation is all very messy!

box, arc, circle do not support antialiasing yet.  arc, is only filled
as of yet.  Some routines do not return $self where they should.  This
affects code like this, C<$img-E<gt>box()-E<gt>arc()> where an object
is expected.

When saving Gif images the program does NOT try to shave of extra
colors if it is possible.  If you specify 128 colors and there are
only 2 colors used - it will have a 128 colortable anyway.

There are some undocumented functions lying around - you can look at
the *sigh* ugly list of EXPORT symbols at the top of Imager.pm and try
to find out what a call does if you feel adventureus


=head1 TODO

Fix the bugs ofcourse and look in the TODO file

=head1 AUTHOR

Arnar M. Hrafnkelsson, addi@umich.edu

=head1 SEE ALSO

perl(1), Affix::Infix2Postfix(3).
http://www.eecs.umich.edu/~addi/perl/Imager/


=cut
