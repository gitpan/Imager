#include "font.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <stdio.h>
#include <stdlib.h>


undef_int
i_init_fonts() {
  mm_log((1,"Initializing fonts\n"));
  
#ifdef HAVE_LIBT1
  init_t1();
#endif

  return(1);
}


#ifdef HAVE_LIBT1

undef_int
init_t1() {
  /*  putenv( "T1LIB_CONFIG=fonts/t1/t1lib.config"); */
  mm_log((1,"init_t1()\n"));
  if ((T1_InitLib(LOGFILE)==NULL)){
    mm_log((1,"Initialization of t1lib failed\n"));
    return(1);
  }
  i_t1_set_aa(0);
  return(0);
}


/* States are:
   0 NO   AA
   1 LOW  AA
   2 HIGH AA
*/

void
i_t1_set_aa(int st) {
  int i;
  long cst[17];
  switch(st) {
  case 0:
    T1_AASetBitsPerPixel(8);
    T1_AASetLevel(T1_AA_NONE);
    T1_AANSetGrayValues(0,255);
    mm_log((1,"setting antialias to none\n"));
    break;
  case 1:
    T1_AASetBitsPerPixel(8);
    T1_AASetLevel(T1_AA_LOW);
    T1_AASetGrayValues( 0,65,127,191,255);
    mm_log((1,"setting antialias to low\n"));
    break;
  case 2:
    T1_AASetBitsPerPixel(8);
    T1_AASetLevel(T1_AA_HIGH);
    for(i=0;i<17;i++) cst[i]=(i*255)/16;
    T1_AAHSetGrayValues( cst );
    mm_log((1,"setting antialias to high\n"));
  }
}


/* 
   align:
   0 - top of font glyph
   1 - baseline
*/


undef_int
i_t1_cp(i_img *im,int xb,int yb,int channel,int fontnum,float points,char* str,int len,int align) {
  GLYPH *glyph;
  int xsize,ysize,x,y;
  i_color val;

  unsigned int ch_mask_store;
  
  if (im == NULL) { mm_log((1,"i_t1_cp: Null image in input\n")); return(0); }

  glyph=T1_AASetString( fontnum, str, len, 0, T1_KERNING, points, NULL);

  mm_log((1,"metrics: ascent: %d descent: %d\n",glyph->metrics.ascent,glyph->metrics.descent));
  mm_log((1," leftSideBearing: %d rightSideBearing: %d\n",glyph->metrics.leftSideBearing,glyph->metrics.rightSideBearing));
  mm_log((1," advanceX: %d  advanceY: %d\n",glyph->metrics.advanceX,glyph->metrics.advanceY));
  mm_log((1,"bpp: %d\n",glyph->bpp));
  
  xsize=glyph->metrics.rightSideBearing-glyph->metrics.leftSideBearing;
  ysize=glyph->metrics.ascent-glyph->metrics.descent;
  
  mm_log((1,"width: %d\nheight: %d\n",xsize,ysize));

  ch_mask_store=im->ch_mask;
  im->ch_mask=1<<channel;

  if (align==1) { xb+=glyph->metrics.leftSideBearing; yb-=glyph->metrics.ascent; }
  
  for(y=0;y<ysize;y++) for(x=0;x<xsize;x++) {
    val.channel[channel]=glyph->bits[y*xsize+x];
    i_ppix(im,x+xb,y+yb,&val);
  }
  
  im->ch_mask=ch_mask_store;
}


void
i_t1_bbox(int fontnum,float points,char *str,int len,int cords[4]) {
  BBox bbox;
  
  bbox=T1_GetStringBBox(fontnum,str,len,0,T1_KERNING);

  cords[0]=((float)bbox.llx*points)/1000;
  cords[1]=((float)bbox.lly*points)/1000;
  cords[2]=((float)bbox.urx*points)/1000;
  cords[3]=((float)bbox.ury*points)/1000;

}


undef_int
i_t1_text(i_img *im,int xb,int yb,i_color *cl,int fontnum,float points,char* str,int len,int align) {
  GLYPH *glyph;
  int xsize,ysize,x,y,ch;
  i_color val;
  unsigned char c,i;

  if (im == NULL) { mm_log((1,"i_t1_cp: Null image in input\n")); return(0); }

  glyph=T1_AASetString( fontnum, str, len, 0, T1_KERNING, points, NULL);

  mm_log((1,"metrics:\n ascent: %d\n descent: %d\n",glyph->metrics.ascent,glyph->metrics.descent));
  mm_log((1," leftSideBearing: %d\n rightSideBearing: %d\n",glyph->metrics.leftSideBearing,glyph->metrics.rightSideBearing));
  mm_log((1," advanceX: %d\n advanceY: %d\n",glyph->metrics.advanceX,glyph->metrics.advanceY));
  mm_log((1,"bpp: %d\n",glyph->bpp));
  
  xsize=glyph->metrics.rightSideBearing-glyph->metrics.leftSideBearing;
  ysize=glyph->metrics.ascent-glyph->metrics.descent;
  
  mm_log((1,"width: %d\nheight: %d\n",xsize,ysize));

  if (align==1) { xb+=glyph->metrics.leftSideBearing; yb-=glyph->metrics.ascent; }
  
  for(y=0;y<ysize;y++) for(x=0;x<xsize;x++) {
    c=glyph->bits[y*xsize+x];
    i=255-c;
    i_gpix(im,x+xb,y+yb,&val);
    for(ch=0;ch<im->channels;ch++) val.channel[ch]=(c*cl->channel[ch]+i*val.channel[ch])/255;
    i_ppix(im,x+xb,y+yb,&val);
  }
}


void
close_t1() {
  T1_CloseLib();
}

#endif


