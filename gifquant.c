#include "gifquant.h"
#include "gif_lib.h"

/* 

This quantization algorithm and implementation routines are by Arnar
M. Hrafnkelson. In case any new ideas are here they are mine since
this was written from scratch.

The algorithm uses local means in the following way:

   For each point in the colormap we find which image points
   have that point as it's closest point. We calculate the mean
   of those points and in the next iteration it will be the new
   entry in the colormap.
   
In order to speed this process up (i.e. nearest neighbor problem) We
divied the r,g,b space up in equally large 512 boxes.  The boxes are
numbered from 0 to 511. Their numbering is so that for a given vector
it is known that it belongs to the box who is formed by concatenating the
3 most significant bits from each component of the RGB triplet.

For each box we find the list of points from the colormap who might be
closest to any given point within the box.  The exact solution
involves finding the Voronoi map (or the dual the Delauny
triangulation) and has many issues including numerical stability.

So we use this approximation:

1. Find which point has the shortest maximum distance to the box.
2. Find all points that have a shorter minimum distance than that to the box

This is a very simple task and is not computationally heavy if one
takes into account that the minimum distances from a pixel to a box is
always found by checking if it's inside the box or is closest to some
side or a corner. Finding the maximum distance is also either a side
or a corner.

This approach results 2-3 times more than the actual points needed but
is still a good gain over the complete space.  Usually when one has a
256 Colorcolor map a search over 30 is often obtained.

A bit of an enhancement to this approach is to keep a seperate list
for each side of the cube, but this will require even more memory. 

             Arnar M. Hrafnkelsson (addi@umich.edu);

*/

/*void gifquant(i_img *im,int *ColorMapSize,GifByteType *OutputBuffer,GifColorType *Colors) { */


void
gifquant(i_img *im,int *ColorMapSize,GifByteType *OutputBuffer,GifColorType *Colors,int pixdev,int fixedlen,i_color fixed[]) {
  int cnum,i,k,x,y,ld,cd,bst_idx,iter,bx,currhb;
  i_color val;
  float sqdist,dlt,accerr;
  cvec clr[256];
  hashbox hb[512];

  mm_log((1,"gifquant(0x%x, ColorMapSize 0x%X, OutputBuffer 0x%X, Colors 0x%X, pixdev %d, fixedlen %d, fixed 0x%X)\n",im,ColorMapSize,OutputBuffer,Colors,pixdev,fixedlen,fixed));
  
  for(i=0;i<fixedlen;i++) {
    clr[i].r=fixed[i].rgb.r;
    clr[i].g=fixed[i].rgb.g;
    clr[i].b=fixed[i].rgb.b;
    clr[i].state=1;
    /*     printf("[%d] (%d,%d,%d)\n",i,fixed[i].rgb.r,fixed[i].rgb.g,fixed[i].rgb.b);  */
  }
  
  cnum=*ColorMapSize;
  dlt=1;
  
  prescan(im,cnum,clr);
  cr_hashindex(clr,cnum,hb);
  
  /*   for(i=0;i<cnum;i++) printf("[%d] (%d,%d,%d)\n",i,clr[i].r,clr[i].g,clr[i].b); */

  /* loop on data and inner on vectors */
  
  for(iter=0;iter<3;iter++) {
    accerr=0.0;
    for(y=0;y<im->ysize;y++) for(x=0;x<im->xsize;x++) {
      ld=196608;
      i_gpix(im,x,y,&val);
      currhb=pixbox(&val);
      /*      printf("box = %d \n",currhb); */
      for(i=0;i<hb[currhb].cnt;i++) { 
	/*	printf("comparing: pix (%d,%d,%d) vec (%d,%d,%d)\n",val.channel[0],val.channel[1],val.channel[2],clr[hb[currhb].vec[i]].r,clr[hb[currhb].vec[i]].g,clr[hb[currhb].vec[i]].b); */
	
	cd=eucl_d(&clr[hb[currhb].vec[i]],&val);
	if (cd<ld) {
	  ld=cd;     /* shortest distance yet */
	  bst_idx=hb[currhb].vec[i]; /* index of closest vector  yet */
	}
      }
      
      clr[bst_idx].mcount++;
      accerr+=(ld);
      clr[bst_idx].dr+=val.channel[0];
      clr[bst_idx].dg+=val.channel[1];
      clr[bst_idx].db+=val.channel[2];
    CNT:
      0; /* this is here just to please pedantic compilers like suns */
    }
    for(i=0;i<cnum;i++) if (clr[i].mcount) { clr[i].dr/=clr[i].mcount; clr[i].dg/=clr[i].mcount; clr[i].db/=clr[i].mcount; }

    /*    for(i=0;i<cnum;i++) printf("vec(%d)=(%d,%d,%d) dest=(%d,%d,%d) matchcount=%d\n",
	  i,clr[i].r,clr[i].g,clr[i].b,clr[i].dr,clr[i].dg,clr[i].db,clr[i].mcount); */

    /*    printf("total error: %.2f\n",sqrt(accerr)); */

    for(i=0;i<cnum;i++) {
      if (clr[i].state) continue; /* skip reserved colors */

      if (clr[i].mcount) {
	clr[i].r=clr[i].r*(1-dlt)+dlt*clr[i].dr;
	clr[i].g=clr[i].g*(1-dlt)+dlt*clr[i].dg;
	clr[i].b=clr[i].b*(1-dlt)+dlt*clr[i].db;
      } else {
	clr[i].r=rand();
	clr[i].g=rand();
	clr[i].b=rand();
      }

      clr[i].dr=0;
      clr[i].dg=0;
      clr[i].db=0;
      clr[i].mcount=0;
    }
    cr_hashindex(clr,cnum,hb);
  }





#ifdef NOTEF
  for(i=0;i<cnum;i++) { 
    cd=eucl_d(&clr[i],&val);
    if (cd<ld) {
      ld=cd;
      bst_idx=i;
    }
  }
#endif


  /* Here we quantize the image */
  
  if (pixdev) {
    k=0;
    for(y=0;y<im->ysize;y++) for(x=0;x<im->xsize;x++) {
      ld=196608;
      i_gpix(im,x,y,&val);
      val.channel[0]=g_sat(val.channel[0]+(int)(pixdev*frandn()));
      val.channel[1]=g_sat(val.channel[1]+(int)(pixdev*frandn()));
      val.channel[2]=g_sat(val.channel[2]+(int)(pixdev*frandn()));
      
      currhb=pixbox(&val);
      for(i=0;i<hb[currhb].cnt;i++) { 
	cd=eucl_d(&clr[hb[currhb].vec[i]],&val);
	if (cd<ld) {
	  ld=cd;
	  bst_idx=hb[currhb].vec[i];
	}
      }
      OutputBuffer[k++]=bst_idx;
    }
  } else {
    k=0;
    for(y=0;y<im->ysize;y++) for(x=0;x<im->xsize;x++) {
      ld=196608;
      i_gpix(im,x,y,&val);
      
      currhb=pixbox(&val);
      for(i=0;i<hb[currhb].cnt;i++) { 
	cd=eucl_d(&clr[hb[currhb].vec[i]],&val);
	if (cd<ld) {
	  ld=cd;
	  bst_idx=hb[currhb].vec[i];
	}
      }
      
      OutputBuffer[k++]=bst_idx;
    }
  }
  
  /* Update the gif colormap */

  for(i=0;i<cnum;i++) {
    Colors[i].Red=clr[i].r;
    Colors[i].Green=clr[i].g;
    Colors[i].Blue=clr[i].b;
  }
  
}

/* Prescan finds the boxes in the image that have the highest number of colors 
   and that result is used as the initial value for the vectores */


void prescan(i_img *im,int cnum, cvec clr[256]) {
  int i,k,j,x,y;
  i_color val;

  pbox prebox[512];
  for(i=0;i<512;i++) {
    prebox[i].boxnum=i;
    prebox[i].pixcnt=0;
    prebox[i].cand=1;
  }
  
  for(y=0;y<im->ysize;y++) for(x=0;x<im->xsize;x++) {
    i_gpix(im,x,y,&val);
    prebox[pixbox(&val)].pixcnt++;
  }

  for(i=0;i<512;i++) prebox[i].pdc=prebox[i].pixcnt;
  qsort(prebox,512,sizeof(pbox),(cmpfunc)pboxcmp);

  for(i=0;i<cnum;i++) {
    /*      printf("Color %d\n",i); 
	    for(k=0;k<10;k++) { printf("box=%03d %04d %d %04d \n",prebox[k].boxnum,prebox[k].pixcnt,prebox[k].cand,prebox[k].pdc); } 
	    printf("\n\n"); */
    reorder(prebox);
  }
  
  /*    for(k=0;k<cnum;k++) { printf("box=%03d %04d %d %04d \n",prebox[k].boxnum,prebox[k].pixcnt,prebox[k].cand,prebox[k].pdc); } */
  
  k=0;
  j=1;
  i=0;
  while(i<cnum) {
    /*    printf("prebox[%d].cand=%d\n",k,prebox[k].cand); */
    if (clr[i].state) { i++; continue; } /* reserved go to next */
    if (j>=prebox[k].cand) { k++; j=1; } else {
      if (prebox[k].cand == 2) boxcenter(prebox[k].boxnum,&(clr[i]));
      else boxrand(prebox[k].boxnum,&(clr[i]));
      /*      printf("(%d,%d) %d %d -> (%d,%d,%d)\n",k,j,prebox[k].boxnum,prebox[k].pixcnt,clr[i].r,clr[i].g,clr[i].b); */
      j++;
      i++;
    }
  }
}
  
#ifdef UNDEF
  } else {
    for(i=0;i<cnum;i++)
      {
	boxcenter(prebox[i].boxnum,&(clr[i]));
	printf("%d %d -> (%d,%d,%d)\n",prebox[i].boxnum,prebox[i].pixcnt,clr[i].r,clr[i].g,clr[i].b);
      }
  }
}
#endif



void reorder(pbox prescan[512]) {
  int nidx;
  pbox c;

  nidx=0;
  c=prescan[0];
  
  c.cand++;
  c.pdc=c.pixcnt/(c.cand*c.cand); 
  /*  c.pdc=c.pixcnt/c.cand; */
  while(c.pdc < prescan[nidx+1].pdc) {
    prescan[nidx]=prescan[nidx+1];
    nidx++;
  }
  prescan[nidx]=c;
}






void statbox(int boxnum,int cnum,cvec clr[256]) {
  int r0,r1,g0,g1,b0,b1;
  int r,g,b,i,cd,ld,bst_idx;
  int v[256];
  i_color val;
  for(i=0;i<256;i++) v[i]=0;
  bbox(boxnum,&r0,&r1,&g0,&g1,&b0,&b1);
  printf("statbox(%d), (%d,%d,%d)-(%d,%d,%d)\n",boxnum,r0,g0,b0,r1,g1,b1);
  
  /*	for(boxnum=0;boxnum<512;boxnum++) {
	bbox(boxnum,&r0,&r1,&g0,&g1,&b0,&b1);
	printf("statbox(%d) (%d,%d,%d)-(%d,%d,%d)\n",boxnum,r0,g0,b0,r1,g1,b1);
	}
  */
  
  for(r=r0;r<=r1;r++) for(g=g0;g<=g1;g++) for(b=b0;b<b1;b++) {
    val.channel[0]=r;
    val.channel[1]=g;
    val.channel[2]=b;
    ld=196608;
    for(i=0;i<cnum;i++) { 
      cd=eucl_d(&clr[i],&val);
      if (cd<ld) {
	ld=cd;
	bst_idx=i;
      }
    }
    v[bst_idx]++;
  }
  r=0;
  for(i=0;i<cnum;i++) if (v[i]) printf("%d - color[%d]=(%d,%d,%d) hits=%d\n",r++,i,clr[i].r,clr[i].g,clr[i].b,v[i]);
  printf("box(%d) -> %d\n",boxnum,r);
}








/* Create hash index */

void cr_hashindex(cvec clr[256],int cnum,hashbox hb[512]) {
  
  int bx,mind,cd,cumcnt,bst_idx,i;
/*  printf("indexing... \n");*/
  
  cumcnt=0;
  for(bx=0;bx<512;bx++) {
    mind=196608;
    for(i=0;i<cnum;i++) { 
      cd=maxdist(bx,&clr[i]);
      if (cd<mind) { mind=cd; bst_idx=i; } 
    }
    
    hb[bx].cnt=0;
    for(i=0;i<cnum;i++) if (mindist(bx,&clr[i])<mind) hb[bx].vec[hb[bx].cnt++]=i;
    /*printf("box %d -> approx -> %d\n",bx,hb[bx].cnt); */
    /*	statbox(bx,cnum,clr); */
    cumcnt+=hb[bx].cnt;
  }
  
/*  printf("Average search space: %d\n",cumcnt/512); */
}


int
pboxcmp(const pbox *a,const pbox *b) {
  if (a->pixcnt > b->pixcnt) return -1;
  if (a->pixcnt < b->pixcnt) return 1;
  return 0;
}


cvec
ecvec() { cvec c; c.r=c.g=c.b=0; c.state=0; c.dr=c.dg=c.db=c.cdist=c.mcount=0; return c; }

unsigned char
g_sat(int in) {
  if (in>255) { return 255; }
  else if (in>0) return in;
  return 0;
}


float
frand() {
  return rand()/(RAND_MAX+1.0);
}

float
frandn() {

  float u1,u2,w;
  
  w=1;
  
  while (w >= 1 || w == 0) {
    u1 = 2 * frand() - 1;
    u2 = 2 * frand() - 1;
    w = u1*u1 + u2*u2;
  }
  
  w = sqrt((-2*log(w))/w);
  return u1*w;
}


int
nrand() {
  int i,a;
  a=0;
  for(i=0;i<8;i++) a+=1+(int) (10.0*rand()/(RAND_MAX+1.0));
  return (a-25);
}

int
eucl_d(cvec* cv,i_color *cl) { return PWR2(cv->r-cl->channel[0])+PWR2(cv->g-cl->channel[1])+PWR2(cv->b-cl->channel[2]); }

int
vecbox(cvec *cv) { return ((cv->r & 224)<<1)+ ((cv->g&224)>>2) + ((cv->b &224) >> 5); }

int
pixbox(i_color *ic) { return ((ic->channel[0] & 224)<<1)+ ((ic->channel[1]&224)>>2) + ((ic->channel[2] &224) >> 5); }





void
bbox(int box,int *r0,int *r1,int *g0,int *g1,int *b0,int *b1) {
  *r0=(box&448)>>1;
  *r1=(*r0)|31;
  *g0=(box&56)<<2;
  *g1=(*g0)|31;
  *b0=(box&7)<<5;
  *b1=(*b0)|31;
}


void
boxcenter(int box,cvec *cv) {
  cv->r=15+((box&448)>>1);
  cv->g=15+((box&56)<<2);
  cv->b=15+((box&7)<<5);
}

void
boxrand(int box,cvec *cv) {
  cv->r=6+(rand()%25)+((box&448)>>1);
  cv->g=6+(rand()%25)+((box&56)<<2);
  cv->b=6+(rand()%25)+((box&7)<<5);
}


int
maxdist(int boxnum,cvec *cv) {
  int r0,r1,g0,g1,b0,b1;
  int r,g,b,mr,mg,mb;

  r=cv->r;
  g=cv->g;
  b=cv->b;
  
  bbox(boxnum,&r0,&r1,&g0,&g1,&b0,&b1);

  mr=max(abs(b-b0),abs(b-b1));
  mg=max(abs(g-g0),abs(g-g1));
  mb=max(abs(r-r0),abs(r-r1));
  
  return PWR2(mr)+PWR2(mg)+PWR2(mb);
}


int
mindist(int boxnum,cvec *cv) {
  int r0,r1,g0,g1,b0,b1;
  int r,g,b,mr,mg,mb;

  r=cv->r;
  g=cv->g;
  b=cv->b;
  
  bbox(boxnum,&r0,&r1,&g0,&g1,&b0,&b1);

  /*  printf("box %d, (%d,%d,%d)-(%d,%d,%d) vec (%d,%d,%d) ",boxnum,r0,g0,b0,r1,g1,b1,r,g,b); */

  if (r0<=r && r<=r1 && g0<=g && g<=g1 && b0<=b && b<=b1) return 0;

  mr=min(abs(b-b0),abs(b-b1));
  mg=min(abs(g-g0),abs(g-g1));
  mb=min(abs(r-r0),abs(r-r1));
  
  mr=PWR2(mr);
  mg=PWR2(mg);
  mb=PWR2(mb);

  if (r0<=r && r<=r1 && g0<=g && g<=g1) return mb;
  if (r0<=r && r<=r1 && b0<=b && b<=b1) return mg;
  if (b0<=b && b<=b1 && g0<=g && g<=g1) return mr;

  if (r0<=r && r<=r1) return mg+mb;
  if (g0<=g && g<=g1) return mr+mb;
  if (b0<=b && b<=b1) return mg+mr;

  return mr+mg+mb;
}

