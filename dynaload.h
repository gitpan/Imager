#include <stdio.h>

#ifdef OS_hpux
#include <dl.h>
typedef shl_t minthandle_t;
#else 
#include <dlfcn.h>
typedef void *minthandle_t; 
#endif 

#include "EXTERN.h"
#include "perl.h"
#include "ppport.h"

#include "ext.h"


typedef struct {
  minthandle_t handle;
  char *filename;
  func_ptr *function_list;
} DSO_handle;

typedef struct {
  HV* hv;
  char *key;
  void *store;
} UTIL_args;

int getint(void *hv_t,char *key,int *store);
int getdouble(void *hv_t,char *key,double *store);
int getvoid(void *hv_t,char *key,void **store);

void *DSO_open(char* file,char** evalstring);
int DSO_close(void *);
void DSO_call(DSO_handle *handle,int func_index,HV* hv);



