#ifndef _IMAGE_TYPES_H_
#define _IMAGE_TYPES_H_

#define MAXCHANNELS 4

typedef struct { unsigned char gray_color; } gray_color;
typedef struct { unsigned char r,g,b; } rgb_color;
typedef struct { unsigned char r,g,b,a; } rgba_color;
typedef struct { unsigned char c,m,y,k; } cmyk_color;

typedef int undef_int; /* special value to put in typemaps to retun undef on 0 and 1 on 1 */

typedef union
{
  gray_color gray;
  rgb_color rgb;
  rgba_color rgba;
  cmyk_color cmyk;
  unsigned char channel[MAXCHANNELS];
} i_color;

struct _i_img {
  int channels;
  int xsize,ysize,bytes;
  unsigned char *data;
  unsigned int ch_mask;

  int (*i_f_ppix) (struct _i_img *,int,int,i_color *); 
  int (*i_f_gpix) (struct _i_img *,int,int,i_color *);
  void *ext_data;
};

typedef struct _i_img i_img;

#endif


