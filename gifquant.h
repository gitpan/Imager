#ifndef _GIFQUANT_H_
#define _GIFQUANT_H_
#include <gif_lib.h>
#include "image.h"
#include <math.h>

#define PWR2(x) ((x)*(x))

typedef int (*cmpfunc)(const void*, const void*);

typedef struct {
  unsigned char r,g,b;
  char state;
  int dr,dg,db;
  int cdist;
  int mcount;
} cvec;

typedef struct {
  int cnt;
  int vec[256];
} hashbox;

typedef struct {
  int boxnum;
  int pixcnt;
  int cand;
  int pdc;
} pbox;





void prescan(i_img *im,int cnum,cvec clr[256]);
void reorder(pbox prescan[512]);
void boxrand(int box,cvec *cv);
void boxcenter(int box,cvec *cv);
int pboxcmp(const pbox *a,const pbox *b);
cvec ecvec();
unsigned char g_sat(int in);
float frand();
float frandn();
int nrand();
int eucl_d(cvec* cv,i_color *cl);
void cr_hashindex(cvec clr[256],int cnum,hashbox hb[512]);
void gifquant(i_img *im,int *ColorMapSize,GifByteType *OutputBuffer,GifColorType *Colors,int pixdev,int fixedlen,i_color fixed[]);
void bbox(int box,int *r0,int *r1,int *g0,int *g1,int *b0,int *b1); 

#endif /* _GIFQUANT_H_ */
