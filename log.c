#include "log.h"

#define DTBUFF 50

static FILE* lg_file=NULL;
static char *date_format="%Y/%m/%d %H:%M:%S";
static char date_buffer[DTBUFF];



#ifdef IMAGER_LOG

/*
 * Logging is active
 */

void
init_log(const char* name,int onoff) {
  if (onoff == 0) {
    lg_file=NULL;
  } else {

    if (name==NULL) {
      lg_file=stderr;
    } else {
      if (NULL == (lg_file=fopen(name, "w+")) ) { 
	fprintf(stderr,"Cannot open file '%s'\n",name);
	exit(2);
      }
    }
  }
  mm_log((0,"Imager - log started\n"));
}

void
m_fatal(int exitcode,const char *fmt, ... ) {
  va_list ap;
  time_t timi;
  struct tm *str_tm;

  if (lg_file != NULL) {
    timi=time(NULL);
    str_tm=localtime(&timi);
    if (strftime(date_buffer,DTBUFF,date_format,str_tm))
      fprintf(lg_file,"[%s] ",date_buffer);
    va_start(ap,fmt);
    vfprintf(lg_file,fmt,ap);
    va_end(ap);
  }
  exit(exitcode);
}

#else

/*
 * Logging is inactive - insert dummy functions


void init_log(const char* name,int onoff) {}
void m_fatal(int exitcode,const char *fmt, ... ) { return(exitcode); }

*/

#endif



void
m_loog(int level,const char *fmt, ... ) {
  va_list ap;
  level=0; /* FIXME: Why isn't level used here */
  if (lg_file != NULL) {
    va_start(ap,fmt);
    vfprintf(lg_file,fmt,ap);
    fflush(lg_file);
    va_end(ap);
  }
}



void
m_lhead(const char *file, int line) {
  time_t timi;
  struct tm *str_tm;

  if (lg_file != NULL) {
    timi=time(NULL);
    str_tm=localtime(&timi);
    if (strftime(date_buffer,DTBUFF,date_format,str_tm))
      fprintf(lg_file,"[%s] %10s:%-5d ",date_buffer,file,line);
  }
}

