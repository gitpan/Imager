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

MODULE = Imager		PACKAGE = Imager		

PROTOTYPES: ENABLE

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

i_color*
i_color_set(cl,r,g,b,a)
	   i_color*    cl
     unsigned char     r
     unsigned char     g
     unsigned char     b
     unsigned char     a

void
i_color_info(cl)
	   i_color*    cl

void
i_draw(im,x1,y1,x2,y2,val)
	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   i_color*    val

void
i_box(im,x1,y1,x2,y2,val)
    	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   i_color*    val

void
i_box_filled(im,x1,y1,x2,y2,val)
    	     i_img*    im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   i_color*    val

void
i_arc(im,x,y,rad,d1,d2,val)
       	     i_img*    im
	       int     x
	       int     y
             float     rad
             float     d1
             float     d2
	   i_color*    val

void
i_copyto(im,src,x1,y1,x2,y2,tx,ty,trans)
    	     i_img*    im
    	     i_img*    src
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	       int     tx
	       int     ty
	   i_color*    trans

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
	   i_color*    cl
	       int     fontnum
             float     points
	      char*    str
	       int     len
	       int     align

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
i_writegif(im,fd,colors)
	     i_img*    im
	       int     fd
	       int     colors

i_img*
i_readgif(im,fd)
	     i_img*    im
	       int     fd

#endif

#ifdef DEVEL_SHIT

void
i_qdist(im)
	     i_img*    im

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
	       EXTEND(SP,2);
	       PUSHs(sv_2mortal(newSViv((IV)rc)));
	       if (evstr!=NULL) PUSHs(sv_2mortal(newSVpvn(evstr, strlen(evstr))));


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




