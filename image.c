#include "image.h"
#include "io.h"

#define XAXIS 0
#define YAXIS 1

#define minmax(a,b,i) ( ((a>=i)?a: ( (b<=i)?b:i   )) )

/* Hack around an obscure linker bug on solaris - probably due to builtin gcc thingies */
void fake() { ceil(1); }

/* i_color_set:: Overwrite a color with new values.

   cl - pointer to color object
   r - red   compnent (range: 0 - 255)
   g - green compnent (range: 0 - 255)
   b - blue  compnent (range: 0 - 255)
   a - alpha compnent (range: 0 - 255)
*/

i_color *
i_color_set(i_color *cl,unsigned char r,unsigned char g,unsigned char b,unsigned char a) {
  mm_log((1,"i_set_i_color(cl* 0x%x,r %d,g %d,b %d,a %d)\n",cl,r,g,b,a));
  if (cl == NULL)
    if ( (cl=mymalloc(sizeof(i_color))) == NULL)
      m_fatal(2,"malloc() error\n");
  cl->rgba.r=r;
  cl->rgba.g=g;
  cl->rgba.b=b;
  cl->rgba.a=a;
  mm_log((1,"(0x%x) <- i_set_color\n",cl));
  return cl;
}

/* i_color_new:: Return a color object with values passed to it.

   cl - pointer to color object
   r - red   compnent (range: 0 - 255)
   g - green compnent (range: 0 - 255)
   b - blue  compnent (range: 0 - 255)
   a - alpha compnent (range: 0 - 255)
*/

i_color *
i_color_new(unsigned char r,unsigned char g,unsigned char b,unsigned char a) {
  i_color *cl=NULL;

  mm_log((1,"i_set_i_color(r %d,g %d,b %d,a %d)\n",cl,r,g,b,a));

  if ( (cl=mymalloc(sizeof(i_color))) == NULL) m_fatal(2,"malloc() error\n");
  cl->rgba.r=r;
  cl->rgba.g=g;
  cl->rgba.b=b;
  cl->rgba.a=a;
  mm_log((1,"(0x%x) <- i_set_color\n",cl));
  return cl;
}

/* i_color_add:: Add src to dst inplace - dst is modified.

   dst - pointer to destination color object
   src - pointer to color object that is added
   ch - number of channels
*/

void
i_color_add(i_color *dst,i_color *src,int ch) {
  int tmp,i;
  for(i=0;i<ch;i++) {
    tmp=dst->channel[i]+src->channel[i];
    dst->channel[i]= tmp>255 ? 255:tmp;
  }
}

/* i_color_info:: Dump color information to log - strictly for debugging.

   cl - pointer to color object
*/

void
i_color_info(i_color *cl) {
  mm_log((1,"i_color_info(cl* 0x%x)\n",cl));
  mm_log((1,"i_color_info: (%d,%d,%d,%d)\n",cl->rgba.r,cl->rgba.g,cl->rgba.b,cl->rgba.a));
}

/* ICL_DESTROY:: Destroy ancillary data for Color object.

   cl - pointer to color object
*/

void
ICL_DESTROY(i_color *cl) {
  mm_log((1,"ICL_DESTROY(cl* 0x%x)\n",cl));
  myfree(cl);
}

/* ICL_DESTROY:: Destroy ancillary data for Color object.

   cl - pointer to color object
*/


i_img *
IIM_new(int x,int y,int ch) {
  i_img *im;
  mm_log((1,"IIM_new(x %d,y %d,ch %d)\n",x,y,ch));

  im=i_img_empty_ch(NULL,x,y,ch);
  
  mm_log((1,"(0x%x) <- IIM_new\n",im));
  return im;
}


void
IIM_DESTROY(i_img *im) {
  mm_log((1,"IIM_DESTROY(im* 0x%x)\n",im));
  /*   myfree(cl); */
}



/* i_img_new:: Create new image reference - notice that this isn't an object yet and
   this should be fixed asap.

*/


i_img *
i_img_new() {
  i_img *im;
  
  mm_log((1,"i_img_struct()\n"));
  if ( (im=mymalloc(sizeof(i_img))) == NULL)
    m_fatal(2,"malloc() error\n");
  
  im->xsize=0;
  im->ysize=0;
  im->channels=3;
  im->ch_mask=MAXINT;
  im->bytes=0;
  im->data=NULL;

  im->i_f_ppix=i_ppix_d;
  im->i_f_gpix=i_gpix_d;
  im->ext_data=NULL;
  
  mm_log((1,"(0x%x) <- i_img_struct\n",im));
  return im;
}

/* i_img_empty:: Re-new image reference (assumes 3 channels)

   im - Image pointer
   x - xsize of destination image
   y - ysize of destination image

*/

i_img *
i_img_empty(i_img *im,int x,int y) {
  mm_log((1,"i_img_empty(*im 0x%x,x %d,y %d)\n",im,x,y));
  if (im==NULL)
    if ( (im=mymalloc(sizeof(i_img))) == NULL)
      m_fatal(2,"malloc() error\n");
  
  im->xsize=x;
  im->ysize=y;
  im->channels=3;
  im->ch_mask=MAXINT;
  im->bytes=x*y*im->channels;
  if ( (im->data=mymalloc(im->bytes)) == NULL) m_fatal(2,"malloc() error\n"); 
  memset(im->data,0,(size_t)im->bytes);

  im->i_f_ppix=i_ppix_d;
  im->i_f_gpix=i_gpix_d;
  im->ext_data=NULL;
  
  mm_log((1,"(0x%x) <- i_img_empty\n",im));
  return im;
}

/* i_img_empty_ch:: Re-new image reference 

   im - Image pointer
   x - xsize of destination image
   y - ysize of destination image
   ch - number of channels

*/

i_img *
i_img_empty_ch(i_img *im,int x,int y,int ch) {
  mm_log((1,"i_img_empty_ch(*im 0x%x,x %d,y %d,ch %d)\n",im,x,y,ch));
  if (im==NULL)
    if ( (im=mymalloc(sizeof(i_img))) == NULL)
      m_fatal(2,"malloc() error\n");
  
  im->xsize=x;
  im->ysize=y;
  im->channels=ch;
  im->ch_mask=MAXINT;
  im->bytes=x*y*im->channels;
  if ( (im->data=mymalloc(im->bytes)) == NULL) m_fatal(2,"malloc() error\n"); 
  memset(im->data,0,(size_t)im->bytes);
  
  im->i_f_ppix=i_ppix_d;
  im->i_f_gpix=i_gpix_d;
  im->ext_data=NULL;
  
  mm_log((1,"(0x%x) <- i_img_empty_ch\n",im));
  return im;
}

/* i_img_exorcise:: Free image data.

   im - Image pointer

*/

void
i_img_exorcise(i_img *im) {
  mm_log((1,"i_img_exorcise(im* 0x%x)\n",im));
  if (im->data != NULL) { myfree(im->data); }
  im->data=NULL;
  im->xsize=0;
  im->ysize=0;
  im->channels=0;

  im->i_f_ppix=i_ppix_d;
  im->i_f_gpix=i_gpix_d;
  im->ext_data=NULL;
}

/* i_img_destroy:: Destroy image and free data via exorcise.

   im - Image pointer
*/

void
i_img_destroy(i_img *im) {
  mm_log((1,"i_img_destroy(im* 0x%x)\n",im));
  i_img_exorcise(im);
  if (im) { myfree(im); }
}

/* i_img_info:: Return image information

   im - Image pointer
   info - pointer to array to return data
*/


void
i_img_info(i_img *im,int *info) {
  mm_log((1,"i_img_info(im 0x%x)\n",im));
  if (im != NULL) {
    mm_log((1,"i_img_info: xsize=%d ysize=%d channels=%d mask=%ud\n",im->xsize,im->ysize,im->channels,im->ch_mask));
    mm_log((1,"i_img_info: data=0x%d\n",im->data));
    info[0]=im->xsize;
    info[1]=im->ysize;
    info[2]=im->channels;
    info[3]=im->ch_mask;
  } else {
    info[0]=0;
    info[1]=0;
    info[2]=0;
    info[3]=0;
  }
}

void
i_img_setmask(i_img *im,int ch_mask) { im->ch_mask=ch_mask; }

int
i_img_getmask(i_img *im) { return im->ch_mask; }

int
i_img_getchannels(i_img *im) { return im->channels; }

int
i_ppix(i_img *im,int x,int y,i_color *val) { return im->i_f_ppix(im,x,y,val); }

int
i_gpix(i_img *im,int x,int y,i_color *val) { return im->i_f_gpix(im,x,y,val); }

int
i_ppix_d(i_img *im,int x,int y,i_color *val) {
  int ch;
  
  if ( x>-1 && x<im->xsize && y>-1 && y<im->ysize ) {
    for(ch=0;ch<im->channels;ch++)
      if (im->ch_mask&(1<<ch)) 
	im->data[(x+y*im->xsize)*im->channels+ch]=val->channel[ch];
    return 0;
  }
  return -1; /* error was clipped */
}


int 
i_gpix_d(i_img *im,int x,int y,i_color *val) {
  int ch;
  if (x>-1 && x<im->xsize && y>-1 && y<im->ysize) {
    for(ch=0;ch<im->channels;ch++) 
    	val->channel[ch]=im->data[(x+y*im->xsize)*im->channels+ch];
    return 0;
  }
  return -1; /* error was cliped */
}

float
i_gpix_pch(i_img *im,int x,int y,int ch) {
  if (x>-1 && x<im->xsize && y>-1 && y<im->ysize) return ((float)im->data[(x+y*im->xsize)*im->channels+ch]/255);
  else return 0;
}


/*
 (x1,y1) (x2,y2) specifies the region to copy (in the source coordinates)
 (tx,ty) specifies the upper left corner for the target image.
 pass NULL in trans for non transparent i_colors.
*/

void
i_copyto_trans(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty,i_color *trans) {
  i_color pv;
  int x,y,t,ttx,tty,tt,ch;

  mm_log((1,"i_copyto_trans(im* 0x%x,src 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,tx %d,ty %d,trans* 0x%x)\n",im,src,x1,y1,x2,y2,tx,ty,trans));

  if (x2<x1) { t=x1; x1=x2; x2=t; }
  if (y2<y1) { t=y1; y1=y2; y2=t; }

  ttx=tx;
  for(x=x1;x<x2;x++)
    {
      tty=ty;
      for(y=y1;y<y2;y++)
	{
	  i_gpix(src,x,y,&pv);
	  if ( trans != NULL)
	  {
	    tt=0;
	    for(ch=0;ch<im->channels;ch++) if (trans->channel[ch]!=pv.channel[ch]) tt++;
	    if (tt) i_ppix(im,ttx,tty,&pv);
	  } else i_ppix(im,ttx,tty,&pv);
	  tty++;
	}
      ttx++;
    }
}

void
i_copyto(i_img *im,i_img *src,int x1,int y1,int x2,int y2,int tx,int ty) {
  i_color pv;
  int x,y,t,ttx,tty;

  if (x2<x1) { t=x1; x1=x2; x2=t; }
  if (y2<y1) { t=y1; y1=y2; y2=t; }

  mm_log((1,"i_copyto(im* 0x%x,src 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,tx %d,ty %d)\n",im,src,x1,y1,x2,y2,tx,ty));

    tty=ty;
    for(y=y1;y<y2;y++) {
    ttx=tx;
    for(x=x1;x<x2;x++) {
      i_gpix(src,x,y,&pv);
      i_ppix(im,ttx,tty,&pv);
    ttx++;
    }
    tty++;
  }
}

void
i_copy(i_img *im,i_img *src) {
  i_color pv;
  int x,y,y1,x1;

  mm_log((1,"i_copy(im* 0x%x,src 0x%x)\n",im,src));

  x1=src->xsize;
  y1=src->ysize;
  i_img_empty_ch(im,x1,y1,src->channels);
  
  for(y=0;y<y1;y++) for(x=0;x<x1;x++) {
    i_gpix(src,x,y,&pv);
    i_ppix(im,x,y,&pv);
  }
}


void
i_rubthru(i_img *im,i_img *src,int tx,int ty) {
  i_color pv,orig,dest;
  int x,y,ttx,tty;

  mm_log((1,"i_rubthru(im 0x%x,src 0x%x,tx %d,ty %d)\n",im,src,tx,ty));

  if (im->channels != 3) {  fprintf(stderr,"Destination is not in rgb mode.\n"); exit(3); }
  if (src->channels != 4) { fprintf(stderr,"Source is not in rgba mode.\n"); exit(3); }

  ttx=tx;
  for(x=0;x<src->xsize;x++)
    {
      tty=ty;
      for(y=0;y<src->ysize;y++)
	{
	  /* fprintf(stderr,"reading (%d,%d) writing (%d,%d).\n",x,y,ttx,tty); */
	  i_gpix(src,x,y,&pv);
	  i_gpix(im,ttx,tty,&orig);
	  dest.rgb.r=(pv.rgba.a*pv.rgba.r+(255-pv.rgba.a)*orig.rgb.r)/255;
	  dest.rgb.g=(pv.rgba.a*pv.rgba.g+(255-pv.rgba.a)*orig.rgb.g)/255;
	  dest.rgb.b=(pv.rgba.a*pv.rgba.b+(255-pv.rgba.a)*orig.rgb.b)/255;
	  i_ppix(im,ttx,tty,&dest);
	  tty++;
	}
      ttx++;
    }
}

float
Lanczos(float x) {
  float PIx, PIx2;
  
  PIx = PI * x;
  PIx2 = PIx / 2.0;
  
  if ((x >= 2.0) || (x <= -2.0)) return (0.0);
  else if (x == 0.0) return (1.0);
  else return(sin(PIx) / PIx * sin(PIx2) / PIx2);
}

i_img*
i_scaleaxis(i_img *im, float Value, int Axis) {
  int hsize, vsize, i, j, k, l, lMax, iEnd, jEnd;
  int LanczosWidthFactor;
  float *l0, *l1, OldLocation;
  int T, TempJump1, TempJump2;
  float F, PictureValue[MAXCHANNELS];
  short psave;
  i_color val,val1,val2;
  i_img *new_img;

  mm_log((1,"i_scaleaxis(im 0x%x,Value %.2f,Axis %d)\n",im,Value,Axis));

  if (Axis == XAXIS) {
    hsize = (int) ((float) im->xsize * Value);
    vsize = im->ysize;
    
    jEnd = hsize;
    iEnd = vsize;
    
    TempJump1 = (hsize - 1) * 3;
    TempJump2 = hsize * (vsize - 1) * 3 + TempJump1;
  } else {
    hsize = im->xsize;
    vsize = (int) ((float) im->ysize * Value);
    
    jEnd = vsize;
    iEnd = hsize;
    
    TempJump1 = 0;
    TempJump2 = 0;
  }
  
  new_img=i_img_empty_ch(NULL,hsize,vsize,im->channels);
  
  if (Value >=1) LanczosWidthFactor = 1;
  else LanczosWidthFactor = (int) (1.0/Value);
  
  lMax = LanczosWidthFactor << 1;
  
  l0 = (float *) mymalloc(lMax * sizeof(float));
  l1 = (float *) mymalloc(lMax * sizeof(float));
  
  for (j=0; j<jEnd; j++) {
    OldLocation = ((float) j) / Value;
    T = (int) (OldLocation);
    F = OldLocation - (float) T;
    
    for (l = 0; l < lMax; l++) {
      l0[lMax-l-1] = Lanczos(((float) (lMax-l-1) + F) / (float) LanczosWidthFactor);
      l1[l] = Lanczos(((float) (l + 1) - F) / (float) LanczosWidthFactor);
    }
    
    if (Axis== XAXIS) {
      
      for (i=0; i<iEnd; i++) {
	for (k=0; k<im->channels; k++) PictureValue[k] = 0.0;
	for (l=0; l < lMax; l++) {
	  i_gpix(im,T+l+1, i, &val1);
	  i_gpix(im,T-lMax+l+1, i, &val2);
	  for (k=0; k<im->channels; k++) {
	    PictureValue[k] += l1[l] * val1.channel[k];
	    PictureValue[k] += l0[lMax-l-1] * val2.channel[k];
	  }
	}
	for(k=0;k<im->channels;k++) {
	  psave = (short)( PictureValue[k] / LanczosWidthFactor);
	  val.channel[k]=minmax(0,255,psave);
	}
	i_ppix(new_img,j,i,&val);
      }
      
    } else {
      
      for (i=0; i<iEnd; i++) {
	for (k=0; k<im->channels; k++) PictureValue[k] = 0.0;
	for (l=0; l < lMax; l++) {
	  i_gpix(im,i, T+l+1, &val1);
	  i_gpix(im,i, T-lMax+l+1, &val2);
	  for (k=0; k<im->channels; k++) {
	    PictureValue[k] += l1[l] * val1.channel[k];
	    PictureValue[k] += l0[lMax-l-1] * val2.channel[k]; 
	  }
	}
	for (k=0; k<im->channels; k++) {
	  psave = (short)( PictureValue[k] / LanczosWidthFactor);
	  val.channel[k]=minmax(0,255,psave);
	}
	i_ppix(new_img,i,j,&val);
      }
      
    }
  }
  myfree(l0);
  myfree(l1);

  mm_log((1,"(0x%x) <- i_scaleaxis\n",new_img));

  return new_img;
}


/* Scale by using nearest neighbor 
   Both axes scaled at the same time since 
   nothing is gained by doing it in two steps */


i_img*
i_scale_nn(i_img *im, float scx, float scy) {

  int nxsize,nysize,nx,ny;
  i_img *new_img;
  i_color val;

  mm_log((1,"i_scale_nn(im 0x%x,scx %.2f,scy %.2f)\n",im,scx,scy));

  nxsize = (int) ((float) im->xsize * scx);
  nysize = (int) ((float) im->ysize * scy);
    
  new_img=i_img_empty_ch(NULL,nxsize,nysize,im->channels);
  
  for(ny=0;ny<nysize;ny++) for(nx=0;nx<nxsize;nx++) {
    i_gpix(im,((float)nx)/scx,((float)ny)/scy,&val);
    i_ppix(new_img,nx,ny,&val);
  }

  mm_log((1,"(0x%x) <- i_scale_nn\n",new_img));

  return new_img;
}



i_img*
i_transform(i_img *im, int *opx,int opxl,int *opy,int opyl,double parm[],int parmlen) {
  double rx,ry;
  int nxsize,nysize,nx,ny;
  i_img *new_img;
  i_color val;
  
  mm_log((1,"i_transform(im 0x%x, opx 0x%x, opxl %d, opy 0x%x, opyl %d, parm 0x%x, parmlen %d)\n",im,opx,opxl,opy,opyl,parm,parmlen));

  nxsize = im->xsize;
  nysize = im->ysize ;
  
  new_img=i_img_empty_ch(NULL,nxsize,nysize,im->channels);
  /*   fprintf(stderr,"parm[2]=%f\n",parm[2]);   */
  for(ny=0;ny<nysize;ny++) for(nx=0;nx<nxsize;nx++) {
    /*     parm[parmlen-2]=(double)nx;
	   parm[parmlen-1]=(double)ny; */

    parm[0]=(double)nx;
    parm[1]=(double)ny;

    /*     fprintf(stderr,"(%d,%d) ->",nx,ny);  */
    rx=op_run(opx,opxl,parm,parmlen);
    ry=op_run(opy,opyl,parm,parmlen);
    /*    fprintf(stderr,"(%f,%f)\n",rx,ry); */
    i_gpix(im,rx,ry,&val);
    i_ppix(new_img,nx,ny,&val);
  }

  mm_log((1,"(0x%x) <- i_transform\n",new_img));
  return new_img;
}

float
i_img_diff(i_img *im1,i_img *im2) {
  int x,y,ch,xb,yb,chb;
  float tdiff;
  i_color val1,val2;

  mm_log((1,"i_img_diff(im1 0x%x,im2 0x%x)\n",im1,im2));

  xb=(im1->xsize<im2->xsize)?im1->xsize:im2->xsize;
  yb=(im1->ysize<im2->ysize)?im1->ysize:im2->ysize;
  chb=(im1->channels<im2->channels)?im1->channels:im2->channels;

  mm_log((1,"i_img_diff: xb=%d xy=%d chb=%d\n",xb,yb,chb));

  tdiff=0;
  for(y=0;y<yb;y++) for(x=0;x<xb;x++) {
    i_gpix(im1,x,y,&val1);
    i_gpix(im2,x,y,&val2);

    for(ch=0;ch<chb;ch++) tdiff+=(val1.channel[ch]-val2.channel[ch])*(val1.channel[ch]-val2.channel[ch]);
  }
  mm_log((1,"i_img_diff <- (%.2f)\n",tdiff));
  return tdiff;
}

/* just a tiny demo of haar wavelets */

i_img*
i_haar(i_img *im) {
  int mx,my;
  int fx,fy;
  int x,y;
  int ch,c;
  i_img *new_img,*new_img2;
  i_color val1,val2,dval1,dval2;
  
  mx=im->xsize;
  my=im->ysize;
  fx=(mx+1)/2;
  fy=(my+1)/2;


  /* horizontal pass */
  
  new_img=i_img_empty_ch(NULL,fx*2,fy*2,im->channels);
  new_img2=i_img_empty_ch(NULL,fx*2,fy*2,im->channels);

  c=0; 
  for(y=0;y<my;y++) for(x=0;x<fx;x++) {
    i_gpix(im,x*2,y,&val1);
    i_gpix(im,x*2+1,y,&val2);
    for(ch=0;ch<im->channels;ch++) {
      dval1.channel[ch]=(val1.channel[ch]+val2.channel[ch])/2;
      dval2.channel[ch]=(255+val1.channel[ch]-val2.channel[ch])/2;
    }
    i_ppix(new_img,x,y,&dval1);
    i_ppix(new_img,x+fx,y,&dval2);
  }

  for(y=0;y<fy;y++) for(x=0;x<mx;x++) {
    i_gpix(new_img,x,y*2,&val1);
    i_gpix(new_img,x,y*2+1,&val2);
    for(ch=0;ch<im->channels;ch++) {
      dval1.channel[ch]=(val1.channel[ch]+val2.channel[ch])/2;
      dval2.channel[ch]=(255+val1.channel[ch]-val2.channel[ch])/2;
    }
    i_ppix(new_img2,x,y,&dval1);
    i_ppix(new_img2,x,y+fy,&dval2);
  }

  i_img_destroy(new_img);
  return new_img2;
}

/* returns number of colors or -1 
   to indicate that it was more than max colors */

int
i_count_colors(i_img *im,int maxc) {
  struct octt *ct;
  int x,y;
  int xsize,ysize;
  i_color val;
  int colorcnt;

  mm_log((1,"i_count_colors(im 0x%08X,maxc %d)\n"));

  xsize=im->xsize; 
  ysize=im->ysize;
  ct=octt_new();
 
  colorcnt=0;
  for(y=0;y<ysize;y++) for(x=0;x<xsize;x++) {
    i_gpix(im,x,y,&val);
    colorcnt+=octt_add(ct,val.rgb.r,val.rgb.g,val.rgb.b);
    if (colorcnt > maxc) { octt_delete(ct); return -1; }
  }
  octt_delete(ct);
  return colorcnt;
}


symbol_table_t symbol_table={i_has_format,i_color_set,i_color_info,
			     i_img_new,i_img_empty,i_img_empty_ch,i_img_exorcise,
			     i_img_info,i_img_setmask,i_img_getmask,i_ppix,i_gpix,
			     i_box,i_draw,i_arc,i_copyto,i_copyto_trans,i_rubthru};


/*
=item i_gen_reader(i_gen_read_data *info, char *buf, int length)

Performs general read buffering for file readers that permit reading
to be done through a callback.

The final callback gets two parameters, a I<need> value, and a I<want>
value, where I<need> is the amount of data that the file library needs
to read, and I<want> is the amount of space available in the buffer
maintained by these functions.

This means if you need to read from a stream that you don't know the
length of, you can return I<need> bytes, taking the performance hit of
possibly expensive callbacks (eg. back to perl code), or if you are
reading from a stream where it doesn't matter if some data is lost, or
if the total length of the stream is known, you can return I<want>
bytes.

=cut 
*/

int
i_gen_reader(i_gen_read_data *gci, char *buf, int length) {
  int total;

  if (length < gci->length - gci->cpos) {
    /* simplest case */
    memcpy(buf, gci->buffer+gci->cpos, length);
    gci->cpos += length;
    return length;
  }
  
  total = 0;
  memcpy(buf, gci->buffer+gci->cpos, gci->length-gci->cpos);
  total  += gci->length - gci->cpos;
  length -= gci->length - gci->cpos;
  buf    += gci->length - gci->cpos;
  if (length < (int)sizeof(gci->buffer)) {
    int did_read;
    int copy_size;
    while (length
	   && (did_read = (gci->cb)(gci->userdata, gci->buffer, length, 
				    sizeof(gci->buffer))) > 0) {
      gci->cpos = 0;
      gci->length = did_read;

      copy_size = min(length, gci->length);
      memcpy(buf, gci->buffer, copy_size);
      gci->cpos += copy_size;
      buf += copy_size;
      total += copy_size;
      length -= copy_size;
    }
  }
  else {
    /* just read the rest - too big for our buffer*/
    int did_read;
    while ((did_read = (gci->cb)(gci->userdata, buf, length, length)) > 0) {
      length -= did_read;
      total += did_read;
      buf += did_read;
    }
  }
  return total;
}

/*
=item i_gen_read_data_new(i_read_callback_t cb, char *userdata)

For use by callback file readers to initialize the reader buffer.

Allocates, initializes and returns the reader buffer.

See also L<image.c/free_gen_read_data> and L<image.c/i_gen_reader>.

=cut
*/
i_gen_read_data *
i_gen_read_data_new(i_read_callback_t cb, char *userdata) {
  i_gen_read_data *self = mymalloc(sizeof(i_gen_read_data));
  self->cb = cb;
  self->userdata = userdata;
  self->length = 0;
  self->cpos = 0;

  return self;
}

/*
=item free_gen_read_data(i_gen_read_data *)

Cleans up.

=cut
*/
void free_gen_read_data(i_gen_read_data *self) {
  myfree(self);
}

/*
=item i_gen_writer(i_gen_write_data *info, char const *data, int size)

Performs write buffering for a callback based file writer.

Failures are considered fatal, if a write fails then data will be
dropped.

=cut
*/
int 
i_gen_writer(
i_gen_write_data *self, 
char const *data, 
int size)
{
  if (self->filledto && self->filledto+size > self->maxlength) {
    if (self->cb(self->userdata, self->buffer, self->filledto)) {
      self->filledto = 0;
    }
    else {
      self->filledto = 0;
      return 0;
    }
  }
  if (self->filledto+size <= self->maxlength) {
    /* just save it */
    memcpy(self->buffer+self->filledto, data, size);
    self->filledto += size;
    return 1;
  }
  /* doesn't fit - hand it off */
  return self->cb(self->userdata, data, size);
}

/*
=item i_gen_write_data_new(i_write_callback_t cb, char *userdata, int max_length)

Allocates and initializes the data structure used by i_gen_writer.

This should be released with L<image.c/free_gen_write_data>

=cut
*/
i_gen_write_data *i_gen_write_data_new(i_write_callback_t cb, 
				       char *userdata, int max_length)
{
  i_gen_write_data *self = mymalloc(sizeof(i_gen_write_data));
  self->cb = cb;
  self->userdata = userdata;
  self->maxlength = min(max_length, sizeof(self->buffer));
  if (self->maxlength < 0)
    self->maxlength = sizeof(self->buffer);
  self->filledto = 0;

  return self;
}

/*
=item free_gen_write_data(i_gen_write_data *info, int flush)

Cleans up the write buffer.

Will flush any left-over data if I<flush> is non-zero.

Returns non-zero if flush is zero or if info->cb() returns non-zero.

Return zero only if flush is non-zero and info->cb() returns zero.
ie. if it fails.

=cut
*/

int free_gen_write_data(i_gen_write_data *info, int flush)
{
  int result = !flush || 
    info->filledto == 0 ||
    info->cb(info->userdata, info->buffer, info->filledto);
  myfree(info);

  return result;
}
