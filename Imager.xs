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
typedef i_img* Imager__ImgRaw;

#ifdef HAVE_LIBTT
typedef TT_Fonthandle* Imager__TTHandle;
#endif

MODULE = Imager		PACKAGE = Imager::Color	PREFIX = ICL_

void
ICL_DESTROY(cl)
               Imager::Color    cl

MODULE = Imager		PACKAGE = Imager::ImgRaw	PREFIX = IIM_

Imager::ImgRaw
IIM_new(x,y,ch)
               int     x
	       int     y
	       int     ch

void
IIM_DESTROY(im)
               Imager::ImgRaw    im


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

Imager::ImgRaw
i_img_new()

Imager::ImgRaw
i_img_empty(im,x,y)
    Imager::ImgRaw     im
               int     x
	       int     y

Imager::ImgRaw
i_img_empty_ch(im,x,y,ch)
    Imager::ImgRaw     im
               int     x
	       int     y
	       int     ch

void
init_log(name,onoff)
	      char*    name
	       int     onoff

void
i_img_exorcise(im)
    Imager::ImgRaw     im

void
i_img_destroy(im)
    Imager::ImgRaw     im

void
i_img_info(im)
    Imager::ImgRaw     im
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
    Imager::ImgRaw     im
	       int     ch_mask

int
i_img_getmask(im)
    Imager::ImgRaw     im

int
i_img_getchannels(im)
    Imager::ImgRaw     im

void
i_draw(im,x1,y1,x2,y2,val)
    Imager::ImgRaw     im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
     Imager::Color     val

void
i_line_aa(im,x1,y1,x2,y2,val)
    Imager::ImgRaw     im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
     Imager::Color     val

void
i_box(im,x1,y1,x2,y2,val)
    Imager::ImgRaw     im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
     Imager::Color     val

void
i_box_filled(im,x1,y1,x2,y2,val)
    Imager::ImgRaw     im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::Color    val

void
i_arc(im,x,y,rad,d1,d2,val)
    Imager::ImgRaw     im
	       int     x
	       int     y
             float     rad
             float     d1
             float     d2
	   Imager::Color    val



void
i_bezier_multi(im,xc,yc,val)
    Imager::ImgRaw     im
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
	     if (!SvROK(ST(2))) croak("Imager: Parameter 2 to i_bezier_multi must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(2))) != SVt_PVAV) croak("Imager: Parameter 2 to i_bezier_multi must be a reference to an array\n");
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
i_poly_aa(im,xc,yc,val)
    Imager::ImgRaw     im
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
             i_poly_aa(im,len,x,y,val);



void
i_copyto(im,src,x1,y1,x2,y2,tx,ty)
    Imager::ImgRaw     im
    Imager::ImgRaw     src
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	       int     tx
	       int     ty


void
i_copyto_trans(im,src,x1,y1,x2,y2,tx,ty,trans)
    Imager::ImgRaw     im
    Imager::ImgRaw     src
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	       int     tx
	       int     ty
     Imager::Color     trans

void
i_copy(im,src)
    Imager::ImgRaw     im
    Imager::ImgRaw     src


void
i_rubthru(im,src,tx,ty)
    Imager::ImgRaw     im
    Imager::ImgRaw     src
	       int     tx
	       int     ty


void
i_gaussian(im,stdev)
    Imager::ImgRaw     im
	     float     stdev

void
i_conv(im,pcoef)
    Imager::ImgRaw     im
	     PREINIT:
	     float*    coeff;
	     int     len;
	     AV* av;
	     SV* sv1;
	     int i;
	     PPCODE:
	     if (!SvROK(ST(1))) croak("Imager: Parameter 1 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("Imager: Parameter 1 must be a reference to an array\n");
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
    Imager::ImgRaw     im1
    Imager::ImgRaw     im2



undef_int	  
i_init_fonts()

#ifdef HAVE_LIBT1

void
i_t1_set_aa(st)
      	       int     st

int
i_t1_new(pfb,afm=NULL)
       	      char*    pfb
       	      char*    afm

int
i_t1_destroy(font_id)
       	       int     font_id


undef_int
i_t1_cp(im,xb,yb,channel,fontnum,points,str,len,align)
    Imager::ImgRaw     im
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
    Imager::ImgRaw     im
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


Imager::TTHandle
i_tt_new(fontname)
	      char*     fontname

void
i_tt_destroy(handle)
     Imager::TTHandle    handle



undef_int
i_tt_text(handle,im,xb,yb,cl,points,str,len,smooth)
  Imager::TTHandle     handle
    Imager::ImgRaw     im
	       int     xb
	       int     yb
     Imager::Color     cl
             float     points
	      char*    str
	       int     len
	       int     smooth


undef_int
i_tt_cp(handle,im,xb,yb,channel,points,str,len,smooth)
  Imager::TTHandle     handle
    Imager::ImgRaw     im
	       int     xb
	       int     yb
	       int     channel
             float     points
	      char*    str
	       int     len
	       int     smooth



undef_int
i_tt_bbox(handle,point,str,len)
  Imager::TTHandle     handle
	     float     point
	      char*    str
	       int     len
	     PREINIT:
	       int     cords[4],rc;
	     PPCODE:
  	       if (rc=i_tt_bbox(handle,point,str,len,cords)) {
                 EXTEND(SP, 4);
                 PUSHs(sv_2mortal(newSViv(cords[0])));
                 PUSHs(sv_2mortal(newSViv(cords[1])));
                 PUSHs(sv_2mortal(newSViv(cords[2])));
                 PUSHs(sv_2mortal(newSViv(cords[3])));
               }


#endif 




#ifdef HAVE_LIBJPEG
undef_int
i_writejpeg(im,fd,qfactor)
    Imager::ImgRaw     im
	       int     fd
	       int     qfactor

void
i_readjpeg(fd)
	       int     fd
	     PREINIT:
	      char*    iptc_itext;
	       int     tlength;
	     i_img*    rimg;
                SV*    r;
	     PPCODE:
 	      iptc_itext=NULL;
	      rimg=i_readjpeg(fd,&iptc_itext,&tlength);
	      if (iptc_itext == NULL) {
		    r = sv_newmortal();
	            EXTEND(SP,1);
	            sv_setref_pv(r, "Imager::ImgRaw", (void*)rimg);
 		    PUSHs(r);
	      } else {
		    r = sv_newmortal();
	            EXTEND(SP,2);
	            sv_setref_pv(r, "Imager::ImgRaw", (void*)rimg);
 		    PUSHs(r);
		    PUSHs(sv_2mortal(newSVpv(iptc_itext,tlength)));
                    myfree(iptc_itext);
	      }

#endif


#ifdef HAVE_LIBPNG

Imager::ImgRaw
i_readpng(fd)
	       int     fd

undef_int
i_writepng(im,fd)
    Imager::ImgRaw     im
	       int     fd

#endif


#ifdef HAVE_LIBGIF

undef_int
i_writegif(im,fd,colors,pixdev,fixed)
    Imager::ImgRaw     im
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
    Imager::ImgRaw     im
	       int     fd
	       int     colors

undef_int
i_writegifex(im,fd)
    Imager::ImgRaw     im
	       int     fd


void
i_readgif(fd)
	       int     fd
	    PREINIT:
	        int*    colour_table;
	        int     colours, q, w;
	      i_img*    rimg;
             SV*    temp[3];
             AV*    ct; 
             SV*    r;
	    PPCODE:
 	      colour_table=NULL;
               colours=0;

        if(GIMME_V == G_ARRAY) {  
            rimg=i_readgif(fd,&colour_table,&colours);
        } else {
            /* don't waste time with colours if they aren't wanted */
            rimg=i_readgif(fd,NULL,NULL);
        }

	if (colour_table == NULL) {
            EXTEND(SP,1);
            r=sv_newmortal();
            sv_setref_pv(r, "Imager::ImgRaw", (void*)rimg);
            PUSHs(r);
	} else {
            /* the following creates an [[r,g,b], [r, g, b], [r, g, b]...] */
            /* I don't know if I have the reference counts right or not :( */
            /* Neither do I :-) */
            ct=newAV();
            av_extend(ct, colours);
            for(q=0; q<colours; q++) {
                for(w=0; w<3; w++)
                    temp[w]=sv_2mortal(newSViv(colour_table[q*3 + w]));
                av_store(ct, q, (SV*)newRV_noinc((SV*)av_make(3, temp)));
            }
            myfree(colour_table);
            
            EXTEND(SP,2);
            r=sv_newmortal();
            sv_setref_pv(r, "Imager::ImgRaw", (void*)rimg);
            PUSHs(r);
            PUSHs(newRV_noinc((SV*)ct));
        }

#endif




Imager::ImgRaw
i_readppm(fd)
	       int     fd

undef_int
i_writeppm(im,fd)
    Imager::ImgRaw     im
	       int     fd

Imager::ImgRaw
i_readraw(fd,x,y,datachannels,storechannels,intrl)
	       int     fd
	       int     x
	       int     y
	       int     datachannels
	       int     storechannels
	       int     intrl

undef_int
i_writeraw(im,fd)
    Imager::ImgRaw     im
	       int     fd


Imager::ImgRaw
i_scaleaxis(im,Value,Axis)
    Imager::ImgRaw     im
             float     Value
	       int     Axis

Imager::ImgRaw
i_scale_nn(im,scx,scy)
    Imager::ImgRaw     im
             float     scx
             float     scy

Imager::ImgRaw
i_haar(im)
    Imager::ImgRaw     im

int
i_count_colors(im,maxc)
    Imager::ImgRaw     im
               int     maxc

Imager::ImgRaw
i_transform(im,opx,opy,parm)
    Imager::ImgRaw     im
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
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("Imager: Parameter 1 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(2))) != SVt_PVAV) croak("Imager: Parameter 2 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(3))) != SVt_PVAV) croak("Imager: Parameter 3 must be a reference to an array\n");
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
             else sv_setref_pv(ST(0), "Imager::ImgRaw", (void*)RETVAL);


void
i_contrast(im,intensity)
    Imager::ImgRaw     im
             float     intensity

void
i_hardinvert(im)
    Imager::ImgRaw     im

void
i_noise(im,amount,type)
    Imager::ImgRaw     im
             float     amount
     unsigned char     type

void
i_bumpmap(im,bump,channel,light_x,light_y,strength)
    Imager::ImgRaw     im
    Imager::ImgRaw     bump
               int     channel
               int     light_x
               int     light_y
               int     strength

void
i_postlevels(im,levels)
    Imager::ImgRaw     im
             int       levels

void
i_mosaic(im,size)
    Imager::ImgRaw     im
               int     size

void
i_watermark(im,wmark,tx,ty,pixdiff)
    Imager::ImgRaw     im
    Imager::ImgRaw     wmark
               int     tx
               int     ty
               int     pixdiff


void
i_autolevels(im,lsat,usat,skew)
    Imager::ImgRaw     im
             float     lsat
             float     usat
             float     skew

void
i_radnoise(im,xo,yo,rscale,ascale)
    Imager::ImgRaw     im
             float     xo
             float     yo
             float     rscale
             float     ascale

void
i_turbnoise(im,xo,yo,scale)
    Imager::ImgRaw     im
             float     xo
             float     yo
             float     scale



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




