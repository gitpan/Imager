#ifndef _FONT_H_
#define _FONT_H_


#include "image.h"

#ifdef HAVE_LIBT1
#include <t1lib.h>

int init_t1();
void close_t1();
void i_t1_set_aa(int st);
undef_int i_t1_cp(i_img *im,int xb,int yb,int channel,int fontnum,float points,char* str,int len,int align);
void i_t1_bbox(int fontnum,float points,char *str,int len,int cords[4]);
undef_int i_t1_text(i_img *im,int xb,int yb,i_color *cl,int fontnum,float points,char* str,int len,int align);
void close_t1();

#endif

#ifdef HAVE_LIBTT
#include <freetype.h>

#define TT_VALID( handle )  ( ( handle ).z != NULL )

undef_int init_tt();
void i_tt_set_aa(int st);
undef_int i_tt_cp(i_img *im,int xb,int yb,int channel,char* fontname,float points,char* str,int len,int align);
undef_int i_tt_text(i_img *im,int xb,int yb,i_color *cl,char *fontname,float points,char* str,int len,int align);
void i_tt_bbox(char* fontname,float points,char *str,int len,int cords[4]);



void i_tt_init_raster_map( TT_Raster_Map*  bit, int  width, int  height );
void i_tt_done_raster_map( TT_Raster_Map *bit );
void i_tt_clear_raster_map( TT_Raster_Map*  bit );
void i_tt_blit_or( TT_Raster_Map*  dst, TT_Raster_Map*  src,int  x_off, int  y_off );
void i_tt_dump_raster_map( i_img* im, TT_Raster_Map*  bit, int xb, int yb, int channel );
void i_tt_load_glyphs( char*  txt, int  txtlen );
void i_tt_done_glyphs( void );
void i_tt_init_face( const char*  filename );
void i_tt_done_face( void );
void i_tt_init_raster_areas( const char*  txt, int  txtlen );
void i_tt_done_raster_areas( void );
void i_tt_render_glyph( TT_Glyph  glyph,int  x_off, int  y_off,TT_Glyph_Metrics*  gmetrics );
void i_tt_render_all_glyphs( char*  txt, int  txtlen );


#endif



#endif /* _FONT_H_ */




