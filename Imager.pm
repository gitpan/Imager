package Imager;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %formats $DEBUG %instances %filters %DSOs $ERRSTR $fontstate);
use IO::File;

#use Data::Dumper;

#require Exporter;
#require DynaLoader;
#require AutoLoader;
#@ISA = qw(Exporter AutoLoader DynaLoader);

@EXPORT = qw(
	     init_log
	     
	     DSO_open
	     DSO_close
	     DSO_funclist
	     DSO_call

	     load_plugin
	     unload_plugin

	     i_list_formats
	     i_has_format
	     
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
	     i_box
	     i_box_filled
	     i_arc

	     i_copyto
	     i_rubthru
	     i_scaleaxis
	     i_scale_nn

	     i_gaussian
	     i_conv

	     i_img_diff

	     i_init_fonts
	     i_t1_set_aa
	     i_t1_cp
	     i_t1_text
	     i_t1_bbox

	     i_readjpeg
	     i_writejpeg

	     i_readpng
	     i_writepng

	     i_readgif
	     i_writegif

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
);



BEGIN { 
    require Exporter;
    require DynaLoader;

    $VERSION = '0.21';

    @ISA = qw(Exporter DynaLoader);
    bootstrap Imager $VERSION;
}

BEGIN {
    for(i_list_formats()) { $formats{$_}++; }
    
    if ($formats{t1}) {
	if ($ENV{T1LIB_CONFIG}) {
	    $fontstate='ok';
	    i_init_fonts();
	} else {
	    $fontstate='missing conf';
	    delete $formats{t1};
	}
    } else {
	$fontstate='no font support';
    }
    
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
        
}

sub init {
    my %parms=(loglevel=>1,@_);
    
    if ($parms{log}) {
	init_log($parms{log},$parms{loglevel});
    }
    
    if ($parms{T1LIB_CONFIG}) { $ENV{T1LIB_CONFIG}=$parms{T1LIB_CONFIG}; }

    if ( $ENV{T1LIB_CONFIG} and ( $fontstate eq 'missing conf' )) {
	i_init_fonts();
	$fontstate='ok';
    }
}



END {
    if ($DEBUG) {
	print "shutdown code\n";
	for(keys %instances) { 
	    $instances{$_}->DESTROY();
	}
	malloc_state();
    
	print "Imager exiting\n";
    }
}

sub load_plugin {
    my ($filename)=@_;
    my $i;
    my ($DSO_handle,$str)=DSO_open($filename);
    if (!defined($DSO_handle)) { $Imager::ERRSTR="Couldn't load plugin '$filename}'\n"; return undef; }
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
#    print Dumper(\%filters);
    return 1;
}

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



# Preloaded methods go here.

sub new {
    my $class = shift;
    my $self ={};
    bless $self,$class;
    $self->{IMG}=undef;    # Just to indicate what exists
    $self->{ERRSTR}=undef; #
    $self->{DEBUG}=$DEBUG;
    $self->{DEBUG} && print "Initialized Imager\n";
    $instances{$self}=$self;
    return $self;
}

sub img_set {
    my $self=shift;
    
    my %hsh=(xsize=>100,ysize=>100,channels=>3,@_);
    
    if (defined($self->{IMG})) {
	i_img_destroy($self->{IMG});
	undef($self->{IMG});
    }

    $self->{IMG}=i_img_empty_ch(undef,$hsh{'xsize'},$hsh{'ysize'},$hsh{'channels'});

}



sub open {
    my $self = shift;
    my %input=@_;

    my $stuff;


    if (defined($self->{IMG})) {
	i_img_destroy($self->{IMG});
	undef($self->{IMG});
    }
    
    if (!$input{file}) { $self->{ERRSTR}='file parameter missing'; return undef; }
    if (!$input{type}) { $self->{ERRSTR}='type parameter missing'; return undef; }

    if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }

    my $fh = new IO::File($input{file},"r");
    if (!defined $fh) {	$self->{ERRSTR}='Could not open file'; return undef; }

    if ( $input{type} eq 'gif' ) { 
	$self->{IMG}=i_readgif(undef,$fh->fileno());
	if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read gif image'; return undef; }
	$self->{DEBUG} && print "loading a gif file\n";
    } elsif ( $input{type} eq 'jpeg' ) {
	($self->{IMG},$self->{IPTCRAW})=i_readjpeg(undef,$fh->fileno());
	if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read jpeg image'; return undef; }
	$self->{DEBUG} && print "loading a jpeg file\n";
    } elsif ( $input{type} eq 'png' ) {
	$self->{IMG}=i_readpng(undef,$fh->fileno());
	if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read png image'; return undef; }
	$self->{DEBUG} && print "loading a png file\n";
    } elsif ( $input{type} eq 'ppm' ) { 
	$self->{IMG}=i_readppm(undef,$fh->fileno());
	if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read ppm image'; return undef; }
	$self->{DEBUG} && print "loading a ppm file\n";
    } elsif ( $input{type} eq 'raw' ) {
	my %params=(datachannels=>3,storechannels=>3,interleave=>1);
	for(keys(%input)) { $params{$_}=$input{$_}; }
	
	if ( !($params{xsize} && $params{ysize}) ) { $self->{ERRSTR}='missing xsize or ysize parameter for raw'; return undef; }
	$self->{IMG}=i_readraw(undef,$fh->fileno(),$params{xsize},$params{ysize},
			       $params{datachannels},$params{storechannels},$params{interleave});
	if ( !defined($self->{IMG}) ) { $self->{ERRSTR}='unable to read raw image'; return undef; }
	$self->{DEBUG} && print "loading a raw file\n";
    }
    return 1;
}

sub write {
    my $self = shift;
    my %input=(gifplanes=>8,jpegquality=>75,@_);
    my $rc;

    if (!$input{file}) { $self->{ERRSTR}='file parameter missing'; return undef; }
    if (!$input{type}) { $self->{ERRSTR}='type parameter missing'; return undef; }

    if (!$formats{$input{type}}) { $self->{ERRSTR}='format not supported'; return undef; }

    my $fh = new IO::File($input{file},"w+");
    if (!defined $fh) {	$self->{ERRSTR}='Could not open file'; return undef; }
    
    if ( $input{type} eq 'gif' ) {
	$rc=i_writegif($self->{IMG},$fh->fileno(),$input{gifplanes});
	if ( !defined($rc) ) { $self->{ERRSTR}='unable to write gif image'; return undef; }
	$self->{DEBUG} && print "writing a gif file\n";
    } elsif ( $input{type} eq 'jpeg' ) {
	$rc=i_writejpeg($self->{IMG},$fh->fileno(),$input{jpegquality});
	if ( !defined($rc) ) { $self->{ERRSTR}='unable to write jpeg image'; return undef; }
	$self->{DEBUG} && print "writing a jpeg file\n";
    } elsif ( $input{type} eq 'png' ) { 
	$rc=i_writepng($self->{IMG},$fh->fileno());
	if ( !defined($rc) ) { $self->{ERRSTR}='unable to write png image'; return undef; }
	$self->{DEBUG} && print "writing a png file\n";
    } elsif ( $input{type} eq 'ppm' ) { 
	$rc=i_writeppm($self->{IMG},$fh->fileno());
	if ( !defined($rc) ) { $self->{ERRSTR}='unable to write ppm image'; return undef; }
	$self->{DEBUG} && print "writing a ppm file\n";
    } elsif ( $input{type} eq 'raw' ) {
	$rc=i_writeraw($self->{IMG},$fh->fileno());
	if ( !defined($rc) ) { $self->{ERRSTR}='unable to write raw image'; return undef; }
	$self->{DEBUG} && print "writing a raw file\n";
    }
    return 1;
}


sub DESTROY {
    my $self=shift;
    delete $instances{$self};
    if (defined($self->{IMG})) {
	i_img_destroy($self->{IMG});
	undef($self->{IMG});
    } else {
	print "Destroy Called on an empty image!\n";
    }
}

sub filter {
    my $self=shift;
    my %input=@_;
    my %hsh;
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

    return 1;
}

sub min {
    my $mx=shift;
    for(@_) { if ($_<$mx) { $mx=$_; }}
    return $mx;
}


sub max {
    my $mx=shift;
    for(@_) { if ($_>$mx) { $mx=$_; }}
    return $mx;
}

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

sub scaleX {
    my $self=shift;
    my %opts=(scalefactor=>0.5,@_);
    my $img = Imager->new();

    if ($opts{pixels}) { 
	$opts{scalefactor}=$opts{pixels}/$self->getwidth();
    }

    unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
    $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},0);
    
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
}

sub scaleY {
    my $self=shift;
    my %opts=(scalefactor=>0.5,@_);
    my $img = Imager->new();

    if ($opts{pixels}) { $opts{scalefactor}=$opts{pixels}/$self->getheight(); }

    unless ($self->{IMG}) { $self->{ERRSTR}='empty input image'; return undef; }
    $img->{IMG}=i_scaleaxis($self->{IMG},$opts{scalefactor},1);
    
    if ( !defined($img->{IMG}) ) { $self->{ERRSTR}='unable to scale image'; return undef; }
    return $img;
}


sub getwidth {
    my $self=shift;
    if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
    return (i_img_info($self->{IMG}))[0];
}

sub getheight {
    my $self=shift;
    if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
    return (i_img_info($self->{IMG}))[1];
}

sub getmask {
    my $self=shift;
    if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
    return i_img_getmask($self->{IMG});
}

sub setmask {
    my $self=shift;
    my %opts=@_;
    if (!defined($self->{IMG})) { $self->{ERRSTR}='image is empty'; return undef; }
    i_img_setmask( $self->{IMG} , $opts{mask} );
}














sub clean
{
    my($str)=$_[0];
    $str = substr($str,3);
    $str =~ s/[\n\r]//g;
    $str =~ s/\s+/ /g;
    $str =~ s/^\s//;
    $str =~ s/\s$//;
    return $str;
}

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
  $img->open(file=>'image.ppm',type=>'ppm') || print "failed: ",$img->{ERRSTR},"\n";
  $scaled=$img->scale(xpixels=>400,ypixels=>400);
  $scaled->write(file=>'sc_image.ppm',type=>'ppm') || print "failed: ",$scaled->{ERRSTR},"\n";

=head1 DESCRIPTION

    Imager is a module for creating and altering images - It 
    is not meant as a replacement or a competitor to ImageMagick or
    GD. Both are excellent packages and well supported.
    
    Why a new module? Compiling PerlMagick has been more than trivial
    for me, and it lacks drawing functions. GD.pm has those but only
    does gif.  I like studying graphics, so why not let others in
    a similar situation benefit?  The basis for this module is code
    written to preprocess remote sensing data. 


=head2 OO interface

    An Image object is created with $img = Imager->new(). Should this fail
    for some reason an explanation can be found in $Imager::ERRSTR. 
    usually error messages are stored in $img->{ERRSTR}, but since no
    object is created this is the only way to give back errors.  $Imager::ERRSTR
    is also used to report all errors not directly associated with an image object.
    
    An image object is a wrapper around the raw handle to an image.  It is stored in the IMG
    value of the object hash.  When Imager->new() is called the IMG member is set to undef.

    $img->open() has two parameters, 'file' and 'type', for type 'raw' two extra parameters
    are necessary 'xsize' and 'ysize', if the 'channel' parameter is omitted for 'raw' it is
    assumed to be 3.  Gif and png images that have a palette are converted to 24 bit when read.
    Grayscale jpegs are still 1 channel images in memory though.  For jpeg images the iptc header
    information (stored in the APP13 header) is avaliable to some degree. You can get the raw
    header with $img->{IPTCRAW}, but you can also retreive the most basic information with
    %hsh=$img->parseiptc() as always: patches welcome.
    
    $img->write has the same interface as open(), for jpeg quality can be adjusted via the
    'jpegquality' parameter (0-100).  The number of colorplanes in gifs are set with 'gifplanes' and
    should be between 1 (2 color) and 8 (256 colors).

    $img->getwidth() and $img->getheight() are used to get the dimensions of the image.
    $img->getmask() and $img->setmask() are used to get/set the channel mask of the image.
    

    To scale an image so porportions are maintained use the $img->scale() method.
    if you give either a xpixels or ypixels parameter they will determine the width
    or height respectively.  If both are given the one resulting in a larger image is used.
    
  example: 
    $img is 700 pixels wide and 500 pixels tall.
    
    $img->scale(xpixels=>400);                         400x285
    $img->scale(ypixels=>400);                         560x400

    $img->scale(xpixels=>400,ypixels=>400);            560x400
    $img->scale(xpixels=>400,ypixels=>400,type=>min);  400x285

    $img->scale(scalefactor=>0.25);                    175x125
    $img->scale();                                     350x250


    if you want to create low quality previews of images you can pass qtype=>'preview'
    to scale and it will use nearest neighbor sampling instead of filtering. It is much
    faster but also generates worse looking images - especially if the original has
    a lot of sharp variations and the scaled image is by more than 3-5 times smaller than the
    original.

    If you need to scale images per axis it is best to do it simply by calling scaleX and scaleY.
    You can pass either 'scalefactor' or 'pixels' to both functions.

=head2 Plugins

    It is possible to add filters to the module without recompiling the module itself.
    This is done by using DSOs (Dynamic shared object) avaliable on most systems. 
    This way you can maintain our own filters and not have to get me to add it, or worse
    patch every new version of the Module.  Modules can be loaded AND UNLOADED at runtime.
    This means that you can have a server/daemon thingy that can do something like:
    
      load_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
      %hsh=(a=>35,b=>200,type=>lin_stretch);
      $img->filter(%hsh);
      unload_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
      $img->write(type=>'ppm',file=>'testout/t60.jpg') || die "error in write()\n";

  .... someone decides that the filter is not working as it should -
       dyntest.c modified and recompiled ....

      load_plugin("dynfilt/dyntest.so") || die "unable to load plugin\n";
      $img->filter(%hsh);
     
    An example plugin comes with the module - Please send feedback if you test this.

=head1 Functional interface 

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
$chan_mask = i_img_getmask($imref);

             i_draw($imref,$x1,$y1,$x2,$y2,$colref);
             i_box($imref,$x1,$y1,$x2,$y2,$colref);
             i_box_filled($imref,$x1,$y1,$x2,$y2,$colref);
             i_arc($imref,$x,$y,$rad,$deg1,$deg2,$colref);

             i_copyto($imref,$srcref,$x1,$y1,$x2,$y2,$tx,$ty,$trans_cl_ref);
	     i_rubthru($imref,$srcref,$tx,$ty);
   $imref  = i_scaleaxis($imref,$scale_factor,$axis);
 
             i_gaussian($imref,$stdev);
             i_conv($imref,$arrayref,$array_len);

             i_img_diff($imref1,$imref2);


	     i_init_fonts();

	     i_t1_set_aa($level);
	     i_t1_cp($imref,$xb,$yb,$channel,$fontnum,$pts,$str,$strlen,$align);
	     i_t1_text($imref,$xb,$yb,$colorref,$fontnum,$pts,$str,$strlen,$align);
    @bbox  = i_t1_bbox($fontnum,$pts,$str,$strlen);

    $imref = i_readjpeg($imref,$fd);
	     i_writejpeg($imref,$fd,$qfactor);

    $imref = i_readpng($imref,$fd);
	     i_writepng($imref,$fd);

    $imref = i_readgif($imref,$fd);
    	     i_writegif($imref,$fd,$planes);

    $imref = i_readppm($imref,$fd);
	     i_writeppm($imref,$fd);

	     i_readraw($imref,$fd,$xsize,$ysize,$datachannels,$storechannels,$interleave);
	     i_writeraw($imref,$fd);



   

=head1 AUTHOR

Arnar M. Hrafnkelsson, amh@mbl.is

=head1 SEE ALSO

perl(1).
http://gauss.mbl.is/~amh/Imager/

=cut



#<ytf> che_fox ++ for knowing how to spell hara-kiri
#<Che_Fox> ytf: demo nihongo de hatsuon dake shitteru no wa, daijoubu da ne
#<Che_Fox> Irix can suck.
#<Che_Fox> So can anyone get to that URL?
#<ytf> che: ah, so desuka
#<Che_Fox> ytf: un, mochiron sou desu
#<ytf> che: ich habe nur ein bisschen nihongo gelernt.
#<dynweb> Che_Fox: sí, por supuesto.
#<Che_Fox> ytf: wirklich? das ist schade.

#package Just_another_Perl_Hacker; sub print {($_=$_[0])=~ s/_/ /g;
#                                      print } sub __PACKAGE__ { &
#                                      print (     __PACKAGE__)} &
#                                                  __PACKAGE__
#                                            (                )


#<Latinum_> dhtml is like an abortion with no anasthetic
#<Latinum_> it's like having your teeth pulled, but having it done through your ass with a screwdriver
#<Latinum_> in short, it's awful.


#$ isbn for Perl/TK pocket reference: Addi: 1-56592-517-3

#7. How Can I Make Linux More Like Windows?
#Hmmm. Rebuild the kernel to use every memory-hogging feature you can find. Reboot every couple of days whether you need to or not.
#And every 18 months or so, send a check for $99 to Bill Gates. That should do the trick.


