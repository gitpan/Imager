#include "log.h"

#define DTBUFF 50

static FILE* lg_file=NULL;
static char *date_format="%Y/%m/%d %H:%M:%S";
static char date_buffer[DTBUFF];

#ifdef IMAGER_LOG

void
init_log(const char* name,int onoff) {
  /*  fprintf(stderr,"init_log(name 0x%x,onoff %d)\n",name,onoff); */

  if (onoff == 0) {
    lg_file=NULL;
  } else {

    if (name==NULL) {
      lg_file=stderr;
    } else {
      if (NULL == (lg_file=fopen(name, "a")) ) { 
	fprintf(stderr,"Cannot open file '%s'\n",name);
	exit(2);
      }
    }

  }

  m_log("Imager - log started\n");
  
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

void init_log(const char* name,int onoff) {}
void m_fatal(int exitcode,const char *fmt, ... ) { return(exitcode); }

#endif

void
m_log(const char *fmt, ... ) {
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

}

void
m_loog(int level,const char *fmt, ... ) {
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
    fflush(lg_file);
    va_end(ap);
  }

}













