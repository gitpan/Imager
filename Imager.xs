#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#ifdef __cplusplus

#endif

#include "image.h"
#include "feat.h"
#include "dynaload.h"
#include "regmach.h"

typedef io_glue* Imager__IO;
typedef i_color* Imager__Color;
typedef i_fcolor* Imager__Color__Float;
typedef i_img*   Imager__ImgRaw;


#ifdef HAVE_LIBTT
typedef TT_Fonthandle* Imager__Font__TT;
#endif

#ifdef HAVE_FT2
typedef FT2_Fonthandle* Imager__Font__FT2;
#endif


void my_SvREFCNT_dec(void *p) {
  SvREFCNT_dec((SV*)p);
}


void
log_entry(char *string, int level) {
  mm_log((level, string));
}


typedef struct i_reader_data_tag
{
  /* presumably a CODE ref or name of a sub */
  SV *sv;
} i_reader_data;

/* used by functions that want callbacks */
static int read_callback(char *userdata, char *buffer, int need, int want) {
  i_reader_data *rd = (i_reader_data *)userdata;
  int count;
  int result;
  SV *data;
  dSP; dTARG = sv_newmortal();
  /* thanks to Simon Cozens for help with the dTARG above */

  ENTER;
  SAVETMPS;
  EXTEND(SP, 2);
  PUSHMARK(SP);
  PUSHi(want);
  PUSHi(need);
  PUTBACK;

  count = perl_call_sv(rd->sv, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Result of perl_call_sv(..., G_SCALAR) != 1");

  data = POPs;

  if (SvOK(data)) {
    STRLEN len;
    char *ptr = SvPV(data, len);
    if (len > want)
      croak("Too much data returned in reader callback");
    
    memcpy(buffer, ptr, len);
    result = len;
  }
  else {
    result = -1;
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  return result;
}

typedef struct
{
  SV *sv; /* a coderef or sub name */
} i_writer_data;

/* used by functions that want callbacks */
static int write_callback(char *userdata, char const *data, int size) {
  i_writer_data *wd = (i_writer_data *)userdata;
  int count;
  int success;
  SV *sv;
  dSP; 

  ENTER;
  SAVETMPS;
  EXTEND(SP, 1);
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSVpv((char *)data, size)));
  PUTBACK;

  count = perl_call_sv(wd->sv, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Result of perl_call_sv(..., G_SCALAR) != 1");

  sv = POPs;
  success = SvTRUE(sv);


  PUTBACK;
  FREETMPS;
  LEAVE;

  return success;
}

struct value_name {
  char *name;
  int value;
};
static int lookup_name(struct value_name *names, int count, char *name, int def_value)
{
  int i;
  for (i = 0; i < count; ++i)
    if (strEQ(names[i].name, name))
      return names[i].value;

  return def_value;
}
static struct value_name transp_names[] =
{
  { "none", tr_none },
  { "threshold", tr_threshold },
  { "errdiff", tr_errdiff },
  { "ordered", tr_ordered, },
};

static struct value_name make_color_names[] =
{
  { "none", mc_none, },
  { "webmap", mc_web_map, },
  { "addi", mc_addi, },
};

static struct value_name translate_names[] =
{
#ifdef HAVE_LIBGIF
  { "giflib", pt_giflib, },
#endif
  { "closest", pt_closest, },
  { "perturb", pt_perturb, },
  { "errdiff", pt_errdiff, },
};

static struct value_name errdiff_names[] =
{
  { "floyd", ed_floyd, },
  { "jarvis", ed_jarvis, },
  { "stucki", ed_stucki, },
  { "custom", ed_custom, },
};

static struct value_name orddith_names[] =
{
  { "random", od_random, },
  { "dot8", od_dot8, },
  { "dot4", od_dot4, },
  { "hline", od_hline, },
  { "vline", od_vline, },
  { "/line", od_slashline, },
  { "slashline", od_slashline, },
  { "\\line", od_backline, },
  { "backline", od_backline, },
  { "tiny", od_tiny, },
  { "custom", od_custom, },
};

static int
hv_fetch_bool(HV *hv, char *name, int def) {
  SV **sv;

  sv = hv_fetch(hv, name, strlen(name), 0);
  if (sv && *sv) {
    return SvTRUE(*sv);
  }
  else
    return def;
}

static int
hv_fetch_int(HV *hv, char *name, int def) {
  SV **sv;

  sv = hv_fetch(hv, name, strlen(name), 0);
  if (sv && *sv) {
    return SvIV(*sv);
  }
  else
    return def;
}

/* look through the hash for quantization options */
static void handle_quant_opts(i_quantize *quant, HV *hv)
{
  /*** POSSIBLY BROKEN: do I need to unref the SV from hv_fetch ***/
  SV **sv;
  int i;
  STRLEN len;
  char *str;

  quant->mc_colors = mymalloc(quant->mc_size * sizeof(i_color));

  sv = hv_fetch(hv, "transp", 6, 0);
  if (sv && *sv && (str = SvPV(*sv, len))) {
    quant->transp = 
      lookup_name(transp_names, sizeof(transp_names)/sizeof(*transp_names), 
		  str, tr_none);
    if (quant->transp != tr_none) {
      quant->tr_threshold = 127;
      sv = hv_fetch(hv, "tr_threshold", 12, 0);
      if (sv && *sv)
	quant->tr_threshold = SvIV(*sv);
    }
    if (quant->transp == tr_errdiff) {
      sv = hv_fetch(hv, "tr_errdiff", 10, 0);
      if (sv && *sv && (str = SvPV(*sv, len)))
	quant->tr_errdiff = lookup_name(errdiff_names, sizeof(errdiff_names)/sizeof(*errdiff_names), str, ed_floyd);
    }
    if (quant->transp == tr_ordered) {
      quant->tr_orddith = od_tiny;
      sv = hv_fetch(hv, "tr_orddith", 10, 0);
      if (sv && *sv && (str = SvPV(*sv, len)))
	quant->tr_orddith = lookup_name(orddith_names, sizeof(orddith_names)/sizeof(*orddith_names), str, od_random);

      if (quant->tr_orddith == od_custom) {
	sv = hv_fetch(hv, "tr_map", 6, 0);
	if (sv && *sv && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
	  AV *av = (AV*)SvRV(*sv);
	  len = av_len(av) + 1;
	  if (len > sizeof(quant->tr_custom))
	    len = sizeof(quant->tr_custom);
	  for (i = 0; i < len; ++i) {
	    SV **sv2 = av_fetch(av, i, 0);
	    if (sv2 && *sv2) {
	      quant->tr_custom[i] = SvIV(*sv2);
	    }
	  }
	  while (i < sizeof(quant->tr_custom))
	    quant->tr_custom[i++] = 0;
	}
      }
    }
  }
  quant->make_colors = mc_addi;
  sv = hv_fetch(hv, "make_colors", 11, 0);
  if (sv && *sv && (str = SvPV(*sv, len))) {
    quant->make_colors = 
      lookup_name(make_color_names, sizeof(make_color_names)/sizeof(*make_color_names), str, mc_addi);
  }
  sv = hv_fetch(hv, "colors", 6, 0);
  if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
    /* needs to be an array of Imager::Color
       note that the caller allocates the mc_color array and sets mc_size
       to it's size */
    AV *av = (AV *)SvRV(*sv);
    quant->mc_count = av_len(av)+1;
    if (quant->mc_count > quant->mc_size)
      quant->mc_count = quant->mc_size;
    for (i = 0; i < quant->mc_count; ++i) {
      SV **sv1 = av_fetch(av, i, 0);
      if (sv1 && *sv1 && SvROK(*sv1) && sv_derived_from(*sv1, "Imager::Color")) {
	i_color *col = (i_color *)SvIV((SV*)SvRV(*sv1));
	quant->mc_colors[i] = *col;
      }
    }
  }
  sv = hv_fetch(hv, "max_colors", 10, 0);
  if (sv && *sv) {
    i = SvIV(*sv);
    if (i <= quant->mc_size && i >= quant->mc_count)
      quant->mc_size = i;
  }

  quant->translate = pt_closest;
  sv = hv_fetch(hv, "translate", 9, 0);
  if (sv && *sv && (str = SvPV(*sv, len))) {
    quant->translate = lookup_name(translate_names, sizeof(translate_names)/sizeof(*translate_names), str, pt_closest);
  }
  sv = hv_fetch(hv, "errdiff", 7, 0);
  if (sv && *sv && (str = SvPV(*sv, len))) {
    quant->errdiff = lookup_name(errdiff_names, sizeof(errdiff_names)/sizeof(*errdiff_names), str, ed_floyd);
  }
  if (quant->translate == pt_errdiff && quant->errdiff == ed_custom) {
    /* get the error diffusion map */
    sv = hv_fetch(hv, "errdiff_width", 13, 0);
    if (sv && *sv)
      quant->ed_width = SvIV(*sv);
    sv = hv_fetch(hv, "errdiff_height", 14, 0);
    if (sv && *sv)
      quant->ed_height = SvIV(*sv);
    sv = hv_fetch(hv, "errdiff_orig", 12, 0);
    if (sv && *sv)
      quant->ed_orig = SvIV(*sv);
    if (quant->ed_width > 0 && quant->ed_height > 0) {
      int sum = 0;
      quant->ed_map = mymalloc(sizeof(int)*quant->ed_width*quant->ed_height);
      sv = hv_fetch(hv, "errdiff_map", 11, 0);
      if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
	AV *av = (AV*)SvRV(*sv);
	len = av_len(av) + 1;
	if (len > quant->ed_width * quant->ed_height)
	  len = quant->ed_width * quant->ed_height;
	for (i = 0; i < len; ++i) {
	  SV **sv2 = av_fetch(av, i, 0);
	  if (sv2 && *sv2) {
	    quant->ed_map[i] = SvIV(*sv2);
	    sum += quant->ed_map[i];
	  }
	}
      }
      if (!sum) {
	/* broken map */
	myfree(quant->ed_map);
	quant->ed_map = 0;
	quant->errdiff = ed_floyd;
      }
    }
  }
  sv = hv_fetch(hv, "perturb", 7, 0);
  if (sv && *sv)
    quant->perturb = SvIV(*sv);
}

static void cleanup_quant_opts(i_quantize *quant) {
  myfree(quant->mc_colors);
  if (quant->ed_map)
    myfree(quant->ed_map);
}

/* look through the hash for options to add to opts */
static void handle_gif_opts(i_gif_opts *opts, HV *hv)
{
  SV **sv;
  int i;
  /**((char *)0) = '\0';*/
  opts->each_palette = hv_fetch_bool(hv, "gif_each_palette", 0);
  opts->interlace = hv_fetch_bool(hv, "interlace", 0);

  sv = hv_fetch(hv, "gif_delays", 10, 0);
  if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
    AV *av = (AV*)SvRV(*sv);
    opts->delay_count = av_len(av)+1;
    opts->delays = mymalloc(sizeof(int) * opts->delay_count);
    for (i = 0; i < opts->delay_count; ++i) {
      SV *sv1 = *av_fetch(av, i, 0);
      opts->delays[i] = SvIV(sv1);
    }
  }
  sv = hv_fetch(hv, "gif_user_input", 14, 0);
  if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
    AV *av = (AV*)SvRV(*sv);
    opts->user_input_count = av_len(av)+1;
    opts->user_input_flags = mymalloc(opts->user_input_count);
    for (i = 0; i < opts->user_input_count; ++i) {
      SV *sv1 = *av_fetch(av, i, 0);
      opts->user_input_flags[i] = SvIV(sv1) != 0;
    }
  }
  sv = hv_fetch(hv, "gif_disposal", 12, 0);
  if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
    AV *av = (AV*)SvRV(*sv);
    opts->disposal_count = av_len(av)+1;
    opts->disposal = mymalloc(opts->disposal_count);
    for (i = 0; i < opts->disposal_count; ++i) {
      SV *sv1 = *av_fetch(av, i, 0);
      opts->disposal[i] = SvIV(sv1);
    }
  }
  sv = hv_fetch(hv, "gif_tran_color", 14, 0);
  if (sv && *sv && SvROK(*sv) && sv_derived_from(*sv, "Imager::Color")) {
    i_color *col = (i_color *)SvIV((SV *)SvRV(*sv));
    opts->tran_color = *col;
  }
  sv = hv_fetch(hv, "gif_positions", 13, 0);
  if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
    AV *av = (AV *)SvRV(*sv);
    opts->position_count = av_len(av) + 1;
    opts->positions = mymalloc(sizeof(i_gif_pos) * opts->position_count);
    for (i = 0; i < opts->position_count; ++i) {
      SV **sv2 = av_fetch(av, i, 0);
      opts->positions[i].x = opts->positions[i].y = 0;
      if (sv && *sv && SvROK(*sv) && SvTYPE(SvRV(*sv)) == SVt_PVAV) {
	AV *av2 = (AV*)SvRV(*sv2);
	SV **sv3;
	sv3 = av_fetch(av2, 0, 0);
	if (sv3 && *sv3)
	  opts->positions[i].x = SvIV(*sv3);
	sv3 = av_fetch(av2, 1, 0);
	if (sv3 && *sv3)
	  opts->positions[i].y = SvIV(*sv3);
      }
    }
  }
  /* Netscape2.0 loop count extension */
  opts->loop_count = hv_fetch_int(hv, "gif_loop_count", 0);

  opts->eliminate_unused = hv_fetch_bool(hv, "gif_eliminate_unused", 1);
}

static void cleanup_gif_opts(i_gif_opts *opts) {
  if (opts->delays)
    myfree(opts->delays);
  if (opts->user_input_flags)
    myfree(opts->user_input_flags);
  if (opts->disposal)
    myfree(opts->disposal);
  if (opts->positions) 
    myfree(opts->positions);
}

/* copies the color map from the hv into the colors member of the HV */
static void copy_colors_back(HV *hv, i_quantize *quant) {
  SV **sv;
  AV *av;
  int i;
  SV *work;

  sv = hv_fetch(hv, "colors", 6, 0);
  if (!sv || !*sv || !SvROK(*sv) || SvTYPE(SvRV(*sv)) != SVt_PVAV) {
    SV *ref;
    av = newAV();
    ref = newRV_inc((SV*) av);
    sv = hv_store(hv, "colors", 6, ref, 0);
  }
  else {
    av = (AV *)SvRV(*sv);
  }
  av_extend(av, quant->mc_count+1);
  for (i = 0; i < quant->mc_count; ++i) {
    i_color *in = quant->mc_colors+i;
    Imager__Color c = ICL_new_internal(in->rgb.r, in->rgb.g, in->rgb.b, 255);
    work = sv_newmortal();
    sv_setref_pv(work, "Imager::Color", (void *)c);
    SvREFCNT_inc(work);
    if (!av_store(av, i, work)) {
      SvREFCNT_dec(work);
    }
  }
}

/* loads the segments of a fountain fill into an array */
i_fountain_seg *load_fount_segs(AV *asegs, int *count) {
  /* Each element of segs must contain:
     [ start, middle, end, c0, c1, segtype, colortrans ]
     start, middle, end are doubles from 0 to 1
     c0, c1 are Imager::Color::Float or Imager::Color objects
     segtype, colortrans are ints
  */
  int i, j;
  AV *aseg;
  SV *sv;
  i_fountain_seg *segs;
  double work[3];
  int worki[2];

  *count = av_len(asegs)+1;
  if (*count < 1) 
    croak("i_fountain must have at least one segment");
  segs = mymalloc(sizeof(i_fountain_seg) * *count);
  for(i = 0; i < *count; i++) {
    SV **sv1 = av_fetch(asegs, i, 0);
    if (!sv1 || !*sv1 || !SvROK(*sv1) 
        || SvTYPE(SvRV(*sv1)) != SVt_PVAV) {
      myfree(segs);
      croak("i_fountain: segs must be an arrayref of arrayrefs");
    }
    aseg = (AV *)SvRV(*sv1);
    if (av_len(aseg) != 7-1) {
      myfree(segs);
      croak("i_fountain: a segment must have 7 members");
    }
    for (j = 0; j < 3; ++j) {
      SV **sv2 = av_fetch(aseg, j, 0);
      if (!sv2 || !*sv2) {
        myfree(segs);
        croak("i_fountain: XS error");
      }
      work[j] = SvNV(*sv2);
    }
    segs[i].start  = work[0];
    segs[i].middle = work[1];
    segs[i].end    = work[2];
    for (j = 0; j < 2; ++j) {
      SV **sv3 = av_fetch(aseg, 3+j, 0);
      if (!sv3 || !*sv3 || !SvROK(*sv3) ||
          (!sv_derived_from(*sv3, "Imager::Color")
           && !sv_derived_from(*sv3, "Imager::Color::Float"))) {
        myfree(segs);
        croak("i_fountain: segs must contain colors in elements 3 and 4");
      }
      if (sv_derived_from(*sv3, "Imager::Color::Float")) {
        segs[i].c[j] = *(i_fcolor *)SvIV((SV *)SvRV(*sv3));
      }
      else {
        i_color c = *(i_color *)SvIV((SV *)SvRV(*sv3));
        int ch;
        for (ch = 0; ch < MAXCHANNELS; ++ch) {
          segs[i].c[j].channel[ch] = c.channel[ch] / 255.0;
        }
      }
    }
    for (j = 0; j < 2; ++j) {
      SV **sv2 = av_fetch(aseg, j+5, 0);
      if (!sv2 || !*sv2) {
        myfree(segs);
        croak("i_fountain: XS error");
      }
      worki[j] = SvIV(*sv2);
    }
    segs[i].type = worki[0];
    segs[i].color = worki[1];
  }

  return segs;
}

/* I don't think ICLF_* names belong at the C interface
   this makes the XS code think we have them, to let us avoid 
   putting function bodies in the XS code
*/
#define ICLF_new_internal(r, g, b, a) i_fcolor_new((r), (g), (b), (a))
#define ICLF_DESTROY(cl) i_fcolor_destroy(cl)

/* for the fill objects
   Since a fill object may later have dependent images, (or fills!)
   we need perl wrappers - oh well
*/
#define IFILL_DESTROY(fill) i_fill_destroy(fill);
typedef i_fill_t* Imager__FillHandle;

MODULE = Imager		PACKAGE = Imager::Color	PREFIX = ICL_

Imager::Color
ICL_new_internal(r,g,b,a)
               unsigned char     r
               unsigned char     g
               unsigned char     b
               unsigned char     a

void
ICL_DESTROY(cl)
               Imager::Color    cl


void
ICL_set_internal(cl,r,g,b,a)
               Imager::Color    cl
               unsigned char     r
               unsigned char     g
               unsigned char     b
               unsigned char     a
	   PPCODE:
	       ICL_set_internal(cl, r, g, b, a);
	       EXTEND(SP, 1);
	       PUSHs(ST(0));

void
ICL_info(cl)
               Imager::Color    cl


void
ICL_rgba(cl)
	      Imager::Color	cl
	    PPCODE:
		EXTEND(SP, 4);
		PUSHs(sv_2mortal(newSVnv(cl->rgba.r)));
		PUSHs(sv_2mortal(newSVnv(cl->rgba.g)));
		PUSHs(sv_2mortal(newSVnv(cl->rgba.b)));
		PUSHs(sv_2mortal(newSVnv(cl->rgba.a)));

Imager::Color
i_hsv_to_rgb(c)
        Imager::Color c
      CODE:
        RETVAL = mymalloc(sizeof(i_color));
        *RETVAL = *c;
        i_hsv_to_rgb(RETVAL);
      OUTPUT:
        RETVAL
        
Imager::Color
i_rgb_to_hsv(c)
        Imager::Color c
      CODE:
        RETVAL = mymalloc(sizeof(i_color));
        *RETVAL = *c;
        i_rgb_to_hsv(RETVAL);
      OUTPUT:
        RETVAL
        


MODULE = Imager        PACKAGE = Imager::Color::Float  PREFIX=ICLF_

Imager::Color::Float
ICLF_new_internal(r, g, b, a)
        double r
        double g
        double b
        double a

void
ICLF_DESTROY(cl)
        Imager::Color::Float    cl

void
ICLF_rgba(cl)
        Imager::Color::Float    cl
      PREINIT:
        int ch;
      PPCODE:
        EXTEND(SP, MAXCHANNELS);
        for (ch = 0; ch < MAXCHANNELS; ++ch) {
        /* printf("%d: %g\n", ch, cl->channel[ch]); */
          PUSHs(sv_2mortal(newSVnv(cl->channel[ch])));
        }

void
ICLF_set_internal(cl,r,g,b,a)
        Imager::Color::Float    cl
        double     r
        double     g
        double     b
        double     a
      PPCODE:
        cl->rgba.r = r;
        cl->rgba.g = g;
        cl->rgba.b = b;
        cl->rgba.a = a;                
        EXTEND(SP, 1);
        PUSHs(ST(0));

Imager::Color::Float
i_hsv_to_rgb(c)
        Imager::Color::Float c
      CODE:
        RETVAL = mymalloc(sizeof(i_fcolor));
        *RETVAL = *c;
        i_hsv_to_rgbf(RETVAL);
      OUTPUT:
        RETVAL
        
Imager::Color::Float
i_rgb_to_hsv(c)
        Imager::Color::Float c
      CODE:
        RETVAL = mymalloc(sizeof(i_fcolor));
        *RETVAL = *c;
        i_rgb_to_hsvf(RETVAL);
      OUTPUT:
        RETVAL
        

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


Imager::IO
io_new_fd(fd)
                         int     fd

Imager::IO
io_new_bufchain()


Imager::IO
io_new_buffer(data)
	  char   *data
	PREINIT:
	  size_t length;
	  SV* sv;
	CODE:
	  SvPV(ST(0), length);
          SvREFCNT_inc(ST(0));
	  RETVAL = io_new_buffer(data, length, my_SvREFCNT_dec, ST(0));
        OUTPUT:
          RETVAL
	

void
io_slurp(ig)
        Imager::IO     ig
	     PREINIT:
	      unsigned char*    data;
	      size_t    tlength;
	     PPCODE:
 	      data    = NULL;
              tlength = io_slurp(ig, &data);
              EXTEND(SP,1);
              PUSHs(sv_2mortal(newSVpv(data,tlength)));
              myfree(data);


MODULE = Imager		PACKAGE = Imager::IO	PREFIX = io_glue_

void
io_glue_DESTROY(ig)
        Imager::IO     ig


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
init_log(name,level)
	      char*    name
	       int     level

void
log_entry(string,level)
	      char*    string
	       int     level


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
i_img_getdata(im)
    Imager::ImgRaw     im
             PPCODE:
	       EXTEND(SP, 1);
               PUSHs(im->idata ? sv_2mortal(newSVpv(im->idata, im->bytes)) 
		     : &PL_sv_undef);


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
i_box_cfill(im,x1,y1,x2,y2,fill)
    Imager::ImgRaw     im
	       int     x1
	       int     y1
	       int     x2
	       int     y2
	   Imager::FillHandle    fill

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
i_arc_cfill(im,x,y,rad,d1,d2,fill)
    Imager::ImgRaw     im
	       int     x
	       int     y
             float     rad
             float     d1
             float     d2
	   Imager::FillHandle    fill



void
i_circle_aa(im,x,y,rad,val)
    Imager::ImgRaw     im
	     float     x
	     float     y
             float     rad
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
	     ICL_info(val);
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
             myfree(x);
             myfree(y);


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
	     ICL_info(val);
	     if (!SvROK(ST(1))) croak("Imager: Parameter 1 to i_poly_aa must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(1))) != SVt_PVAV) croak("Imager: Parameter 1 to i_poly_aa must be a reference to an array\n");
	     if (!SvROK(ST(2))) croak("Imager: Parameter 1 to i_poly_aa must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(2))) != SVt_PVAV) croak("Imager: Parameter 1 to i_poly_aa must be a reference to an array\n");
	     av1=(AV*)SvRV(ST(1));
	     av2=(AV*)SvRV(ST(2));
	     if (av_len(av1) != av_len(av2)) croak("Imager: x and y arrays to i_poly_aa must be equal length\n");
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
             myfree(x);
             myfree(y);



void
i_flood_fill(im,seedx,seedy,dcol)
    Imager::ImgRaw     im
	       int     seedx
	       int     seedy
     Imager::Color     dcol

void
i_flood_cfill(im,seedx,seedy,fill)
    Imager::ImgRaw     im
	       int     seedx
	       int     seedy
     Imager::FillHandle     fill


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


undef_int
i_rubthru(im,src,tx,ty)
    Imager::ImgRaw     im
    Imager::ImgRaw     src
	       int     tx
	       int     ty

undef_int
i_flipxy(im, direction)
    Imager::ImgRaw     im
	       int     direction

Imager::ImgRaw
i_rotate90(im, degrees)
    Imager::ImgRaw      im
               int      degrees

Imager::ImgRaw
i_rotate_exact(im, amount)
    Imager::ImgRaw      im
            double      amount

Imager::ImgRaw
i_matrix_transform(im, xsize, ysize, matrix)
    Imager::ImgRaw      im
               int      xsize
               int      ysize
      PREINIT:
        double matrix[9];
        AV *av;
        IV len;
        SV *sv1;
        int i;
      CODE:
        if (!SvROK(ST(3)) || SvTYPE(SvRV(ST(3))) != SVt_PVAV)
          croak("i_matrix_transform: parameter 4 must be an array ref\n");
	av=(AV*)SvRV(ST(3));
	len=av_len(av)+1;
        if (len > 9)
          len = 9;
        for (i = 0; i < len; ++i) {
	  sv1=(*(av_fetch(av,i,0)));
	  matrix[i] = SvNV(sv1);
        }
        for (; i < 9; ++i)
          matrix[i] = 0;
        RETVAL = i_matrix_transform(im, xsize, ysize, matrix);        
      OUTPUT:
        RETVAL

void
i_gaussian(im,stdev)
    Imager::ImgRaw     im
	     float     stdev

void
i_unsharp_mask(im,stdev,scale)
    Imager::ImgRaw     im
	     float     stdev
             double    scale

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
	     myfree(coeff);

undef_int
i_convert(im, src, coeff)
    Imager::ImgRaw     im
    Imager::ImgRaw     src
	PREINIT:
    	  float *coeff;
	  int outchan;
	  int inchan;
	  AV *avmain;
          SV **temp;
	  SV *svsub;
          AV *avsub;
	  int len;
	  int i, j;
        CODE:
	  if (!SvROK(ST(2)) || SvTYPE(SvRV(ST(2))) != SVt_PVAV)
	    croak("i_convert: parameter 3 must be an arrayref\n");
          avmain = (AV*)SvRV(ST(2));
	  outchan = av_len(avmain)+1;
          /* find the biggest */
          inchan = 0;
	  for (j=0; j < outchan; ++j) {
	    temp = av_fetch(avmain, j, 0);
	    if (temp && SvROK(*temp) && SvTYPE(SvRV(*temp)) == SVt_PVAV) {
	      avsub = (AV*)SvRV(*temp);
	      len = av_len(avsub)+1;
	      if (len > inchan)
		inchan = len;
	    }
          }
          coeff = mymalloc(sizeof(float) * outchan * inchan);
	  for (j = 0; j < outchan; ++j) {
	    avsub = (AV*)SvRV(*av_fetch(avmain, j, 0));
	    len = av_len(avsub)+1;
	    for (i = 0; i < len; ++i) {
	      temp = av_fetch(avsub, i, 0);
	      if (temp)
		coeff[i+j*inchan] = SvNV(*temp);
	      else
	 	coeff[i+j*inchan] = 0;
	    }
	    while (i < inchan)
	      coeff[i++ + j*inchan] = 0;
	  }
	  RETVAL = i_convert(im, src, coeff, outchan, inchan);
          myfree(coeff);
	OUTPUT:
	  RETVAL


void
i_map(im, pmaps)
    Imager::ImgRaw     im
	PREINIT:
	  unsigned int mask = 0;
	  AV *avmain;
	  AV *avsub;
          SV **temp;
	  int len;
	  int i, j;
	  unsigned char (*maps)[256];
        CODE:
	  if (!SvROK(ST(1)) || SvTYPE(SvRV(ST(1))) != SVt_PVAV)
	    croak("i_map: parameter 2 must be an arrayref\n");
          avmain = (AV*)SvRV(ST(1));
	  len = av_len(avmain)+1;
	  if (im->channels < len) len = im->channels;

	  maps = mymalloc( len * sizeof(unsigned char [256]) );

	  for (j=0; j<len ; j++) {
	    temp = av_fetch(avmain, j, 0);
	    if (temp && SvROK(*temp) && (SvTYPE(SvRV(*temp)) == SVt_PVAV) ) {
	      avsub = (AV*)SvRV(*temp);
	      if(av_len(avsub) != 255) continue;
	      mask |= 1<<j;
              for (i=0; i<256 ; i++) {
		int val;
		temp = av_fetch(avsub, i, 0);
		val = temp ? SvIV(*temp) : 0;
		if (val<0) val = 0;
		if (val>255) val = 255;
		maps[j][i] = val;
	      }
            }
          }
          i_map(im, maps, mask);
	  myfree(maps);



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
	       int     cords[6];
	     PPCODE:
   	       i_t1_bbox(fontnum,point,str,len,cords);
               EXTEND(SP, 4);
               PUSHs(sv_2mortal(newSViv(cords[0])));
               PUSHs(sv_2mortal(newSViv(cords[1])));
               PUSHs(sv_2mortal(newSViv(cords[2])));
               PUSHs(sv_2mortal(newSViv(cords[3])));
               PUSHs(sv_2mortal(newSViv(cords[4])));
               PUSHs(sv_2mortal(newSViv(cords[5])));



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


Imager::Font::TT
i_tt_new(fontname)
	      char*     fontname


MODULE = Imager         PACKAGE = Imager::Font::TT      PREFIX=TT_

#define TT_DESTROY(handle) i_tt_destroy(handle)

void
TT_DESTROY(handle)
     Imager::Font::TT   handle


MODULE = Imager         PACKAGE = Imager


undef_int
i_tt_text(handle,im,xb,yb,cl,points,str,len,smooth)
  Imager::Font::TT     handle
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
  Imager::Font::TT     handle
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
  Imager::Font::TT     handle
	     float     point
	      char*    str
	       int     len
	     PREINIT:
	       int     cords[6],rc;
	     PPCODE:
  	       if ((rc=i_tt_bbox(handle,point,str,len,cords))) {
                 EXTEND(SP, 4);
                 PUSHs(sv_2mortal(newSViv(cords[0])));
                 PUSHs(sv_2mortal(newSViv(cords[1])));
                 PUSHs(sv_2mortal(newSViv(cords[2])));
                 PUSHs(sv_2mortal(newSViv(cords[3])));
                 PUSHs(sv_2mortal(newSViv(cords[4])));
                 PUSHs(sv_2mortal(newSViv(cords[5])));
               }


#endif 




#ifdef HAVE_LIBJPEG
undef_int
i_writejpeg_wiol(im, ig, qfactor)
    Imager::ImgRaw     im
        Imager::IO     ig
	       int     qfactor


void
i_readjpeg_wiol(ig)
        Imager::IO     ig
	     PREINIT:
	      char*    iptc_itext;
	       int     tlength;
	     i_img*    rimg;
                SV*    r;
	     PPCODE:
 	      iptc_itext = NULL;
	      rimg = i_readjpeg_wiol(ig,-1,&iptc_itext,&tlength);
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




#ifdef HAVE_LIBTIFF

Imager::ImgRaw
i_readtiff_wiol(ig, length)
        Imager::IO     ig
	       int     length


undef_int
i_writetiff_wiol(im, ig)
    Imager::ImgRaw     im
        Imager::IO     ig

undef_int
i_writetiff_wiol_faxable(im, ig, fine)
    Imager::ImgRaw     im
        Imager::IO     ig
	       int     fine


#endif /* HAVE_LIBTIFF */





#ifdef HAVE_LIBPNG

Imager::ImgRaw
i_readpng_wiol(ig, length)
        Imager::IO     ig
	       int     length


undef_int
i_writepng_wiol(im, ig)
    Imager::ImgRaw     im
        Imager::IO     ig


#endif


#ifdef HAVE_LIBGIF

void
i_giflib_version()
	PPCODE:
	  PUSHs(sv_2mortal(newSVnv(IM_GIFMAJOR+IM_GIFMINOR*0.1)));

undef_int
i_writegif(im,fd,colors,pixdev,fixed)
    Imager::ImgRaw     im
	       int     fd
	       int     colors
               int     pixdev
	     PREINIT:
             int     fixedlen;
	     Imager__Color  fixed;
	     Imager__Color  tmp;
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
    Imager::ImgRaw    im
	       int     fd
	       int     colors


undef_int
i_writegif_gen(fd, ...)
	       int     fd
      PROTOTYPE: $$@
      PREINIT:
	i_quantize quant;
	i_gif_opts opts;
	i_img **imgs = NULL;
	int img_count;
	int i;
	HV *hv;
      CODE:
	if (items < 3)
	    croak("Usage: i_writegif_gen(fd,hashref, images...)");
	if (!SvROK(ST(1)) || ! SvTYPE(SvRV(ST(1))))
	    croak("i_writegif_gen: Second argument must be a hash ref");
	hv = (HV *)SvRV(ST(1));
	memset(&quant, 0, sizeof(quant));
	quant.mc_size = 256;
	memset(&opts, 0, sizeof(opts));
	handle_quant_opts(&quant, hv);
	handle_gif_opts(&opts, hv);
	img_count = items - 2;
	RETVAL = 1;
	if (img_count < 1) {
	  RETVAL = 0;
	  i_clear_error();
	  i_push_error(0, "You need to specify images to save");
	}
	else {
          imgs = mymalloc(sizeof(i_img *) * img_count);
          for (i = 0; i < img_count; ++i) {
	    SV *sv = ST(2+i);
	    imgs[i] = NULL;
	    if (SvROK(sv) && sv_derived_from(sv, "Imager::ImgRaw")) {
	      imgs[i] = (i_img *)SvIV((SV*)SvRV(sv));
	    }
	    else {
	      i_clear_error();
	      i_push_error(0, "Only images can be saved");
	      RETVAL = 0;
	      break;
            }
	  }
          if (RETVAL) {
	    RETVAL = i_writegif_gen(&quant, fd, imgs, img_count, &opts);
          }
	  myfree(imgs);
          if (RETVAL) {
	    copy_colors_back(hv, &quant);
          }
	}
        ST(0) = sv_newmortal();
        if (RETVAL == 0) ST(0)=&PL_sv_undef;
        else sv_setiv(ST(0), (IV)RETVAL);
	cleanup_gif_opts(&opts);
	cleanup_quant_opts(&quant);


undef_int
i_writegif_callback(cb, maxbuffer,...)
	int maxbuffer;
      PREINIT:
	i_quantize quant;
	i_gif_opts opts;
	i_img **imgs = NULL;
	int img_count;
	int i;
	HV *hv;
        i_writer_data wd;
      CODE:
	if (items < 4)
	    croak("Usage: i_writegif_callback(\\&callback,maxbuffer,hashref, images...)");
	if (!SvROK(ST(2)) || ! SvTYPE(SvRV(ST(2))))
	    croak("i_writegif_callback: Second argument must be a hash ref");
	hv = (HV *)SvRV(ST(2));
	memset(&quant, 0, sizeof(quant));
	quant.mc_size = 256;
	memset(&opts, 0, sizeof(opts));
	handle_quant_opts(&quant, hv);
	handle_gif_opts(&opts, hv);
	img_count = items - 3;
	RETVAL = 1;
	if (img_count < 1) {
	  RETVAL = 0;
	}
	else {
          imgs = mymalloc(sizeof(i_img *) * img_count);
          for (i = 0; i < img_count; ++i) {
	    SV *sv = ST(3+i);
	    imgs[i] = NULL;
	    if (SvROK(sv) && sv_derived_from(sv, "Imager::ImgRaw")) {
	      imgs[i] = (i_img *)SvIV((SV*)SvRV(sv));
	    }
	    else {
	      RETVAL = 0;
	      break;
            }
	  }
          if (RETVAL) {
	    wd.sv = ST(0);
	    RETVAL = i_writegif_callback(&quant, write_callback, (char *)&wd, maxbuffer, imgs, img_count, &opts);
          }
	  myfree(imgs);
          if (RETVAL) {
	    copy_colors_back(hv, &quant);
          }
	}
	ST(0) = sv_newmortal();
	if (RETVAL == 0) ST(0)=&PL_sv_undef;
	else sv_setiv(ST(0), (IV)RETVAL);
	cleanup_gif_opts(&opts);
	cleanup_quant_opts(&quant);

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
 	       colour_table = NULL;
               colours = 0;

	if(GIMME_V == G_ARRAY) {
            rimg = i_readgif(fd,&colour_table,&colours);
        } else {
            /* don't waste time with colours if they aren't wanted */
            rimg = i_readgif(fd,NULL,NULL);
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
            /* No Idea here either */

            ct=newAV();
            av_extend(ct, colours);
            for(q=0; q<colours; q++) {
                for(w=0; w<3; w++)
                    temp[w]=sv_2mortal(newSViv(colour_table[q*3 + w]));
                av_store(ct, q, (SV*)newRV_noinc((SV*)av_make(3, temp)));
            }
            myfree(colour_table);

            EXTEND(SP,2);
            r = sv_newmortal();
            sv_setref_pv(r, "Imager::ImgRaw", (void*)rimg);
            PUSHs(r);
            PUSHs(newRV_noinc((SV*)ct));
        }





void
i_readgif_scalar(...)
          PROTOTYPE: $
            PREINIT:
               char*    data;
       unsigned int     length;
	        int*    colour_table;
	        int     colours, q, w;
	      i_img*    rimg;
                 SV*    temp[3];
                 AV*    ct; 
                 SV*    r;
	       PPCODE:
        data = (char *)SvPV(ST(0), length);
        colour_table=NULL;
        colours=0;

	if(GIMME_V == G_ARRAY) {  
            rimg=i_readgif_scalar(data,length,&colour_table,&colours);
        } else {
            /* don't waste time with colours if they aren't wanted */
            rimg=i_readgif_scalar(data,length,NULL,NULL);
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

void
i_readgif_callback(...)
          PROTOTYPE: &
            PREINIT:
               char*    data;
	        int     length;
	        int*    colour_table;
	        int     colours, q, w;
	      i_img*    rimg;
                 SV*    temp[3];
                 AV*    ct; 
                 SV*    r;
       i_reader_data    rd;
	       PPCODE:
	rd.sv = ST(0);
        colour_table=NULL;
        colours=0;

	if(GIMME_V == G_ARRAY) {  
            rimg=i_readgif_callback(read_callback, (char *)&rd,&colour_table,&colours);
        } else {
            /* don't waste time with colours if they aren't wanted */
            rimg=i_readgif_callback(read_callback, (char *)&rd,NULL,NULL);
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
            /* Neither do I - maybe I'll move this somewhere */
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

void
i_readgif_multi(fd)
        int     fd
      PREINIT:
        i_img **imgs;
        int count;
        int i;
      PPCODE:
        imgs = i_readgif_multi(fd, &count);
        if (imgs) {
          EXTEND(SP, count);
          for (i = 0; i < count; ++i) {
            SV *sv = sv_newmortal();
            sv_setref_pv(sv, "Imager::ImgRaw", (void *)imgs[i]);
            PUSHs(sv);
          }
          myfree(imgs);
        }

void
i_readgif_multi_scalar(data)
      PREINIT:
        i_img **imgs;
        int count;
        char *data;
        unsigned int length;
        int i;
      PPCODE:
        data = (char *)SvPV(ST(0), length);
        imgs = i_readgif_multi_scalar(data, length, &count);
        if (imgs) {
          EXTEND(SP, count);
          for (i = 0; i < count; ++i) {
            SV *sv = sv_newmortal();
            sv_setref_pv(sv, "Imager::ImgRaw", (void *)imgs[i]);
            PUSHs(sv);
          }
          myfree(imgs);
        }

void
i_readgif_multi_callback(cb)
      PREINIT:
        i_reader_data rd;
        i_img **imgs;
        int count;
        int i;
      PPCODE:
        rd.sv = ST(0);
        imgs = i_readgif_multi_callback(read_callback, (char *)&rd, &count);
        if (imgs) {
          EXTEND(SP, count);
          for (i = 0; i < count; ++i) {
            SV *sv = sv_newmortal();
            sv_setref_pv(sv, "Imager::ImgRaw", (void *)imgs[i]);
            PUSHs(sv);
          }
          myfree(imgs);
        }

#endif



Imager::ImgRaw
i_readpnm_wiol(ig, length)
        Imager::IO     ig
	       int     length


undef_int
i_writeppm_wiol(im, ig)
    Imager::ImgRaw     im
        Imager::IO     ig


Imager::ImgRaw
i_readraw_wiol(ig,x,y,datachannels,storechannels,intrl)
        Imager::IO     ig
	       int     x
	       int     y
	       int     datachannels
	       int     storechannels
	       int     intrl

undef_int
i_writeraw_wiol(im,ig)
    Imager::ImgRaw     im
        Imager::IO     ig

undef_int
i_writebmp_wiol(im,ig)
    Imager::ImgRaw     im
        Imager::IO     ig

Imager::ImgRaw
i_readbmp_wiol(ig)
        Imager::IO     ig


undef_int
i_writetga_wiol(im,ig, wierdpack, compress, idstring)
    Imager::ImgRaw     im
        Imager::IO     ig
               int     wierdpack
               int     compress
              char*    idstring
            PREINIT:
                SV* sv1;
                int rc;
                int idlen;
	       CODE:
                idlen  = SvCUR(ST(4));
                RETVAL = i_writetga_wiol(im, ig, wierdpack, compress, idstring, idlen);
                OUTPUT:
                RETVAL


Imager::ImgRaw
i_readtga_wiol(ig, length)
        Imager::IO     ig
               int     length


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
             if (!SvROK(ST(3))) croak("Imager: Parameter 3 must be a reference to an array\n");
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
             parm=mymalloc( parmlen*sizeof(double) );
             for(i=0;i<parmlen;i++) { /* FIXME: Bug? */
               sv1=(*(av_fetch(av,i,0)));
               parm[i]=(double)SvNV(sv1);
             }
             RETVAL=i_transform(im,opx,opxl,opy,opyl,parm,parmlen);
             myfree(parm);
             myfree(opy);
             myfree(opx);
             ST(0) = sv_newmortal();
             if (RETVAL == 0) ST(0)=&PL_sv_undef;
             else sv_setref_pv(ST(0), "Imager::ImgRaw", (void*)RETVAL);

Imager::ImgRaw
i_transform2(width,height,ops,n_regs,c_regs,in_imgs)
	     PREINIT:
             int width;
             int height;
	     double* parm;
	     struct rm_op *ops;
	     STRLEN ops_len;
	     int ops_count;
             double *n_regs;
             int n_regs_count;
             i_color *c_regs;
	     int c_regs_count;
             int in_imgs_count;
             i_img **in_imgs;
	     AV* av;
	     SV* sv1;
             IV tmp;
	     int i;
             CODE:
	     if (!SvROK(ST(3))) croak("Imager: Parameter 4 must be a reference to an array\n");
	     if (!SvROK(ST(4))) croak("Imager: Parameter 5 must be a reference to an array\n");
	     if (!SvROK(ST(5))) croak("Imager: Parameter 6 must be a reference to an array of images\n");
	     if (SvTYPE(SvRV(ST(3))) != SVt_PVAV) croak("Imager: Parameter 4 must be a reference to an array\n");
	     if (SvTYPE(SvRV(ST(4))) != SVt_PVAV) croak("Imager: Parameter 5 must be a reference to an array\n");

	/*if (SvTYPE(SvRV(ST(5))) != SVt_PVAV) croak("Imager: Parameter 6 must be a reference to an array\n");*/

             if (SvTYPE(SvRV(ST(5))) == SVt_PVAV) {
	       av = (AV*)SvRV(ST(5));
               in_imgs_count = av_len(av)+1;
	       for (i = 0; i < in_imgs_count; ++i) {
		 sv1 = *av_fetch(av, i, 0);
		 if (!sv_derived_from(sv1, "Imager::ImgRaw")) {
		   croak("Parameter 5 must contain only images");
		 }
	       }
	     }
	     else {
	       in_imgs_count = 0;
             }
             if (in_imgs_count > 0) {
               av = (AV*)SvRV(ST(5));
               in_imgs = mymalloc(in_imgs_count*sizeof(i_img*));
               for (i = 0; i < in_imgs_count; ++i) {              
	         sv1 = *av_fetch(av,i,0);
	         if (!sv_derived_from(sv1, "Imager::ImgRaw")) {
		   croak("Parameter 5 must contain only images");
	         }
                 tmp = SvIV((SV*)SvRV(sv1));
	         in_imgs[i] = (i_img*)tmp;
	       }
	     }
             else {
	       /* no input images */
	       in_imgs = NULL;
             }
             /* default the output size from the first input if possible */
             if (SvOK(ST(0)))
	       width = SvIV(ST(0));
             else if (in_imgs_count)
	       width = in_imgs[0]->xsize;
             else
	       croak("No output image width supplied");

             if (SvOK(ST(1)))
	       height = SvIV(ST(1));
             else if (in_imgs_count)
	       height = in_imgs[0]->ysize;
             else
	       croak("No output image height supplied");

	     ops = (struct rm_op *)SvPV(ST(2), ops_len);
             if (ops_len % sizeof(struct rm_op))
	         croak("Imager: Parameter 3 must be a bitmap of regops\n");
	     ops_count = ops_len / sizeof(struct rm_op);
	     av = (AV*)SvRV(ST(3));
	     n_regs_count = av_len(av)+1;
             n_regs = mymalloc(n_regs_count * sizeof(double));
	     for (i = 0; i < n_regs_count; ++i) {
	       sv1 = *av_fetch(av,i,0);
	       if (SvOK(sv1))
	         n_regs[i] = SvNV(sv1);
	     }
             av = (AV*)SvRV(ST(4));
             c_regs_count = av_len(av)+1;
             c_regs = mymalloc(c_regs_count * sizeof(i_color));
             /* I don't bother initializing the colou?r registers */

	     RETVAL=i_transform2(width, height, 3, ops, ops_count, 
				 n_regs, n_regs_count, 
				 c_regs, c_regs_count, in_imgs, in_imgs_count);
	     if (in_imgs)
	         myfree(in_imgs);
             myfree(n_regs);
	     myfree(c_regs);
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
i_bumpmap_complex(im,bump,channel,tx,ty,Lx,Ly,Lz,cd,cs,n,Ia,Il,Is)
    Imager::ImgRaw     im
    Imager::ImgRaw     bump
               int     channel
               int     tx
               int     ty
             float     Lx
             float     Ly
             float     Lz
             float     cd
             float     cs
             float     n
     Imager::Color     Ia
     Imager::Color     Il
     Imager::Color     Is



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
i_turbnoise(im, xo, yo, scale)
    Imager::ImgRaw     im
             float     xo
             float     yo
             float     scale


void
i_gradgen(im, ...)
    Imager::ImgRaw     im
      PREINIT:
	int num;
	int *xo;
	int *yo;
        i_color *ival;
	int dmeasure;
	int i;
	SV *sv;
	AV *axx;
	AV *ayy;
	AV *ac;
      CODE:
	if (items != 5)
	    croak("Usage: i_gradgen(im, xo, yo, ival, dmeasure)");
	if (!SvROK(ST(1)) || ! SvTYPE(SvRV(ST(1))))
	    croak("i_gradgen: Second argument must be an array ref");
	if (!SvROK(ST(2)) || ! SvTYPE(SvRV(ST(2))))
	    croak("i_gradgen: Third argument must be an array ref");
	if (!SvROK(ST(3)) || ! SvTYPE(SvRV(ST(3))))
	    croak("i_gradgen: Fourth argument must be an array ref");
	axx = (AV *)SvRV(ST(1));
	ayy = (AV *)SvRV(ST(2));
	ac  = (AV *)SvRV(ST(3));
	dmeasure = (int)SvIV(ST(4));
	
        num = av_len(axx) < av_len(ayy) ? av_len(axx) : av_len(ayy);
	num = num <= av_len(ac) ? num : av_len(ac);
	num++; 
	if (num < 2) croak("Usage: i_gradgen array refs must have more than 1 entry each");
	xo = mymalloc( sizeof(int) * num );
	yo = mymalloc( sizeof(int) * num );
	ival = mymalloc( sizeof(i_color) * num );
	for(i = 0; i<num; i++) {
	  xo[i]   = (int)SvIV(* av_fetch(axx, i, 0));
	  yo[i]   = (int)SvIV(* av_fetch(ayy, i, 0));
          sv = *av_fetch(ac, i, 0);
	  if ( !sv_derived_from(sv, "Imager::Color") ) {
	    free(axx); free(ayy); free(ac);
            croak("i_gradgen: Element of fourth argument is not derived from Imager::Color");
	  }
	  ival[i] = *(i_color *)SvIV((SV *)SvRV(sv));
	}
        i_gradgen(im, num, xo, yo, ival, dmeasure);
        myfree(xo);
        myfree(yo);
        myfree(ival);


void
i_fountain(im, xa, ya, xb, yb, type, repeat, combine, super_sample, ssample_param, segs)
    Imager::ImgRaw     im
            double     xa
            double     ya
            double     xb
            double     yb
               int     type
               int     repeat
               int     combine
               int     super_sample
            double     ssample_param
      PREINIT:
        AV *asegs;
        int count;
        i_fountain_seg *segs;
      CODE:
	if (!SvROK(ST(10)) || ! SvTYPE(SvRV(ST(10))))
	    croak("i_fountain: argument 11 must be an array ref");
        
	asegs = (AV *)SvRV(ST(10));
        segs = load_fount_segs(asegs, &count);
        i_fountain(im, xa, ya, xb, yb, type, repeat, combine, super_sample, 
                   ssample_param, count, segs);
        myfree(segs);

Imager::FillHandle
i_new_fill_fount(xa, ya, xb, yb, type, repeat, combine, super_sample, ssample_param, segs)
            double     xa
            double     ya
            double     xb
            double     yb
               int     type
               int     repeat
               int     combine
               int     super_sample
            double     ssample_param
      PREINIT:
        AV *asegs;
        int count;
        i_fountain_seg *segs;
      CODE:
	if (!SvROK(ST(9)) || ! SvTYPE(SvRV(ST(9))))
	    croak("i_fountain: argument 11 must be an array ref");
        
	asegs = (AV *)SvRV(ST(9));
        segs = load_fount_segs(asegs, &count);
        RETVAL = i_new_fill_fount(xa, ya, xb, yb, type, repeat, combine, 
                                  super_sample, ssample_param, count, segs);
        myfree(segs);        
      OUTPUT:
        RETVAL

void
i_errors()
      PREINIT:
        i_errmsg *errors;
	int i;
	AV *av;
	SV *ref;
	SV *sv;
      PPCODE:
	errors = i_errors();
	i = 0;
	while (errors[i].msg) {
	  av = newAV();
	  sv = newSVpv(errors[i].msg, strlen(errors[i].msg));
	  if (!av_store(av, 0, sv)) {
	    SvREFCNT_dec(sv);
	  }
	  sv = newSViv(errors[i].code);
	  if (!av_store(av, 1, sv)) {
	    SvREFCNT_dec(sv);
	  }
	  PUSHs(sv_2mortal(newRV_noinc((SV*)av)));
	  ++i;
	}

void
i_nearest_color(im, ...)
    Imager::ImgRaw     im
      PREINIT:
	int num;
	int *xo;
	int *yo;
        i_color *ival;
	int dmeasure;
	int i;
	SV *sv;
	AV *axx;
	AV *ayy;
	AV *ac;
      CODE:
	if (items != 5)
	    croak("Usage: i_nearest_color(im, xo, yo, ival, dmeasure)");
	if (!SvROK(ST(1)) || ! SvTYPE(SvRV(ST(1))))
	    croak("i_nearest_color: Second argument must be an array ref");
	if (!SvROK(ST(2)) || ! SvTYPE(SvRV(ST(2))))
	    croak("i_nearest_color: Third argument must be an array ref");
	if (!SvROK(ST(3)) || ! SvTYPE(SvRV(ST(3))))
	    croak("i_nearest_color: Fourth argument must be an array ref");
	axx = (AV *)SvRV(ST(1));
	ayy = (AV *)SvRV(ST(2));
	ac  = (AV *)SvRV(ST(3));
	dmeasure = (int)SvIV(ST(4));
	
        num = av_len(axx) < av_len(ayy) ? av_len(axx) : av_len(ayy);
	num = num <= av_len(ac) ? num : av_len(ac);
	num++; 
	if (num < 2) croak("Usage: i_nearest_color array refs must have more than 1 entry each");
	xo = mymalloc( sizeof(int) * num );
	yo = mymalloc( sizeof(int) * num );
	ival = mymalloc( sizeof(i_color) * num );
	for(i = 0; i<num; i++) {
	  xo[i]   = (int)SvIV(* av_fetch(axx, i, 0));
	  yo[i]   = (int)SvIV(* av_fetch(ayy, i, 0));
          sv = *av_fetch(ac, i, 0);
	  if ( !sv_derived_from(sv, "Imager::Color") ) {
	    free(axx); free(ayy); free(ac);
            croak("i_nearest_color: Element of fourth argument is not derived from Imager::Color");
	  }
	  ival[i] = *(i_color *)SvIV((SV *)SvRV(sv));
	}
        i_nearest_color(im, num, xo, yo, ival, dmeasure);




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



# this is mostly for testing...
SV *
i_get_pixel(im, x, y)
	Imager::ImgRaw im
	int x
	int y;
      PREINIT:
        i_color *color;
      CODE:
	color = (i_color *)mymalloc(sizeof(i_color));
	if (i_gpix(im, x, y, color) == 0) {
          ST(0) = sv_newmortal();
          sv_setref_pv(ST(0), "Imager::Color", (void *)color);
        }
        else {
          myfree(color);
          ST(0) = &PL_sv_undef;
        }
        

int
i_ppix(im, x, y, cl)
        Imager::ImgRaw im
        int x
        int y
        Imager::Color cl

Imager::ImgRaw
i_img_pal_new(x, y, channels, maxpal)
	int	x
        int	y
        int     channels
	int	maxpal

Imager::ImgRaw
i_img_to_pal(src, quant)
        Imager::ImgRaw src
      PREINIT:
        HV *hv;
        i_quantize quant;
      CODE:
        if (!SvROK(ST(1)) || ! SvTYPE(SvRV(ST(1))))
          croak("i_img_to_pal: second argument must be a hash ref");
        hv = (HV *)SvRV(ST(1));
        memset(&quant, 0, sizeof(quant));
        quant.mc_size = 256;
	handle_quant_opts(&quant, hv);
        RETVAL = i_img_to_pal(src, &quant);
        if (RETVAL) {
          copy_colors_back(hv, &quant);
        }
	cleanup_quant_opts(&quant);
      OUTPUT:
        RETVAL

Imager::ImgRaw
i_img_to_rgb(src)
        Imager::ImgRaw src

void
i_gpal(im, l, r, y)
        Imager::ImgRaw  im
        int     l
        int     r
        int     y
      PREINIT:
        i_palidx *work;
        int count, i;
      PPCODE:
        if (l < r) {
          work = mymalloc((r-l) * sizeof(i_palidx));
          count = i_gpal(im, l, r, y, work);
          if (GIMME_V == G_ARRAY) {
            EXTEND(SP, count);
            for (i = 0; i < count; ++i) {
              PUSHs(sv_2mortal(newSViv(work[i])));
            }
          }
          else {
            EXTEND(SP, 1);
            PUSHs(sv_2mortal(newSVpv(work, count * sizeof(i_palidx))));
          }
          myfree(work);
        }
        else {
          if (GIMME_V != G_ARRAY) {
            EXTEND(SP, 1);
            PUSHs(&PL_sv_undef);
          }
        }

int
i_ppal(im, l, y, ...)
        Imager::ImgRaw  im
        int     l
        int     y
      PREINIT:
        i_palidx *work;
        int count, i;
      CODE:
        if (items > 3) {
          work = mymalloc(sizeof(i_palidx) * (items-3));
          for (i=0; i < items-3; ++i) {
            work[i] = SvIV(ST(i+3));
          }
          RETVAL = i_ppal(im, l, l+items-3, y, work);
          myfree(work);
        }
        else {
          RETVAL = 0;
        }
      OUTPUT:
        RETVAL

SV *
i_addcolors(im, ...)
        Imager::ImgRaw  im
      PREINIT:
        int index;
        i_color *colors;
        int i;
      CODE:
        if (items < 2)
          croak("i_addcolors: no colors to add");
        colors = mymalloc((items-1) * sizeof(i_color));
        for (i=0; i < items-1; ++i) {
          if (sv_isobject(ST(i+1)) 
              && sv_derived_from(ST(i+1), "Imager::Color")) {
            IV tmp = SvIV((SV *)SvRV(ST(i+1)));
            colors[i] = *(i_color *)tmp;
          }
          else {
            myfree(colors);
            croak("i_plin: pixels must be Imager::Color objects");
          }
        }
        index = i_addcolors(im, colors, items-1);
        myfree(colors);
        if (index == 0) {
          ST(0) = sv_2mortal(newSVpv("0 but true", 0));
        }
        else if (index == -1) {
          ST(0) = &PL_sv_undef;
        }
        else {
          ST(0) = sv_2mortal(newSViv(index));
        }

int 
i_setcolors(im, index, ...)
        Imager::ImgRaw  im
        int index
      PREINIT:
        i_color *colors;
        int i;
      CODE:
        if (items < 3)
          croak("i_setcolors: no colors to add");
        colors = mymalloc((items-2) * sizeof(i_color));
        for (i=0; i < items-2; ++i) {
          if (sv_isobject(ST(i+2)) 
              && sv_derived_from(ST(i+2), "Imager::Color")) {
            IV tmp = SvIV((SV *)SvRV(ST(i+2)));
            colors[i] = *(i_color *)tmp;
          }
          else {
            myfree(colors);
            croak("i_setcolors: pixels must be Imager::Color objects");
          }
        }
        RETVAL = i_setcolors(im, index, colors, items-2);
        myfree(colors);

void
i_getcolors(im, index, ...)
        Imager::ImgRaw im
        int index
      PREINIT:
        i_color *colors;
        int count = 1;
        int i;
      PPCODE:
        if (items > 3)
          croak("i_getcolors: too many arguments");
        if (items == 3)
          count = SvIV(ST(2));
        if (count < 1)
          croak("i_getcolors: count must be positive");
        colors = mymalloc(sizeof(i_color) * count);
        if (i_getcolors(im, index, colors, count)) {
          for (i = 0; i < count; ++i) {
            i_color *pv;
            SV *sv = sv_newmortal();
            pv = mymalloc(sizeof(i_color));
            *pv = colors[i];
            sv_setref_pv(sv, "Imager::Color", (void *)pv);
            PUSHs(sv);
          }
        }
        myfree(colors);


SV *
i_colorcount(im)
        Imager::ImgRaw im
      PREINIT:
        int count;
      CODE:
        count = i_colorcount(im);
        if (count >= 0) {
          ST(0) = sv_2mortal(newSViv(count));
        }
        else {
          ST(0) = &PL_sv_undef;
        }

SV *
i_maxcolors(im)
        Imager::ImgRaw im
      PREINIT:
        int count;
      CODE:
        count = i_maxcolors(im);
        if (count >= 0) {
          ST(0) = sv_2mortal(newSViv(count));
        }
        else {
          ST(0) = &PL_sv_undef;
        }

SV *
i_findcolor(im, color)
        Imager::ImgRaw im
        Imager::Color color
      PREINIT:
        i_palidx index;
      CODE:
        if (i_findcolor(im, color, &index)) {
          ST(0) = sv_2mortal(newSViv(index));
        }
        else {
          ST(0) = &PL_sv_undef;
        }

int
i_img_bits(im)
        Imager::ImgRaw  im

int
i_img_type(im)
        Imager::ImgRaw  im

int
i_img_virtual(im)
        Imager::ImgRaw  im

void
i_gsamp(im, l, r, y, ...)
        Imager::ImgRaw im
        int l
        int r
        int y
      PREINIT:
        int *chans;
        int chan_count;
        i_sample_t *data;
        int count, i;
      PPCODE:
        if (items < 5)
          croak("No channel numbers supplied to g_samp()");
        if (l < r) {
          chan_count = items - 4;
          chans = mymalloc(sizeof(int) * chan_count);
          for (i = 0; i < chan_count; ++i)
            chans[i] = SvIV(ST(i+4));
          data = mymalloc(sizeof(i_sample_t) * (r-l) * chan_count); /* XXX: memleak? */
          count = i_gsamp(im, l, r, y, data, chans, chan_count);
	  myfree(chans);
          if (GIMME_V == G_ARRAY) {
            EXTEND(SP, count);
            for (i = 0; i < count; ++i)
              PUSHs(sv_2mortal(newSViv(data[i])));
          }
          else {
            EXTEND(SP, 1);
            PUSHs(sv_2mortal(newSVpv(data, count * sizeof(i_sample_t))));
          }
	  myfree(data);
        }
        else {
          if (GIMME_V != G_ARRAY) {
            EXTEND(SP, 1);
            PUSHs(&PL_sv_undef);
          }
        }


Imager::ImgRaw
i_img_masked_new(targ, mask, x, y, w, h)
        Imager::ImgRaw targ
        int x
        int y
        int w
        int h
      PREINIT:
        i_img *mask;
      CODE:
        if (SvOK(ST(1))) {
          if (!sv_isobject(ST(1)) 
              || !sv_derived_from(ST(1), "Imager::ImgRaw")) {
            croak("i_img_masked_new: parameter 2 must undef or an image");
          }
          mask = (i_img *)SvIV((SV *)SvRV(ST(1)));
        }
        else
          mask = NULL;
        RETVAL = i_img_masked_new(targ, mask, x, y, w, h);
      OUTPUT:
        RETVAL

int
i_plin(im, l, y, ...)
        Imager::ImgRaw  im
        int     l
        int     y
      PREINIT:
        i_color *work;
        int count, i;
      CODE:
        if (items > 3) {
          work = mymalloc(sizeof(i_color) * (items-3));
          for (i=0; i < items-3; ++i) {
            if (sv_isobject(ST(i+3)) 
                && sv_derived_from(ST(i+3), "Imager::Color")) {
              IV tmp = SvIV((SV *)SvRV(ST(i+3)));
              work[i] = *(i_color *)tmp;
            }
            else {
              myfree(work);
              croak("i_plin: pixels must be Imager::Color objects");
            }
          }
          /**(char *)0 = 1;*/
          RETVAL = i_plin(im, l, l+items-3, y, work);
          myfree(work);
        }
        else {
          RETVAL = 0;
        }
      OUTPUT:
        RETVAL

int
i_ppixf(im, x, y, cl)
        Imager::ImgRaw im
        int x
        int y
        Imager::Color::Float cl

void
i_gsampf(im, l, r, y, ...)
        Imager::ImgRaw im
        int l
        int r
        int y
      PREINIT:
        int *chans;
        int chan_count;
        i_fsample_t *data;
        int count, i;
      PPCODE:
        if (items < 5)
          croak("No channel numbers supplied to g_sampf()");
        if (l < r) {
          chan_count = items - 4;
          chans = mymalloc(sizeof(int) * chan_count);
          for (i = 0; i < chan_count; ++i)
            chans[i] = SvIV(ST(i+4));
          data = mymalloc(sizeof(i_fsample_t) * (r-l) * chan_count);
          count = i_gsampf(im, l, r, y, data, chans, chan_count);
          if (GIMME_V == G_ARRAY) {
            EXTEND(SP, count);
            for (i = 0; i < count; ++i)
              PUSHs(sv_2mortal(newSVnv(data[i])));
          }
          else {
            EXTEND(SP, 1);
            PUSHs(sv_2mortal(newSVpv((void *)data, count * sizeof(i_fsample_t))));
          }
        }
        else {
          if (GIMME_V != G_ARRAY) {
            EXTEND(SP, 1);
            PUSHs(&PL_sv_undef);
          }
        }

int
i_plinf(im, l, y, ...)
        Imager::ImgRaw  im
        int     l
        int     y
      PREINIT:
        i_fcolor *work;
        int count, i;
      CODE:
        if (items > 3) {
          work = mymalloc(sizeof(i_fcolor) * (items-3));
          for (i=0; i < items-3; ++i) {
            if (sv_isobject(ST(i+3)) 
                && sv_derived_from(ST(i+3), "Imager::Color::Float")) {
              IV tmp = SvIV((SV *)SvRV(ST(i+3)));
              work[i] = *(i_fcolor *)tmp;
            }
            else {
              myfree(work);
              croak("i_plin: pixels must be Imager::Color::Float objects");
            }
          }
          /**(char *)0 = 1;*/
          RETVAL = i_plinf(im, l, l+items-3, y, work);
          myfree(work);
        }
        else {
          RETVAL = 0;
        }
      OUTPUT:
        RETVAL

SV *
i_gpixf(im, x, y)
	Imager::ImgRaw im
	int x
	int y;
      PREINIT:
        i_fcolor *color;
      CODE:
	color = (i_fcolor *)mymalloc(sizeof(i_fcolor));
	if (i_gpixf(im, x, y, color) == 0) {
          ST(0) = sv_newmortal();
          sv_setref_pv(ST(0), "Imager::Color::Float", (void *)color);
        }
        else {
          myfree(color);
          ST(0) = &PL_sv_undef;
        }
        
void
i_glin(im, l, r, y)
        Imager::ImgRaw im
        int l
        int r
        int y
      PREINIT:
        i_color *vals;
        int count, i;
      PPCODE:
        if (l < r) {
          vals = mymalloc((r-l) * sizeof(i_color));
          count = i_glin(im, l, r, y, vals);
          EXTEND(SP, count);
          for (i = 0; i < count; ++i) {
            SV *sv;
            i_color *col = mymalloc(sizeof(i_color));
            sv = sv_newmortal();
            sv_setref_pv(sv, "Imager::Color", (void *)col);
            PUSHs(sv);
          }
          myfree(vals);
        }

void
i_glinf(im, l, r, y)
        Imager::ImgRaw im
        int l
        int r
        int y
      PREINIT:
        i_fcolor *vals;
        int count, i;
      PPCODE:
        if (l < r) {
          vals = mymalloc((r-l) * sizeof(i_fcolor));
          count = i_glinf(im, l, r, y, vals);
          EXTEND(SP, count);
          for (i = 0; i < count; ++i) {
            SV *sv;
            i_fcolor *col = mymalloc(sizeof(i_fcolor));
            *col = vals[i];
            sv = sv_newmortal();
            sv_setref_pv(sv, "Imager::Color::Float", (void *)col);
            PUSHs(sv);
          }
          myfree(vals);
        }

Imager::ImgRaw
i_img_16_new(x, y, ch)
        int x
        int y
        int ch

Imager::ImgRaw
i_img_double_new(x, y, ch)
        int x
        int y
        int ch

undef_int
i_tags_addn(im, name, code, idata)
        Imager::ImgRaw im
        int     code
        int     idata
      PREINIT:
        char *name;
        STRLEN len;
      CODE:
        if (SvOK(ST(1)))
          name = SvPV(ST(1), len);
        else
          name = NULL;
        RETVAL = i_tags_addn(&im->tags, name, code, idata);
      OUTPUT:
        RETVAL

undef_int
i_tags_add(im, name, code, data, idata)
        Imager::ImgRaw  im
        int code
        int idata
      PREINIT:
        char *name;
        char *data;
        STRLEN len;
      CODE:
        if (SvOK(ST(1)))
          name = SvPV(ST(1), len);
        else
          name = NULL;
        if (SvOK(ST(3)))
          data = SvPV(ST(3), len);
        else {
          data = NULL;
          len = 0;
        }
        RETVAL = i_tags_add(&im->tags, name, code, data, len, idata);
      OUTPUT:
        RETVAL

SV *
i_tags_find(im, name, start)
        Imager::ImgRaw  im
        char *name
        int start
      PREINIT:
        int entry;
      CODE:
        if (i_tags_find(&im->tags, name, start, &entry)) {
          if (entry == 0)
            ST(0) = sv_2mortal(newSVpv("0 but true", 0));
          else
            ST(0) = sv_2mortal(newSViv(entry));
        } else {
          ST(0) = &PL_sv_undef;
        }

SV *
i_tags_findn(im, code, start)
        Imager::ImgRaw  im
        int             code
        int             start
      PREINIT:
        int entry;
      CODE:
        if (i_tags_findn(&im->tags, code, start, &entry)) {
          if (entry == 0)
            ST(0) = sv_2mortal(newSVpv("0 but true", 0));
          else
            ST(0) = sv_2mortal(newSViv(entry));
        }
        else
          ST(0) = &PL_sv_undef;

int
i_tags_delete(im, entry)
        Imager::ImgRaw  im
        int             entry
      CODE:
        RETVAL = i_tags_delete(&im->tags, entry);
      OUTPUT:
        RETVAL

int
i_tags_delbyname(im, name)
        Imager::ImgRaw  im
        char *          name
      CODE:
        RETVAL = i_tags_delbyname(&im->tags, name);
      OUTPUT:
        RETVAL

int
i_tags_delbycode(im, code)
        Imager::ImgRaw  im
        int             code
      CODE:
        RETVAL = i_tags_delbycode(&im->tags, code);
      OUTPUT:
        RETVAL

void
i_tags_get(im, index)
        Imager::ImgRaw  im
        int             index
      PPCODE:
        if (index >= 0 && index < im->tags.count) {
          i_img_tag *entry = im->tags.tags + index;
          EXTEND(SP, 5);
        
          if (entry->name) {
            PUSHs(sv_2mortal(newSVpv(entry->name, 0)));
          }
          else {
            PUSHs(sv_2mortal(newSViv(entry->code)));
          }
          if (entry->data) {
            PUSHs(sv_2mortal(newSVpvn(entry->data, entry->size)));
          }
          else {
            PUSHs(sv_2mortal(newSViv(entry->idata)));
          }
        }

int
i_tags_count(im)
        Imager::ImgRaw  im
      CODE:
        RETVAL = im->tags.count;
      OUTPUT:
        RETVAL

#ifdef HAVE_WIN32

void
i_wf_bbox(face, size, text)
	char *face
	int size
	char *text
      PREINIT:
	int cords[6];
      PPCODE:
        if (i_wf_bbox(face, size, text, strlen(text), cords)) {
          EXTEND(SP, 6);  
          PUSHs(sv_2mortal(newSViv(cords[0])));
          PUSHs(sv_2mortal(newSViv(cords[1])));
          PUSHs(sv_2mortal(newSViv(cords[2])));
          PUSHs(sv_2mortal(newSViv(cords[3])));
          PUSHs(sv_2mortal(newSViv(cords[4])));
          PUSHs(sv_2mortal(newSViv(cords[5])));
        }

undef_int
i_wf_text(face, im, tx, ty, cl, size, text, align, aa)
	char *face
	Imager::ImgRaw im
	int tx
	int ty
	Imager::Color cl
	int size
	char *text
	int align
	int aa
      CODE:
	RETVAL = i_wf_text(face, im, tx, ty, cl, size, text, strlen(text), 
	                   align, aa);
      OUTPUT:
	RETVAL

undef_int
i_wf_cp(face, im, tx, ty, channel, size, text, align, aa)
	char *face
	Imager::ImgRaw im
	int tx
	int ty
	int channel
	int size
	char *text
	int align
	int aa
      CODE:
	RETVAL = i_wf_cp(face, im, tx, ty, channel, size, text, strlen(text), 
		         align, aa);
      OUTPUT:
	RETVAL


#endif

#ifdef HAVE_FT2

MODULE = Imager         PACKAGE = Imager::Font::FT2     PREFIX=FT2_

#define FT2_DESTROY(font) i_ft2_destroy(font)

void
FT2_DESTROY(font)
        Imager::Font::FT2 font

MODULE = Imager         PACKAGE = Imager::Font::FreeType2 

Imager::Font::FT2
i_ft2_new(name, index)
        char *name
        int index

undef_int
i_ft2_setdpi(font, xdpi, ydpi)
        Imager::Font::FT2 font
        int xdpi
        int ydpi

void
i_ft2_getdpi(font)
        Imager::Font::FT2 font
      PREINIT:
        int xdpi, ydpi;
      CODE:
        if (i_ft2_getdpi(font, &xdpi, &ydpi)) {
          EXTEND(SP, 2);
          PUSHs(sv_2mortal(newSViv(xdpi)));
          PUSHs(sv_2mortal(newSViv(ydpi)));
        }

undef_int
i_ft2_sethinting(font, hinting)
        Imager::Font::FT2 font
        int hinting

undef_int
i_ft2_settransform(font, matrix)
        Imager::Font::FT2 font
      PREINIT:
        double matrix[6];
        int len;
        AV *av;
        SV *sv1;
        int i;
      CODE:
        if (!SvROK(ST(1)) || SvTYPE(SvRV(ST(1))) != SVt_PVAV)
          croak("i_ft2_settransform: parameter 2 must be an array ref\n");
	av=(AV*)SvRV(ST(1));
	len=av_len(av)+1;
        if (len > 6)
          len = 6;
        for (i = 0; i < len; ++i) {
	  sv1=(*(av_fetch(av,i,0)));
	  matrix[i] = SvNV(sv1);
        }
        for (; i < 6; ++i)
          matrix[i] = 0;
        RETVAL = i_ft2_settransform(font, matrix);
      OUTPUT:
        RETVAL

void
i_ft2_bbox(font, cheight, cwidth, text)
        Imager::Font::FT2 font
        double cheight
        double cwidth
        char *text
      PREINIT:
        int bbox[6];
        int i;
      PPCODE:
        if (i_ft2_bbox(font, cheight, cwidth, text, strlen(text), bbox)) {
          EXTEND(SP, 6);
          for (i = 0; i < 6; ++i)
            PUSHs(sv_2mortal(newSViv(bbox[i])));
        }

void
i_ft2_bbox_r(font, cheight, cwidth, text, vlayout, utf8)
        Imager::Font::FT2 font
        double cheight
        double cwidth
        char *text
        int vlayout
        int utf8
      PREINIT:
        int bbox[8];
        int i;
      PPCODE:
#ifdef SvUTF8
        if (SvUTF8(ST(3)))
          utf8 = 1;
#endif
        if (i_ft2_bbox_r(font, cheight, cwidth, text, strlen(text), vlayout,
                         utf8, bbox)) {
          EXTEND(SP, 8);
          for (i = 0; i < 8; ++i)
            PUSHs(sv_2mortal(newSViv(bbox[i])));
        }

undef_int
i_ft2_text(font, im, tx, ty, cl, cheight, cwidth, text, align, aa, vlayout, utf8)
        Imager::Font::FT2 font
        Imager::ImgRaw im
        int tx
        int ty
        Imager::Color cl
        double cheight
        double cwidth
        int align
        int aa
        int vlayout
        int utf8
      PREINIT:
        char *text;
        STRLEN len;
      CODE:
#ifdef SvUTF8
        if (SvUTF8(ST(7))) {
          utf8 = 1;
        }
#endif
        text = SvPV(ST(7), len);
        RETVAL = i_ft2_text(font, im, tx, ty, cl, cheight, cwidth, text,
                            len, align, aa, vlayout, utf8);
      OUTPUT:
        RETVAL

undef_int
i_ft2_cp(font, im, tx, ty, channel, cheight, cwidth, text, align, aa, vlayout, utf8)
        Imager::Font::FT2 font
        Imager::ImgRaw im
        int tx
        int ty
        int channel
        double cheight
        double cwidth
        char *text
        int align
        int aa
        int vlayout
        int utf8
      CODE:
#ifdef SvUTF8
        if (SvUTF8(ST(7)))
          utf8 = 1;
#endif
        RETVAL = i_ft2_cp(font, im, tx, ty, channel, cheight, cwidth, text,
                          strlen(text), align, aa, vlayout, 1);
      OUTPUT:
        RETVAL

void
ft2_transform_box(font, x0, x1, x2, x3)
        Imager::Font::FT2 font
        int x0
        int x1
        int x2
        int x3
      PREINIT:
        int box[4];
      PPCODE:
        box[0] = x0; box[1] = x1; box[2] = x2; box[3] = x3;
        ft2_transform_box(font, box);
          EXTEND(SP, 4);
          PUSHs(sv_2mortal(newSViv(box[0])));
          PUSHs(sv_2mortal(newSViv(box[1])));
          PUSHs(sv_2mortal(newSViv(box[2])));
          PUSHs(sv_2mortal(newSViv(box[3])));
        
#endif

MODULE = Imager         PACKAGE = Imager::FillHandle PREFIX=IFILL_

void
IFILL_DESTROY(fill)
        Imager::FillHandle fill

MODULE = Imager         PACKAGE = Imager

Imager::FillHandle
i_new_fill_solid(cl, combine)
        Imager::Color cl
        int combine

Imager::FillHandle
i_new_fill_solidf(cl, combine)
        Imager::Color::Float cl
        int combine

Imager::FillHandle
i_new_fill_hatch(fg, bg, combine, hatch, cust_hatch, dx, dy)
        Imager::Color fg
        Imager::Color bg
        int combine
        int hatch
        int dx
        int dy
      PREINIT:
        unsigned char *cust_hatch;
        STRLEN len;
      CODE:
        if (SvOK(ST(4))) {
          cust_hatch = SvPV(ST(4), len);
        }
        else
          cust_hatch = NULL;
        RETVAL = i_new_fill_hatch(fg, bg, combine, hatch, cust_hatch, dx, dy);
      OUTPUT:
        RETVAL

Imager::FillHandle
i_new_fill_hatchf(fg, bg, combine, hatch, cust_hatch, dx, dy)
        Imager::Color::Float fg
        Imager::Color::Float bg
        int combine
        int hatch
        int dx
        int dy
      PREINIT:
        unsigned char *cust_hatch;
        STRLEN len;
      CODE:
        if (SvOK(ST(4))) {
          cust_hatch = SvPV(ST(4), len);
        }
        else
          cust_hatch = NULL;
        RETVAL = i_new_fill_hatchf(fg, bg, combine, hatch, cust_hatch, dx, dy);
      OUTPUT:
        RETVAL

Imager::FillHandle
i_new_fill_image(src, matrix, xoff, yoff, combine)
        Imager::ImgRaw src
        int xoff
        int yoff
        int combine
      PREINIT:
        double matrix[9];
        double *matrixp;
        AV *av;
        IV len;
        SV *sv1;
        int i;
      CODE:
        if (!SvOK(ST(1))) {
          matrixp = NULL;
        }
        else {
          if (!SvROK(ST(1)) || SvTYPE(SvRV(ST(1))) != SVt_PVAV)
            croak("i_new_fill_image: parameter must be an arrayref");
	  av=(AV*)SvRV(ST(1));
	  len=av_len(av)+1;
          if (len > 9)
            len = 9;
          for (i = 0; i < len; ++i) {
	    sv1=(*(av_fetch(av,i,0)));
	    matrix[i] = SvNV(sv1);
          }
          for (; i < 9; ++i)
            matrix[i] = 0;
          matrixp = matrix;
        }
        RETVAL = i_new_fill_image(src, matrixp, xoff, yoff, combine);
      OUTPUT:
        RETVAL
