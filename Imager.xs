#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#ifdef __cplusplus
}
#endif

#include "image.h"
#include "feat.h"
#include "dynaload.h"

typedef i_color* Imager__Color;


MODULE = Imager		PACKAGE = Imager::Color	PREFIX = ICL_

void
ICL_DESTROY(cl)
               Imager::Color    cl


MODULE = Imager		PACKAGE = Imager

PROTOTYPES: ENABLE

Imager::Color
i_color_new(r,g,b,a)
               unsigned char     r
               unsigned char     g
               unsigned char     b
               unsigned char     a


Imager::Color
i_color_set(cl,r,g,b,a)
               Imager::Color    cl
               unsigned char     r
               unsigned char     g
               unsigned char     b
               unsigned char     a


void
i_color_info(cl)
               Imager::Color    cl


void
i_list_formats()
	     PREINIT:
	      char*    item;
	       int     i;
	     PPCODE:
	       i=0;
	       while( (item=i_format_list[i++]) != NULL ) {
		      EXTEND(SP, 1);
		      PUSHs(sv_2mortal(newSVpv(item,0)));
	       }

undef_int
i_has_format(frmt)
              char*    frmt

i_img*
i_img_empty(im,x,y)
	     i_img*    im
               int     x
	       int     y

i_img*
i_img_empty_ch(im,x,y,ch)
	     i_img*    im
               int     x
	       int     y
	       int     ch

void
init_log(name,onoff)
	      char*    name
	       int     onoff

void
i_img_exorcise(im)
             i_img*    im

void
i_img_destroy(im)
             i_img*    im

void
i_img_info(im)
             i_img*    im
	     PREINIT:
	       int     info[4];
	     PPCODE:
   	       i_img_info(im,info);
               EXTEND(SP, 4);
               PUSHs(sv_2mortal(newSViv(info[0])));
               PUSHs(sv_2mortal(newSViv(info[1])));
               PUSHs(sv_2mortal(newSViv(info[2])));
               PUSHs(sv_2mortal(newSViv(info[3])));


void
i_img_setmask(im,ch_mask)
             i_img*    im
	       int     ch_mask

int
i_img_getmask(im)
	     i_img*    im


void
i_draw(im,x1,y1,x2,y2,val)
	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::Color    val

void
i_line_aa(im,x1,y1,x2,y2,val)
	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::Color    val

void
i_box(im,x1,y1,x2,y2,val)
    	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::Color    val

void
i_box_filled(im,x1,y1,x2,y2,val)
    	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::Color    val

void
i_arc(im,x,y,rad,d1,d2,val)
       	     i_img*    im
	       int     x
	       int     y
             float     rad
             float     d1
             float     d2
	   Imager::Color    val



void
i_bezier_multi(im,xc,yc,val)
    	     i_img*    im
             Imager::Color  val
	     PREINIT:
	     double   *x,*y;
	     int       len;
	     AV       *av1;
	     AV       *av2;
	     SV       *sv1;
	     SV       *sv2;
	     int i;
	     PPCODE:
	     i_color_info(val);
	     if (!SvROK(ST(1))) croak("Imager: Parameter 1 to i_bezier_multi must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("Imager: Parameter 1 to i_bezier_multi must be a reference to an array\n");
	     if (!SvROK(ST(2))) croak("Imager: Parameter 1 to i_bezier_multi must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(2))) != SVt_PVAV) croak("Imager: Parameter 1 to i_bezier_multi must be a reference to an array\n");
	     av1=(AV*)SvRV(ST(1));
	     av2=(AV*)SvRV(ST(2));
	     if (av_len(av1) != av_len(av2)) croak("Imager: x and y arrays to i_bezier_multi must be equal length\n");
	     len=av_len(av1)+1;
	     x=mymalloc( len*sizeof(double) );
	     y=mymalloc( len*sizeof(double) );
	     for(i=0;i<len;i++) {
	       sv1=(*(av_fetch(av1,i,0)));
	       sv2=(*(av_fetch(av2,i,0)));
	       x[i]=(double)SvNV(sv1);
	       y[i]=(double)SvNV(sv2);
	     }
             i_bezier_multi(im,len,x,y,val);



void
i_copyto(im,src,x1,y1,x2,y2,tx,ty)
    	     i_img*    im
    	     i_img*    src
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	       int     tx
	       int     ty


void
i_copyto_trans(im,src,x1,y1,x2,y2,tx,ty,trans)
    	     i_img*    im
    	     i_img*    src
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	       int     tx
	       int     ty
     Imager::Color     trans

void
i_rubthru(im,src,tx,ty)
    	     i_img*    im
    	     i_img*    src
	       int     tx
	       int     ty


void
i_gaussian(im,stdev)
	     i_img*    im
	     float     stdev

void
i_conv(im,pcoef)
	     i_img*    im
	     PREINIT:
	     float*    coeff;
	     int     len;
	     AV* av;
	     SV* sv1;
	     int i;
	     PPCODE:
	     if (!SvROK(ST(1))) croak("Imager: Parameter 1 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("SuperS: Parameter 1 must be a reference to an array\n");
	     av=(AV*)SvRV(ST(1));
	     len=av_len(av)+1;
	     coeff=mymalloc( len*sizeof(float) );
	     for(i=0;i<len;i++) {
	       sv1=(*(av_fetch(av,i,0)));
	       coeff[i]=(float)SvNV(sv1);
	     }
	     i_conv(im,coeff,len);

	          
float
i_img_diff(im1,im2)
	     i_img*    im1
	     i_img*    im2


undef_int	  
i_init_fonts()

#ifdef HAVE_LIBT1

void
i_t1_set_aa(st)
      	       int     st

undef_int
i_t1_cp(im,xb,yb,channel,fontnum,points,str,len,align)
       	     i_img*    im
	       int     xb
	       int     yb
	       int     channel
	       int     fontnum
             float     points
	      char*    str
	       int     len
	       int     align

void
i_t1_bbox(fontnum,point,str,len)
               int     fontnum
	     float     point
	      char*    str
	       int     len
	     PREINIT:
	       int     cords[4];
	     PPCODE:
   	       i_t1_bbox(fontnum,point,str,len,cords);
               EXTEND(SP, 4);
               PUSHs(sv_2mortal(newSViv(cords[0])));
               PUSHs(sv_2mortal(newSViv(cords[1])));
               PUSHs(sv_2mortal(newSViv(cords[2])));
               PUSHs(sv_2mortal(newSViv(cords[3])));



undef_int
i_t1_text(im,xb,yb,cl,fontnum,points,str,len,align)
       	     i_img*    im
	       int     xb
	       int     yb
     Imager::Color    cl
	       int     fontnum
             float     points
	      char*    str
	       int     len
	       int     align

#endif 

#ifdef HAVE_LIBTT



undef_int
i_tt_text(im,xb,yb,cl,fontname,points,str,len,align)
       	     i_img*    im
	       int     xb
	       int     yb
     Imager::Color     cl
	      char*    fontname
             float     points
	      char*    str
	       int     len
	       int     align


undef_int
i_tt_cp(im,xb,yb,channel,fontname,points,str,len,align)
       	     i_img*    im
	       int     xb
	       int     yb
	       int     channel
	      char*    fontname
             float     points
	      char*    str
	       int     len
	       int     align



void
i_tt_bbox(fontname,point,str,len)
              char*    fontname
	     float     point
	      char*    str
	       int     len
	     PREINIT:
	       int     cords[4];
	     PPCODE:
   	       i_tt_bbox(fontname,point,str,len,cords);
               EXTEND(SP, 4);
               PUSHs(sv_2mortal(newSViv(cords[0])));
               PUSHs(sv_2mortal(newSViv(cords[1])));
               PUSHs(sv_2mortal(newSViv(cords[2])));
               PUSHs(sv_2mortal(newSViv(cords[3])));


#endif 




#ifdef HAVE_LIBJPEG
undef_int
i_writejpeg(im,fd,qfactor)
	     i_img*    im
	       int     fd
	       int     qfactor

void
i_readjpeg(im,fd)
	     i_img*    im
	       int     fd
	     PREINIT:
	      char*    iptc_itext;
	       int     tlength;
	     i_img*    rimg;
	     PPCODE:
 	      iptc_itext=NULL;
	      rimg=i_readjpeg(im,fd,&iptc_itext,&tlength);
	      if (iptc_itext == NULL) {
	            EXTEND(SP,1);
		    PUSHs(sv_2mortal(newSViv((IV)rimg)));
	      } else {
	            EXTEND(SP,1);
		    PUSHs(sv_2mortal(newSViv((IV)rimg)));
		    PUSHs(sv_2mortal(newSVpv(iptc_itext,tlength)));
	      }
	      if ( (iptc_itext) != NULL) myfree(iptc_itext);

#endif


#ifdef HAVE_LIBPNG

i_img*
i_readpng(im,fd)
	     i_img*    im
	       int     fd

undef_int
i_writepng(im,fd)
	     i_img*    im
	       int     fd

#endif


#ifdef HAVE_LIBGIF


undef_int
i_writegif(im,fd,colors,pixdev,fixed)
	     i_img*    im
	       int     fd
	       int     colors
               int     pixdev
	     PREINIT:
             int     rc;
             int     fixedlen;
	     Imager__Color  fixed;
	     Imager__Color  tmp;
	     int len;
	     AV* av;
	     SV* sv1;
             IV  Itmp;
	     int i;
	     CODE:
	     if (!SvROK(ST(4))) croak("Imager: Parameter 4 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(4))) != SVt_PVAV) croak("Imager: Parameter 4 must be a reference to an array\n");
	     av=(AV*)SvRV(ST(4));
	     fixedlen=av_len(av)+1;
	     fixed=mymalloc( fixedlen*sizeof(i_color) );
	     for(i=0;i<fixedlen;i++) {
	       sv1=(*(av_fetch(av,i,0)));
               if (sv_derived_from(sv1, "Imager::Color")) {
                 Itmp = SvIV((SV*)SvRV(sv1));
                 tmp = (i_color*) Itmp;
               } else croak("Imager: one of the elements of array ref is not of Imager::Color type\n");
               fixed[i]=*tmp;
	     }
	     RETVAL=i_writegif(im,fd,colors,pixdev,fixedlen,fixed);
             myfree(fixed);
             ST(0) = sv_newmortal();
             if (RETVAL == 0) ST(0)=&PL_sv_undef;
             else sv_setiv(ST(0), (IV)RETVAL);




undef_int
i_writegifmc(im,fd,colors)
	     i_img*    im
	       int     fd
	       int     colors



i_img*
i_readgif(im,fd)
	     i_img*    im
	       int     fd

#endif




i_img *
i_readppm(im,fd)
	     i_img*    im
	       int     fd

undef_int
i_writeppm(im,fd)
	     i_img*    im
	       int     fd

i_img*
i_readraw(im,fd,x,y,datachannels,storechannels,intrl)
     	     i_img*    im
	       int     fd
	       int     x
	       int     y
	       int     datachannels
	       int     storechannels
	       int     intrl

undef_int
i_writeraw(im,fd)
	     i_img*    im
	       int     fd


i_img*
i_scaleaxis(im,Value,Axis)
       	     i_img*    im
             float     Value
	       int     Axis

i_img*
i_scale_nn(im,scx,scy)
       	     i_img*    im
             float     scx
             float     scy


i_img*
i_transform(im,opx,opy,parm)
	     i_img*    im
	     PREINIT:
	     double* parm;
	     int*    opx;
	     int*    opy;
	     int     opxl;
	     int     opyl;
	     int     parmlen;
	     AV* av;
	     SV* sv1;
	     int i;
             CODE:
	     if (!SvROK(ST(1))) croak("Imager: Parameter 1 must be a reference to an array\n");
	     if (!SvROK(ST(2))) croak("Imager: Parameter 2 must be a reference to an array\n");
	     if (!SvROK(ST(3))) croak("Imager: Parameter 2 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("SuperS: Parameter 1 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(2))) != SVt_PVAV) croak("SuperS: Parameter 2 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(3))) != SVt_PVAV) croak("SuperS: Parameter 3 must be a reference to an array\n");
	     av=(AV*)SvRV(ST(1));
	     opxl=av_len(av)+1;
	     opx=mymalloc( opxl*sizeof(int) );
	     for(i=0;i<opxl;i++) {
	       sv1=(*(av_fetch(av,i,0)));
	       opx[i]=(int)SvIV(sv1);
	     }
	     av=(AV*)SvRV(ST(2));
	     opyl=av_len(av)+1;
	     opy=mymalloc( opyl*sizeof(int) );
	     for(i=0;i<opyl;i++) {
	       sv1=(*(av_fetch(av,i,0)));
	       opy[i]=(int)SvIV(sv1);
	     }
	     av=(AV*)SvRV(ST(3));
	     parmlen=av_len(av)+1;
	     parm=mymalloc( (2+parmlen)*sizeof(int) );
	     for(i=0;i<parmlen;i++) {
	       sv1=(*(av_fetch(av,i,0)));
	       parm[i]=(int)SvNV(sv1);
	     }
	     RETVAL=i_transform(im,opx,opxl,opy,opyl,parm,parmlen+2);
             ST(0) = sv_newmortal();
             if (RETVAL == 0) ST(0)=&PL_sv_undef;
             else sv_setiv(ST(0), (IV)RETVAL);	  


void
i_contrast(im,intensity)
             i_img*     im
             float      intensity

void
i_hardinvert(im)
             i_img*    im

void
i_noise(im,amount,type)
             i_img*     im
             float      amount
     unsigned char      type

void
i_bumpmap(im,bump,channel,light_x,light_y,strength)
             i_img*     im
             i_img*     bump
             int        channel
             int        light_x
             int        light_y
             int        strength

void
i_postlevels(im,levels)
             i_img*     im
             int        levels

void
i_mosaic(im,size)
             i_img*     im
             int        size

void
i_watermark(im,wmark,tx,ty,pixdiff)
             i_img*     im
             i_img*     wmark
             int        tx
             int        ty
             int        pixdiff


void
i_autolevels(im,lsat,usat,skew)
             i_img*     im
             float      lsat
             float      usat
             float      skew

void
i_radnoise(im,xo,yo,rscale,ascale)
             i_img*     im
             float      xo
             float      yo
             float      rscale
             float      ascale

void
i_turbnoise(im,xo,yo,scale)
             i_img*     im
             float      xo
             float      yo
             float      scale



void
malloc_state()

void
hashinfo(hv)
	     PREINIT:
	       HV* hv;
	       int stuff;
	     PPCODE:
	       if (!SvROK(ST(0))) croak("Imager: Parameter 0 must be a reference to a hash\n");	       
	       hv=(HV*)SvRV(ST(0));
	       if (SvTYPE(hv)!=SVt_PVHV) croak("Imager: Parameter 0 must be a reference to a hash\n");
	       if (getint(hv,"stuff",&stuff)) printf("ok: %d\n",stuff); else printf("key doesn't exist\n");
	       if (getint(hv,"stuff2",&stuff)) printf("ok: %d\n",stuff); else printf("key doesn't exist\n");
	       
void
DSO_open(filename)
             char*       filename
	     PREINIT:
	       void *rc;
	       char *evstr;
	     PPCODE:
	       rc=DSO_open(filename,&evstr);
               if (rc!=NULL) {
                 if (evstr!=NULL) {
                   EXTEND(SP,2); 
                   PUSHs(sv_2mortal(newSViv((IV)rc)));
                   PUSHs(sv_2mortal(newSVpvn(evstr, strlen(evstr))));
                 } else {
                   EXTEND(SP,1);
                   PUSHs(sv_2mortal(newSViv((IV)rc)));
                 }
               }


undef_int
DSO_close(dso_handle)
             void*       dso_handle

void
DSO_funclist(dso_handle_v)
             void*       dso_handle_v
	     PREINIT:
	       int i;
	       DSO_handle *dso_handle;
	     PPCODE:
	       dso_handle=(DSO_handle*)dso_handle_v;
	       i=0;
	       while( dso_handle->function_list[i].name != NULL) {
	         EXTEND(SP,1);
		 PUSHs(sv_2mortal(newSVpv(dso_handle->function_list[i].name,0)));
	         EXTEND(SP,1);
		 PUSHs(sv_2mortal(newSVpv(dso_handle->function_list[i++].pcode,0)));
	       }


void
DSO_call(handle,func_index,hv)
	       void*  handle
	       int    func_index
	     PREINIT:
	       HV* hv;
	     PPCODE:
	       if (!SvROK(ST(2))) croak("Imager: Parameter 2 must be a reference to a hash\n");	       
	       hv=(HV*)SvRV(ST(2));
	       if (SvTYPE(hv)!=SVt_PVHV) croak("Imager: Parameter 2 must be a reference to a hash\n");
	       DSO_call( (DSO_handle *)handle,func_index,hv);




