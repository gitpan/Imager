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

#ifdef HAVE_LIBTT
  init_tt();
#endif

  return(1);
}



#ifdef HAVE_LIBT1

undef_int
init_t1() {
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
  
  mm_log((1,"width: %d height: %d\n",xsize,ysize));

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
  
  mm_log((1,"i_t1_bbox(fontnum %d,points %.2f,str '%.*s', len %d)\n",fontnum,points,len,str,len));
  T1_LoadFont(fontnum);  /* Here a return code is ignored - fix later  - haw haw haw */ 
  bbox=T1_GetStringBBox(fontnum,str,len,0,T1_KERNING);
  
  mm_log((1,"bbox: (%d,%d,%d,%d)\n",(int)(bbox.llx*points/1000),(int)(bbox.lly*points/1000),(int)(bbox.urx*points/1000),(int)(bbox.ury*points/1000) ));
    
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

  mm_log((1,"metrics:  ascent: %d descent: %d\n",glyph->metrics.ascent,glyph->metrics.descent));
  mm_log((1," leftSideBearing: %d rightSideBearing: %d\n",glyph->metrics.leftSideBearing,glyph->metrics.rightSideBearing));
  mm_log((1," advanceX: %d advanceY: %d\n",glyph->metrics.advanceX,glyph->metrics.advanceY));
  mm_log((1,"bpp: %d\n",glyph->bpp));
  
  xsize=glyph->metrics.rightSideBearing-glyph->metrics.leftSideBearing;
  ysize=glyph->metrics.ascent-glyph->metrics.descent;
  
  mm_log((1,"width: %d height: %d\n",xsize,ysize));

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




#ifdef HAVE_LIBTT

static TT_Engine    engine;
static TT_Face      face;
static TT_Instance  instance;
static TT_Face_Properties  properties;
static TT_Raster_Map  bit;
static TT_Raster_Map  small_bit;   /* used when font-smoothing is enabled */
static TT_Glyph  *glyphs = NULL;

static int  LTT_pnm_width,LTT_pnm_height;
static int  LTT_pnm_x_shift,LTT_pnm_y_shift;
/* static int  LTT_dpi    = 96; */
static int  LTT_dpi    = 72;
static int  LTT_ptsize = 12;
static int  LTT_hinted = 1;
static int  LTT_smooth = 1;
static int  LTT_border = 0;
static int  LTT_Ascent;
static int  LTT_Descent;



undef_int
init_tt() {
  TT_Error  error;
  
  mm_log((1,"init_tt()\n"));
  
  error = TT_Init_FreeType( &engine );
  if ( error ){
    mm_log((1,"Initialization of ttlib failed, code = 0x%x\n",error));
    return(1);
  }

  
  /* i_tt_set_aa(0); Do something equiv here */
  return(0);
}
  










/* raster map management */

void
i_tt_init_raster_map( TT_Raster_Map*  bit, int  width, int  height ) {
  bit->rows  = height;
  bit->width = ( width + 3 ) & -4;
  bit->flow  = TT_Flow_Down;
  
  if ( LTT_smooth ) {
    bit->cols  = bit->width;
    bit->size  = bit->rows * bit->width;
  } else {
    bit->cols  = ( bit->width + 7 ) / 8;    /* convert to # of bytes     */
    bit->size  = bit->rows * bit->cols;     /* number of bytes in buffer */
  }
  
  bit->bitmap = (void *) malloc( bit->size );
  if ( !bit->bitmap ) m_fatal(0,"Not enough memory to allocate bitmap!\n" );
}


void
i_tt_done_raster_map( TT_Raster_Map *bit ) {
  free( bit->bitmap );
  bit->bitmap = NULL;
}


void
i_tt_clear_raster_map( TT_Raster_Map*  bit ) {
  memset( bit->bitmap, 0, bit->size );
}


void
i_tt_blit_or( TT_Raster_Map *dst, TT_Raster_Map *src,int x_off, int y_off ) {
  int   x, y;
  int   x1, x2, y1, y2;
  char  *s, *d;
  
  /* clipping */
  
  x1 = x_off < 0 ? -x_off : 0;
  y1 = y_off < 0 ? -y_off : 0;
  
  x2 = (int)dst->cols - x_off;
  if ( x2 > src->cols ) x2 = src->cols;
  
  y2 = (int)dst->rows - y_off;
  if ( y2 > src->rows ) y2 = src->rows;

  if ( x1 >= x2 ) return;

  /* do the real work now */

  for ( y = y1; y < y2; ++y ) {
    s = ( (char*)src->bitmap ) + y * src->cols + x1;
    d = ( (char*)dst->bitmap ) + ( y + y_off ) * dst->cols + x1 + x_off;
    
    for ( x = x1; x < x2; ++x ) *d++ |= *s++;
  }
}


/* glyph management */

void
i_tt_load_glyphs( char*  txt, int  txtlen ) {
  unsigned short  i, n, code, load_flags;
  unsigned short  num_glyphs = 0, no_cmap = 0;
  unsigned short  platform, encoding;
  TT_Error        error;
  TT_CharMap      char_map;

  mm_log((1,"i_tt_load_glyphs( txt '%.*s', len %d )\n",txtlen, txt, txtlen));
  
  /* First, look for a Unicode charmap */
  
  n = properties.num_CharMaps;
  
  for ( i = 0; i < n; i++ ) {
    TT_Get_CharMap_ID( face, i, &platform, &encoding );
    if ( (platform == 3 && encoding == 1 ) || (platform == 0 && encoding == 0 ) ) {
      TT_Get_CharMap( face, i, &char_map );
      break;
    }
  }
  
  if ( i == n ) {
    TT_Face_Properties  properties;
    TT_Get_Face_Properties( face, &properties );
    no_cmap = 1;
    num_glyphs = properties.num_Glyphs;
  }
  
  /* Second, allocate the array */
  
  glyphs = (TT_Glyph*)malloc( 256 * sizeof ( TT_Glyph ) );
  memset( glyphs, 0, 256 * sizeof ( TT_Glyph ) );

  /* Finally, load the glyphs you need */
  
  load_flags = TTLOAD_SCALE_GLYPH;
  if ( LTT_hinted ) load_flags |= TTLOAD_HINT_GLYPH;
  
  for ( i = 0; i < txtlen; ++i ) {
    unsigned char  j = txt[i];
    
    if ( TT_VALID( glyphs[j] ) ) continue;
    
    if ( no_cmap ) {
      code = (j - ' ' + 1) < 0 ? 0 : (j - ' ' + 1);
      if ( code >= num_glyphs ) code = 0;
    }
    else code = TT_Char_Index( char_map, j );


    /*    
    (void)(
	   ( error = TT_New_Glyph( face, &glyphs[j] ) ) ||
	   ( error = TT_Load_Glyph( instance, glyphs[j], code, load_flags ) )
	   );
    if ( error ) m_fatal(0, "Cannot allocate and load glyph: error 0x%x.\n", error );
    */

  
  

    if ( error = TT_New_Glyph( face, &glyphs[j] ) )
      m_fatal(0, "Cannot allocate and load glyph: error 0x%x.\n", error );
    if ( error = TT_Load_Glyph( instance, glyphs[j], code, load_flags ) )
      m_fatal(0, "Cannot allocate and load glyph: error 0x%x.\n", error );

  }
}


void
i_tt_done_glyphs( void ) {
  int  i;

  if ( !glyphs ) return;

  for ( i = 0; i < 256; ++i ) TT_Done_Glyph( glyphs[i] );
  free( glyphs );
  
  glyphs = NULL;
}


/* face & instance management */

void
i_tt_init_face( const char *filename ) {
  TT_Error  error;

  mm_log((1,"i_tt_init_face( filename, '%s' )\n",filename));

  /* load the typeface */

  error = TT_Open_Face( engine, filename, &face );
  if ( error ) {
    if ( error == TT_Err_Could_Not_Open_File ) m_fatal (0, "Could not find/open %s.\n", filename );
    else m_fatal(0, "Error while opening %s, error code = 0x%x.\n",filename, error );
  }
  
  TT_Get_Face_Properties( face, &properties );
  
  /* create and initialize instance */
  
  (void) (( error = TT_New_Instance( face, &instance ) ) || 
	  ( error = TT_Set_Instance_Resolutions( instance, LTT_dpi, LTT_dpi ) ) ||
	  ( error = TT_Set_Instance_CharSize( instance, LTT_ptsize*64 ) ) );
  
  if ( error ) m_fatal(0, "Could not create and initialize instance: error 0x%x.\n",error );
}


void
i_tt_done_face() {
  TT_Done_Instance( instance );
  TT_Close_Face( face );
}


/* rasterization stuff */

void
i_tt_init_raster_areas( const char *txt, int txtlen ) {
  int                  i, upm, ascent, descent;
  TT_Face_Properties   properties;
  TT_Instance_Metrics  imetrics;
  TT_Glyph_Metrics     gmetrics;

  mm_log((1,"i_tt_init_raster_areas(txt '%s',txtlen %d)\n",txt,txtlen));
  
  /* allocate the large bitmap */
  
  TT_Get_Face_Properties( face, &properties );
  TT_Get_Instance_Metrics( instance, &imetrics );
  
  upm     = properties.header->Units_Per_EM;
  ascent  = ( properties.horizontal->Ascender  * imetrics.y_ppem ) / upm;
  descent = ( properties.horizontal->Descender * imetrics.y_ppem ) / upm;

  LTT_Ascent=ascent;
  LTT_Descent=descent;
  
  LTT_pnm_width   = 2 * LTT_border;
  LTT_pnm_height  = 2 * LTT_border + ascent - descent;
  
  for ( i = 0; i < txtlen; ++i ) {
    unsigned char  j = txt[i];
    if ( !TT_VALID( glyphs[j] ) ) continue;

    TT_Get_Glyph_Metrics( glyphs[j], &gmetrics );
    LTT_pnm_width += gmetrics.advance / 64;
  }
  
  i_tt_init_raster_map( &bit, LTT_pnm_width, LTT_pnm_height );
  i_tt_clear_raster_map( &bit );
  
  LTT_pnm_x_shift = LTT_border;
  LTT_pnm_y_shift = LTT_border - descent;
  
  /* allocate the small bitmap if you need it */

  if ( LTT_smooth ) i_tt_init_raster_map( &small_bit, imetrics.x_ppem + 32, LTT_pnm_height );
}


void 
i_tt_done_raster_areas( void ) {
  i_tt_done_raster_map( &bit );
  if ( LTT_smooth ) i_tt_done_raster_map( &small_bit );
}


void
i_tt_render_glyph( TT_Glyph glyph,int x_off, int y_off,TT_Glyph_Metrics* gmetrics ) {
  if ( !LTT_smooth ) TT_Get_Glyph_Bitmap( glyph, &bit, x_off * 64, y_off * 64);
  else {
    TT_F26Dot6 xmin, ymin, xmax, ymax;

    mm_log((1,"i_tt_render_glyph(glyph 0x0%X, x_off %d, y_off %d, gmetrics 0x0%X)\n",glyph,x_off,y_off,gmetrics));    
    /* grid-fit the bounding box */

    xmin =  gmetrics->bbox.xMin & -64;
    ymin =  gmetrics->bbox.yMin & -64;
    xmax = (gmetrics->bbox.xMax + 63) & -64;
    ymax = (gmetrics->bbox.yMax + 63) & -64;
    
    /* now render the glyph in the small pixmap */
    /* and blit-or the resulting small pixmap into the biggest one */
    
    i_tt_clear_raster_map( &small_bit );
    TT_Get_Glyph_Pixmap( glyph, &small_bit, -xmin, -ymin );
    i_tt_blit_or( &bit, &small_bit, xmin/64 + x_off, -ymin/64 - y_off );
  }
}

void
i_tt_render_all_glyphs( char* txt, int txtlen ) {
  int               i;
  TT_F26Dot6        x, y, adjx;
  TT_Glyph_Metrics  gmetrics;

  
  mm_log((1,"i_tt_render_all_glyphs( txt '%.*s', len %d)\n",txtlen,txt,txtlen));

  x = LTT_pnm_x_shift;
  y = LTT_pnm_y_shift;
  
  for ( i = 0; i < txtlen; i++ ) {
    unsigned char  j = txt[i];

    if ( !TT_VALID( glyphs[j] ) ) continue;

    TT_Get_Glyph_Metrics( glyphs[j], &gmetrics );

    adjx = x;                                         /* ??? lsb */
    i_tt_render_glyph( glyphs[j], adjx, y, &gmetrics );
    
    x += gmetrics.advance / 64;
  }

}

void
i_tt_dump_raster_map( i_img* im, TT_Raster_Map*  bit, int xb, int yb, int channel ) {
  char *bmap;
  char ucval;
  i_color val;
  int    i,x,y,ex,ey;
  FILE *test;

  unsigned int ch_mask_store;
  ch_mask_store=im->ch_mask;
  im->ch_mask=1<<channel;
  
  for(i=0;i<im->channels;i++) val.channel[i]=0;
  
  bmap = (char *)bit->bitmap;

  for(x=0;x<bit->width;x++) for(y=0;y<bit->rows;y++) {
    ucval=bmap[y*(bit->cols)+x];
    val.channel[channel]=(255*ucval)/4;
    i_ppix(im,x+xb,y+yb-LTT_Ascent,&val);
  }

  im->ch_mask=ch_mask_store;
  
  /*   test=fopen("test.ppm","w+");
  if ( LTT_smooth ) {
    fprintf( test, "P5\n%d %d\n4\n", LTT_pnm_width, LTT_pnm_height );
    for ( i = bit->size - 1; i >= 0; --i ) bmap[i] = bmap[i] > 4 ? 0 : 4 - bmap[i];
    for ( i = LTT_pnm_height; i > 0; --i, bmap += bit->cols ) fwrite( bmap, 1, LTT_pnm_width, test );
  } else {
    fprintf( test, "P4\n%d %d\n", LTT_pnm_width, LTT_pnm_height );
    for ( i = LTT_pnm_height; i > 0; --i, bmap += bit->cols ) fwrite( bmap, 1, (LTT_pnm_width+7) / 8, test );
  }
  fclose(test);
  */
}

void
i_tt_dump_raster_map2( i_img* im, TT_Raster_Map*  bit, int xb, int yb, i_color *cl ) {
  char *bmap;
  char ucval;
  i_color val;
  int    c,i,ch,x,y,ex,ey;
  FILE *test;

  bmap = (char *)bit->bitmap;

  for(x=0;x<bit->width;x++) for(y=0;y<bit->rows;y++) {
    c=(255*bmap[y*(bit->cols)+x])/4;
    i=255-c;
    i_gpix(im,x+xb,y+yb-LTT_Ascent,&val);
    for(ch=0;ch<im->channels;ch++) val.channel[ch]=(c*cl->channel[ch]+i*val.channel[ch])/255;
    i_ppix(im,x+xb,y+yb-LTT_Ascent,&val);
  }
  
}



undef_int
i_tt_cp(i_img *im,int xb,int yb,int channel,char *fontname,float points,char* str,int len,int align) {
  mm_log((1,"i_tt_cp(im 0x%x,xb %d,yb %d,channel %d, fontname %s,points %.2f,len %d,align %d)\n",im,xb,yb,channel,fontname,points,len,align));

  if (im == NULL) { mm_log((1,"i_tt_cp: Null image in input\n")); return(0); }

  LTT_ptsize = points;

  i_tt_init_face( fontname ); 
  i_tt_load_glyphs( str, len );
  i_tt_init_raster_areas( str, len );
  i_tt_render_all_glyphs( str, len );

  i_tt_dump_raster_map( im, &bit, xb, yb ,channel);

  i_tt_done_raster_areas();
  i_tt_done_glyphs();
  i_tt_done_face();
  return 0;
}

undef_int
i_tt_text(i_img *im,int xb,int yb,i_color *cl,char *fontname,float points,char* str,int len,int align) {
  mm_log((1,"i_tt_text(im 0x%x,xb %d,yb %d,cl 0x%X, fontname %s,points %.2f,len %d,align %d)\n",im,xb,yb,cl,fontname,points,len,align));

  if (im == NULL) { mm_log((1,"i_tt_text: Null image in input\n")); return(0); }

  LTT_ptsize = points;

  i_tt_init_face( fontname ); 
  i_tt_load_glyphs( str, len );
  i_tt_init_raster_areas( str, len );
  i_tt_render_all_glyphs( str, len );

  i_tt_dump_raster_map2( im, &bit, xb, yb, cl);

  i_tt_done_raster_areas();
  i_tt_done_glyphs();
  i_tt_done_face();
  return 0;
}



void
i_tt_bbox(char* fontname,float points,char *str,int len,int cords[4]) {
  int                  i, upm, ascent, descent,width;
  TT_Face_Properties   properties;
  TT_Instance_Metrics  imetrics;
  TT_Glyph_Metrics     gmetrics;
  
  mm_log((1,"i_tt_box(fontname '%s',points %f,str '%.*s', len %d)\n",fontname,points,len,str,len));

  LTT_ptsize = points;
  
  i_tt_init_face( fontname ); 
  i_tt_load_glyphs( str, len );

  TT_Get_Face_Properties( face, &properties );
  TT_Get_Instance_Metrics( instance, &imetrics );
  
  upm     = properties.header->Units_Per_EM;
  ascent  = ( properties.horizontal->Ascender  * imetrics.y_ppem ) / upm;
  descent = ( properties.horizontal->Descender * imetrics.y_ppem ) / upm;
  
  width  = 0;
  
  for ( i = 0; i < len; ++i ) {
    unsigned char  j = str[i];
    if ( !TT_VALID( glyphs[j] ) ) continue;
    
    TT_Get_Glyph_Metrics( glyphs[j], &gmetrics );
    width += gmetrics.advance / 64;
  }
  
  cords[0]=0;
  cords[1]=descent;
  cords[2]=width;
  cords[3]=ascent;
}



void
i_tt_set_aa(int st) {
  LTT_smooth=st;
}


#endif

