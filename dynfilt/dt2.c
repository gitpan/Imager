#include "pluginst.h"


char evalstr[]="Description string of plugin dyntest - kind of like";
void null_plug(void *ptr) { }



/* Example dynamic filter - level stretch (linear) - note it only stretches and doesn't compress */

/* input parameters
   a: the current black
   b: the current white
   
   0 <= a < b <= 255;

   output pixel value calculated by: o=((i-a)*255)/(b-a);

   note that since we do not have the needed functions to manipulate the data structures *** YET ***
*/


unsigned char saturate(int in) {
  if (in>255) { return 255; }
  else if (in>0) return in;
  return 0;
}

void lin_stretch(void *INP) {

  int a, b;
  i_img *im;
  i_color rcolor;
  int i,bytes,x,y;
  int info[4];


  if ( !getVOID("image",&im) ) { fprintf(stderr,"Error: image is missing\n"); }
  if ( !getINT("a",&a) ) { fprintf(stderr,"Error: a is missing\n"); }
  if ( !getINT("b",&b) ) { fprintf(stderr,"Error: b is missing\n"); }
  
  /*  printf("parameters: (im 0x%x,a %d,b %d)\n",im,a,b); */
  bytes=im->bytes;

  /*  i_img_info(im,info); */
  /*  for(i=0;i<4;i++) { printf("%d: %d\n",i,info[i]); } */
  /*  printf("image info:\n size (%d,%d)\n channels (%d)\n channel mask (%d)\n bytes (%d)\n",im->xsize,im->ysize,im->channels,im->ch_mask,im->bytes); */

  for(y=0;y<im->ysize;y++) for(x=0;x<im->xsize;x++) {
    i_gpix(im,x,y,&rcolor);
    for(i=0;i<im->channels;i++) rcolor.channel[i]=saturate((255*(rcolor.channel[i]-a))/(b-a));    
    i_ppix(im,x,y,&rcolor);
  }

}

func_ptr function_list[]={
  {
    "null_plug",
    null_plug,
    "callsub => sub { 1; }"
  },{
    "lin_stretch",
    lin_stretch,
    "callseq => ['image','a','b'], \
    callsub => sub { my %hsh=@_; DSO_call($DSO_handle,1,\\%hsh); } \
    "
  },
  {NULL,NULL,NULL}};


/* Remember to double backslash backslashes within Double quotes in C */
