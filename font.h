#ifndef _FONT_H_
#define _FONT_H_

#include "image.h"



#ifdef HAVE_LIBTT



#define USTRCT(x) ((x).z)
#define TT_VALID( handle )  ( ( handle ).z != NULL )

#endif



#endif /* _FONT_H_ */




