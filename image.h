#ifndef _IMAGE_H_
#define _IMAGE_H_

#include "io.h"
#include "log.h"
#include "stackmach.h"

#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#ifdef SUNOS
#include <strings.h>
#endif

#include "datatypes.h"

#ifndef PI
#define PI 3.14159265358979323846
#endif

#ifndef MAXINT
#define MAXINT 2147483647
#endif


undef_int i_has_format(char *frmt);

/* constructors and destructors */

i_color *i_color_new(unsigned char r,unsigned char g,unsigned char b,unsigned char a);
i_color *i_color_set(i_color *cl,unsigned char r,unsigned char g,unsigned char b,unsigned char a);
void i_color_info(i_color *cl);

i_img *i_img_new();
i_img *i_img_empty(i_img *im,int x,int y);
i_img *i_img_empty_ch(i_img *im,int x,int y,int ch);
void i_img_exorcise(i_img *im);


void i_img_info(i_img *im,int *info);

/* Image feature settings */

void i_img_setmask(i_img *im,int ch_mask);
int i_img_getmask(i_img *im);

/* Base functions */

int i_ppix(i_img *im,int x,int y,i_color *val);
int i_gpix(i_img *im,int x,int y,i_color *val);

int i_ppix_d(i_img *im,int x,int y,i_color *val);
int i_gpix_d(i_img *im,int x,int y,i_color *val);

float i_gpix_pch(i_img *im,int x,int y,int ch);

/* functions for drawing primitives */

void i_box(i_img *im,int x1,int y1,int x2,int y2,i_color *val);
void i_draw(i_img *im,int x1,int y1,int x2,int y2,i_color *val);
void i_line_aa(i_img *im,int x1,int y1,int x2,int y2,i_color *val);
void i_arc(i_img *im,int x,int y,float rad,float d1,float d2,i_color *val);
void i_copyto(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty);
void i_copyto_trans(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty,i_color *trans);
void i_rubthru(i_img *im,i_img *src,int tx,int ty);

void i_bezier_multi(i_img *im,int l,double *x,double *y,i_color *val);

/* image processing functions */

void i_gaussian(i_img *im,float stdev);
void i_conv(i_img *im,float *coeff,int len);

float i_img_diff(i_img *im1,i_img *im2);

/* font routines */



undef_int i_init_fonts();

#ifdef HAVE_LIBT1

void      i_t1_set_aa(int st);
undef_int i_t1_cp(i_img *im,int xb,int yb,int channel,int fontnum,float points,char* str,int len,int align);
undef_int i_t1_text(i_img *im,int xb,int yb,i_color *cl,int fontnum,float points,char* str,int len,int align);
void      i_t1_bbox(int fontnum,float point,char *str,int len,int cords[4]);
#endif

#ifdef HAVE_LIBTT

undef_int i_tt_cp(i_img *im,int xb,int yb,int channel,char* fontname,float points,char* str,int len,int align);
undef_int i_tt_text(i_img *im,int xb,int yb,i_color *cl,char* fontname,float points,char* str,int len,int align);
void i_tt_bbox(char* fontname,float points,char *str,int len,int cords[4]);

#endif







/* functions for reading and writing formats */

#ifdef HAVE_LIBJPEG
i_img* i_readjpeg(i_img *im,int fd,char** iptc_itext,int *tlength);
i_img* i_readjpeg_extra2(i_img *im,int fd,char** iptc_itext);
undef_int i_writejpeg(i_img *im,int fd,int qfactor);
#endif

#ifdef HAVE_LIBPNG
i_img *i_readpng(i_img *im,int fd);
undef_int i_writepng(i_img *im,int fd);
#endif

#ifdef HAVE_LIBGIF
i_img *i_readgif(i_img *im,int fd);
undef_int i_writegif(i_img *im,int fd,int colors,int pixdev,int fixedlen,i_color fixed[]);

void i_qdist(i_img *im);
#endif

i_img *i_readraw(i_img* im,int fd,int x,int y,int datachannels,int storechannels,int intrl);
undef_int i_writeraw(i_img* im,int fd);

i_img *i_readppm(i_img *im,int fd);
undef_int i_writeppm(i_img *im,int fd);


i_img* i_scaleaxis(i_img *im, float Value, int Axis);
i_img* i_scale_nn(i_img *im, float scx, float scy);

i_img* i_transform(i_img *im, int *opx,int opxl,int *opy,int opyl,double parm[],int parmlen);

/* filters */

void i_contrast(i_img *im, float intensity);
void i_hardinvert(i_img *im);
void i_noise(i_img *im, float amount, unsigned char type);
void i_autolevels(i_img *im,float lsat,float usat,float skew);
void i_radnoise(i_img *im,int xo,int yo,float rscale,float ascale);
void i_turbnoise(i_img *im,float xo,float yo,float scale);

/* Debug only functions */

void malloc_state();

typedef struct {
  undef_int (*i_has_format)(char *frmt);
  i_color*(*i_color_set)(i_color *cl,unsigned char r,unsigned char g,unsigned char b,unsigned char a);
  void (*i_color_info)(i_color *cl);

  i_img*(*i_img_new)();
  i_img*(*i_img_empty)(i_img *im,int x,int y);
  i_img*(*i_img_empty_ch)(i_img *im,int x,int y,int ch);
  void(*i_img_exorcise)(i_img *im);

  void(*i_img_info)(i_img *im,int *info);
  
  void(*i_img_setmask)(i_img *im,int ch_mask);
  int(*i_img_getmask)(i_img *im);
  
  int(*i_ppix)(i_img *im,int x,int y,i_color *val);
  int(*i_gpix)(i_img *im,int x,int y,i_color *val);

  void(*i_box)(i_img *im,int x1,int y1,int x2,int y2,i_color *val);
  void(*i_draw)(i_img *im,int x1,int y1,int x2,int y2,i_color *val);
  void(*i_arc)(i_img *im,int x,int y,float rad,float d1,float d2,i_color *val);
  void(*i_copyto)(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty);
  void(*i_copyto_trans)(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty,i_color *trans);
  void(*i_rubthru)(i_img *im,i_img *src,int tx,int ty);

} symbol_table_t;



#endif




