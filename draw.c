#include "image.h"
#include "draw.h"


void
i_mmarray_cr(i_mmarray *ar,int l) {
  int i;

  ar->lines=l;
  ar->data=mymalloc(sizeof(minmax)*l);
  for(i=0;i<l;i++) { ar->data[i].max=-1; ar->data[i].min=MAXINT; }
}

void
i_mmarray_dst(i_mmarray *ar) {
  ar->lines=0;
  if (ar->data != NULL) { myfree(ar->data); ar->data=NULL; }
}

void
i_mmarray_add(i_mmarray *ar,int x,int y) {
  if (y>-1 && y<ar->lines)
    {
      if (x<ar->data[y].min) ar->data[y].min=x;
      if (x>ar->data[y].max) ar->data[y].max=x;
    }
}

int
i_mmarray_gmin(i_mmarray *ar,int y) {
  if (y>-1 && y<ar->lines) return ar->data[y].min;
  else return -1;
}

int
i_mmarray_getm(i_mmarray *ar,int y) {
  if (y>-1 && y<ar->lines) return ar->data[y].max;
  else return MAXINT;
}

void
i_mmarray_render(i_img *im,i_mmarray *ar,i_color *val) {
  int i,x;
  for(i=0;i<ar->lines;i++) if (ar->data[i].max!=-1) for(x=ar->data[i].min;x<ar->data[i].max;x++) i_ppix(im,x,i,val);
}


void
i_arcdraw(i_img *im,int x1,int y1,int x2,int y2,i_mmarray *ar) {
  double alpha;
  double dsec;
  int temp;
  alpha=(double)(y2-y1)/(double)(x2-x1);
  if (fabs(alpha)<1) 
    {
      if (x2<x1) { temp=x1; x1=x2; x2=temp; temp=y1; y1=y2; y2=temp; }
      dsec=y1;
      while(x1<x2)
	{
	  dsec+=alpha;
	  i_mmarray_add(ar,x1,(int)(dsec+0.5));
	  x1++;
	}
    }
  else
    {
      alpha=1/alpha;
      if (y2<y1) { temp=x1; x1=x2; x2=temp; temp=y1; y1=y2; y2=temp; }
      dsec=x1;
      while(y1<y2)
	{
	  dsec+=alpha;
	  i_mmarray_add(ar,(int)(dsec+0.5),y1);
	  y1++;
	}
    }
}

void
i_mmarray_info(i_mmarray *ar) {
  int i;
  for(i=0;i<ar->lines;i++)
  if (ar->data[i].max!=-1) printf("line %d: min=%d, max=%d.\n",i,ar->data[i].min,ar->data[i].max);
}



void
i_arc(i_img *im,int x,int y,float rad,float d1,float d2,i_color *val) {
  i_mmarray dot;
  float f,fx,fy;
  int x1,y1;

  mm_log((1,"i_arc(im* 0x%x,x %d,y %d,rad %.2f,d1 %.2f,d2 %.2f,val 0x%x)\n",im,x,y,rad,d1,d2,val));

  i_mmarray_cr(&dot,im->ysize);

  x1=(int)(x+0.5+rad*cos(d1*PI/180.0));
  y1=(int)(y+0.5+rad*sin(d1*PI/180.0));
  fx=(float)x1; fy=(float)y1;

  /*  printf("x1: %d.\ny1: %d.\n",x1,y1); */
  i_arcdraw(im,x,y,x1,y1,&dot);

  x1=(int)(x+0.5+rad*cos(d2*PI/180.0));
  y1=(int)(y+0.5+rad*sin(d2*PI/180.0));

  for(f=d1;f<=d2;f+=0.01) i_mmarray_add(&dot,(int)(x+0.5+rad*cos(f*PI/180.0)),(int)(y+0.5+rad*sin(f*PI/180.0)));

  /*  printf("x1: %d.\ny1: %d.\n",x1,y1); */
  i_arcdraw(im,x,y,x1,y1,&dot);

  /*  dot.info(); */
  i_mmarray_render(im,&dot,val);
}

void
i_box(i_img *im,int x1,int y1,int x2,int y2,i_color *val) {
  int x,y;
  mm_log((1,"i_box(im* 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,val 0x%x)\n",im,x1,y1,x2,y2,val));
  for(x=x1;x<x2+1;x++) {
    i_ppix(im,x,y1,val);
    i_ppix(im,x,y2,val);
  }
  for(y=y1;y<y2+1;y++) {
    i_ppix(im,x1,y,val);
    i_ppix(im,x2,y,val);
  }
}

void
i_box_filled(i_img *im,int x1,int y1,int x2,int y2,i_color *val) {
  int x,y;
  mm_log((1,"i_box_filled(im* 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,val 0x%x)\n",im,x1,y1,x2,y2,val));
  for(x=x1;x<x2+1;x++) for (y=y1;y<y2+1;y++) i_ppix(im,x,y,val);
}


void
i_draw(i_img *im,int x1,int y1,int x2,int y2,i_color *val) {
  double alpha;
  double dsec;
  int temp;

  mm_log((1,"i_draw(im* 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,val 0x%x)\n",im,x1,y1,x2,y2,val));

  alpha=(double)(y2-y1)/(double)(x2-x1);
  if (fabs(alpha)<1) 
    {
      if (x2<x1) { temp=x1; x1=x2; x2=temp; temp=y1; y1=y2; y2=temp; }
      dsec=y1;
      while(x1<x2)
	{
	  dsec+=alpha;
	  i_ppix(im,x1,(int)(dsec+0.5),val);
	  x1++;
	}
    }
  else
    {
      alpha=1/alpha;
      if (y2<y1) { temp=x1; x1=x2; x2=temp; temp=y1; y1=y2; y2=temp; }
      dsec=x1;
      while(y1<y2)
	{
	  dsec+=alpha;
	  i_ppix(im,(int)(dsec+0.5),y1,val);
	  y1++;
	}
    }
  mm_log((1,"i_draw: alpha=%f.\n",alpha));
}

void
i_line_aa(i_img *im,int x1,int y1,int x2,int y2,i_color *val) {
  i_color tval;
  float alpha;
  float dsec,dfrac;
  int temp,dx,dy,isec,ch;

  mm_log((1,"i_draw(im* 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,val 0x%x)\n",im,x1,y1,x2,y2,val));

  dy=y2-y1;
  dx=x2-x1;

  if (abs(dx)>abs(dy)) { /* alpha < 1 */
    if (x2<x1) { temp=x1; x1=x2; x2=temp; temp=y1; y1=y2; y2=temp; }
    alpha=(float)(y2-y1)/(float)(x2-x1);

    dsec=y1;
    while(x1<=x2) {
      isec=(int)dsec;
      dfrac=dsec-isec;
      /*      dfrac=1-(1-dfrac)*(1-dfrac); */
      /* This is something we can play with to try to get better looking lines */

      i_gpix(im,x1,isec,&tval);
      for(ch=0;ch<im->channels;ch++) tval.channel[ch]=(unsigned char)(dfrac*(float)tval.channel[ch]+(1-dfrac)*(float)val->channel[ch]);
      i_ppix(im,x1,isec,&tval);
      
      i_gpix(im,x1,isec+1,&tval);
      for(ch=0;ch<im->channels;ch++) tval.channel[ch]=(unsigned char)((1-dfrac)*(float)tval.channel[ch]+dfrac*(float)val->channel[ch]);
      i_ppix(im,x1,isec+1,&tval);
      
      dsec+=alpha;
      x1++;
    }
  } else {
    if (y2<y1) { temp=y1; y1=y2; y2=temp; temp=x1; x1=x2; x2=temp; }
    alpha=(float)(x2-x1)/(float)(y2-y1);
    dsec=x1;
    while(y1<=y2) {
      isec=(int)dsec;
      dfrac=dsec-isec;
      /*      dfrac=sqrt(dfrac); */
      /* This is something we can play with */
      i_gpix(im,isec,y1,&tval);
      for(ch=0;ch<im->channels;ch++) tval.channel[ch]=(unsigned char)(dfrac*(float)tval.channel[ch]+(1-dfrac)*(float)val->channel[ch]);
      i_ppix(im,isec,y1,&tval);

      i_gpix(im,isec+1,y1,&tval);
      for(ch=0;ch<im->channels;ch++) tval.channel[ch]=(unsigned char)((1-dfrac)*(float)tval.channel[ch]+dfrac*(float)val->channel[ch]);
      i_ppix(im,isec+1,y1,&tval);

      dsec+=alpha;
      y1++;
    }
  }
}

double
perm(int n,int k) {
  double r;
  int i;
  r=1;
  for(i=k+1;i<=n;i++) r*=i;
  for(i=1;i<=(n-k);i++) r/=i;
  return r;
}


/* Note in calculating t^k*(1-t)^(n-k) 
   we can start by using t^0=1 so this simplifies to
   t^0*(1-t)^n - we want to multiply that with t/(1-t) each iteration
   to get a new level - this may lead to errors who knows lets test it */

void
i_bezier_multi(i_img *im,int l,double *x,double *y,i_color *val) {
  double *bzcoef;
  double t,cx,cy;
  int k,i;
  int lx,ly;
  int n=l-1;
  double itr,ccoef;

  bzcoef=mymalloc(sizeof(double)*l);
  for(k=0;k<l;k++) bzcoef[k]=perm(n,k);
  i_color_info(val);


  /*  for(k=0;k<l;k++) printf("bzcoef: %d -> %f\n",k,bzcoef[k]); */
  i=0;
  for(t=0;t<=1;t+=0.025) {
    cx=cy=0;
    itr=t/(1-t);
    ccoef=pow(1-t,n);
    for(k=0;k<l;k++) {
      /*      cx+=bzcoef[k]*x[k]*pow(t,k)*pow(1-t,n-k); 
	      cy+=bzcoef[k]*y[k]*pow(t,k)*pow(1-t,n-k);*/

      cx+=bzcoef[k]*x[k]*ccoef;
      cy+=bzcoef[k]*y[k]*ccoef;
      ccoef*=itr;
    }
    /*    printf("%f -> (%d,%d)\n",t,(int)(0.5+cx),(int)(0.5+cy)); */
    if (i++) { 
      i_line_aa(im,lx,ly,(int)(0.5+cx),(int)(0.5+cy),val);
    }
      /*     i_ppix(im,(int)(0.5+cx),(int)(0.5+cy),val); */
    lx=(int)(0.5+cx);
    ly=(int)(0.5+cy);
  }
  i_color_info(val);
  myfree(bzcoef);
}

struct p_point {
  int n;
  double x,y;
};

struct p_line  {
  int n;
  double x1,y1;
  double x2,y2;
  double miny,maxy;
};


int
p_compy(void *p1, void *p2) {
  /* p_compy(const struct p_point *p1, const struct p_point *p2) { */
  struct p_point *pp1,*pp2;
  pp1=p1;
  pp2=p2;
  if (pp1->y > pp2->y) return 1;
  if (pp1->y < pp2->y) return -1;
  return 0;
}




/* Antialiasing polygon algorithm 
   specs:
     1. only nice polygons - no crossovers
     2. floating point co-ordinates
     3. full antialiasing ( complete spectrum of blends )
     4. uses hardly any memory
     5. no subsampling phase

   For each interval we must: 
     1. find which lines are in it
     2. order the lines from in increasing x order.
        since we are assuming no crossovers it is sufficent
        to check a single point on each line.
*/


double
p_eval_aty(struct p_line *l,double y) {
  double x;
  
  
}


void
i_poly_aa(i_img *im,int l,double *x,double *y,i_color *val) {
  int i,s,cy,miny,maxy;
  double comp=0.01;
  struct p_point *pset;
  struct p_line *lset;
  
  if ( (pset=mymalloc(sizeof(struct p_point)*l)) == NULL) { m_fatal(2,"malloc failed\n"); return; }
  if ( (lset=mymalloc(sizeof(struct p_line)*l)) == NULL) { m_fatal(2,"malloc failed\n"); return; }

  for(i=0;i<l;i++) {
    pset[i].n=i;
    pset[i].x=x[i];
    pset[i].y=y[i];
    
    lset[i].n=i;
    lset[i].x1=x[i];
    lset[i].y1=y[i];
    lset[i].x2=x[(i+1)%l];
    lset[i].y2=y[(i+1)%l];
    lset[i].miny=min(lset[i].y1,lset[i].y2);
    lset[i].maxy=max(lset[i].y1,lset[i].y2);
  }

  qsort(pset,l,sizeof(struct p_point),p_compy);

  printf("POST point list\n");
  for(i=0;i<l;i++) {
    printf("%d [ %d ] %f %f\n",i,pset[i].n,pset[i].x,pset[i].y);
  }
  
  printf("line list\n");
  for(i=0;i<l;i++) {
    printf("%d [ %d ] (%.2f , %.2f) -> (%.2f , %.2f) yspan ( %.2f , %.2f )\n",i,lset[i].n,lset[i].x1,lset[i].y1,lset[i].x2,lset[i].y2,lset[i].miny,lset[i].maxy);
  }
  
  miny=pset[0].y;
  maxy=ceil(pset[i-1].y);
  for(cy=miny;cy<=maxy;cy++) {
    



  }


  
}
