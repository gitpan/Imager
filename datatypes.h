#ifndef _DATATYPES_H_
#define _DATATYPES_H_

#include "io.h"

#define MAXCHANNELS 4

typedef struct { unsigned char gray_color; } gray_color;
typedef struct { unsigned char r,g,b; } rgb_color;
typedef struct { unsigned char r,g,b,a; } rgba_color;
typedef struct { unsigned char c,m,y,k; } cmyk_color;

typedef int undef_int; /* special value to put in typemaps to retun undef on 0 and 1 on 1 */

typedef union {
  gray_color gray;
  rgb_color rgb;
  rgba_color rgba;
  cmyk_color cmyk;
  unsigned char channel[MAXCHANNELS];
  unsigned int ui;
} i_color;

/* This thing is shamelessly stolen from the libtiff tiff.h file. */

#ifndef _TIFF_DATA_TYPEDEFS_
#define _TIFF_DATA_TYPEDEFS_

#ifdef __STDC__
typedef signed char int8;       /* NB: non-ANSI compilers may not grok */
#else
typedef char int8;
#endif
typedef unsigned char uint8;
typedef short int16;
typedef unsigned short uint16;  /* sizeof (uint16) must == 2 */
#if defined(__alpha) || (defined(_MIPS_SZLONG) && _MIPS_SZLONG == 64)
typedef int int32;
typedef unsigned int uint32;    /* sizeof (uint32) must == 4 */
#else
typedef long int32;
typedef unsigned long uint32;   /* sizeof (uint32) must == 4 */
#endif
#endif /* _TIFF_DATA_TYPEDEFS_ */



typedef struct {
  char	  *name;
  int type;
  union { 
    int8 i8;
    int16 i16;
    int32 i32;
    uint8 u8;
    uint16 u16;
    uint32 u32;
  } value;
} taginfo;
 

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

/* used for palette indices in some internal code (which might be 
   exposed at some point
*/
typedef unsigned char i_palidx;

/* Helper datatypes
  The types in here so far are:

  doubly linked bucket list - pretty efficient
  octtree - no idea about goodness
  
  needed: hashes.

*/












/* bitmap mask */

struct i_bitmap {
  int xsize,ysize;
  char *data;
};

struct i_bitmap* btm_new(int xsize,int ysize);
void btm_destroy(struct i_bitmap *btm);
int btm_test(struct i_bitmap *btm,int x,int y);
void btm_set(struct i_bitmap *btm,int x,int y);








/* Stack/Linked list */

struct llink {
  struct llink *p,*n;
  void *data;
  int fill;		/* Number used in this link */
};

struct llist {
  struct llink *h,*t;
  int multip;		/* # of copies in a single chain  */
  int ssize;		/* size of each small element     */
  int count;           /* number of elements on the list */
};


/* Links */

struct llink *llink_new( struct llink* p,int size );
int  llist_llink_push( struct llist *lst, struct llink *lnk, void *data );

/* Lists */

struct llist *llist_new( int multip, int ssize );
void llist_destroy( struct llist *l );
void llist_push( struct llist *l, void *data );
void llist_dump( struct llist *l );
int llist_pop( struct llist *l,void *data );




/* Octtree */

struct octt {
  struct octt *t[8]; 
  int cnt;
};

struct octt *octt_new();
int octt_add(struct octt *ct,unsigned char r,unsigned char g,unsigned char b);
void octt_dump(struct octt *ct);
void octt_count(struct octt *ct,int *tot,int max,int *overflow);
void octt_delete(struct octt *ct);

#endif

