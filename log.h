#ifndef _LOG_H_
#define _LOG_H_

#include <stdio.h>
#include <stdarg.h>
#include <time.h>
/* 
   input:  name of file to log too
   input:  onoff, 0 means no logging
   global: creates a global variable FILE* lg_file
*/
#ifdef IMAGER_LOG
#define mm_log(x) (m_loog x)
#else
#define mm_log(x)
#endif

void init_log(const char* name,int onoff);
void m_fatal(int exitcode,const char *fmt, ... );
void m_log(const char *msg, ... );
void m_loog(int level,const char *msg, ... );

#endif /* _LOG_H_ */
