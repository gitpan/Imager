#include "image.h"
#include "io.h"

#define XAXIS 0
#define YAXIS 1

#define minmax(a,b,i) ( ((a>=i)?a: ( (b<=i)?b:i   )) )

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

i_color_add(i_color *dst,i_color *src,int ch) {
  int tmp,i;
  for(i=0;i<ch;i++) {
    tmp=dst->channel[i]+src->channel[i];
    dst->channel[i]= tmp>255 ? 255:tmp;
  }
}

void
i_color_info(i_color *cl) {
  mm_log((1,"i_color_info(cl* 0x%x)\n",cl));
  mm_log((1,"i_color_info: (%d,%d,%d,%d)\n",cl->rgba.r,cl->rgba.g,cl->rgba.b,cl->rgba.a));
}

void
ICL_DESTROY(i_color *cl) {
  mm_log((1,"ICL_DESTROY(cl* 0x%x)\n",cl));
  myfree(cl);
}


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


void
i_img_destroy(i_img *im) {
  mm_log((1,"i_img_destroy(im* 0x%x)\n",im));
  i_img_exorcise(im);
  if (im) { myfree(im); }
}

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
i_ppix(i_img *im,int x,int y,i_color *val) { return im->i_f_ppix(im,x,y,val); }

int
i_gpix(i_img *im,int x,int y,i_color *val) { return im->i_f_gpix(im,x,y,val); }

int
i_ppix_d(i_img *im,int x,int y,i_color *val) {
  int ch;
  
  if ( x>-1 && x<im->xsize && y>-1 && y<im->ysize )
    {
      for(ch=0;ch<im->channels;ch++)
	if (im->ch_mask&(1<<ch)) im->data[(x+y*im->xsize)*im->channels+ch]=val->channel[ch];
      return 0;
    }
  return -1; /* error was clipped */
}


int 
i_gpix_d(i_img *im,int x,int y,i_color *val) {
  int ch;
  if (x>-1 && x<im->xsize && y>-1 && y<im->ysize) {
    for(ch=0;ch<im->channels;ch++) val->channel[ch]=im->data[(x+y*im->xsize)*im->channels+ch];
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
  int x,y,t,ttx,tty,tt,ch;

  mm_log((1,"i_copyto(im* 0x%x,src 0x%x,x1 %d,y1 %d,x2 %d,y2 %d,tx %d,ty %d)\n",im,src,x1,y1,x2,y2,tx,ty));

  if (x2<x1) { t=x1; x1=x2; x2=t; }
  if (y2<y1) { t=y1; y1=y2; y2=t; }

  ttx=tx;
  for(x=x1;x<x2;x++) {
    tty=ty;
    for(y=y1;y<y2;y++) {
      i_gpix(src,x,y,&pv);
      i_ppix(im,ttx,tty,&pv);
      tty++;
    }
    ttx++;
  }
}


void
i_rubthru(i_img *im,i_img *src,int tx,int ty) {
  i_color pv,orig,dest;
  int x,y,t,ttx,tty,tt;

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
}


symbol_table_t symbol_table={i_has_format,i_color_set,i_color_info,
			     i_img_new,i_img_empty,i_img_empty_ch,i_img_exorcise,
			     i_img_info,i_img_setmask,i_img_getmask,i_ppix,i_gpix,
			     i_box,i_draw,i_arc,i_copyto,i_copyto_trans,i_rubthru};


