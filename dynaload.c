#include "dynaload.h"

/* char dl_errorstring[256]; */

int getint(void *hv_t,char *key,int *store) {
  SV** svpp;
  HV* hv=(HV*)hv_t;  

  if ( !hv_exists(hv,key,strlen(key)) ) return 0;

  svpp=hv_fetch(hv, key, strlen(key), 0);
  *store=(int)SvIV(*svpp);
  return 1;
}

int getdouble(void *hv_t,char* key,double *store) {
  SV** svpp;
  HV* hv=(HV*)hv_t;

  if ( !hv_exists(hv,key,strlen(key)) ) return 0;
  svpp=hv_fetch(hv, key, strlen(key), 0);
  *store=(float)SvNV(*svpp);
  return 1;
}

int getvoid(void *hv_t,char* key,void **store) {
  SV** svpp;
  HV* hv=(HV*)hv_t;

  if ( !hv_exists(hv,key,strlen(key)) ) return 0;

  svpp=hv_fetch(hv, key, strlen(key), 0);
  *store=(void*)SvIV(*svpp);

  return 1;
}

UTIL_table_t UTIL_table={getint,getdouble,getvoid};
extern symbol_table_t symbol_table;

/*
  Dynamic loading works like this:
  dynaload opens the shared object and
  loads all the functions into an array of functions
  it returns a string from the dynamic function that
  can be supplied to the parser for evaling.
*/

void
DSO_call(DSO_handle *handle,int func_index,HV* hv) {
 (handle->function_list[func_index].iptr)((void*)hv);
}


#if (LOSNAME == hpux)

void*
DSO_open(char* file,char** evalstring) {
  void *d_handle,**plugin_symtab,**plugin_utiltab;
  int  rc,*iptr, (*fptr)(int);
  func_ptr *function_list;
  DSO_handle *dso_handle;
  int i;

  *evalstring=NULL;
  if ( (d_handle = (void*)shl_load(file, BIND_DEFERRED,NULL)) == NULL) return NULL;
  if ( (shl_findsym((shl_t*)d_handle, "evalstr",TYPE_UNDEFINED,(void*)evalstring))) return NULL;

  if ( (shl_findsym((shl_t*)d_handle, "symbol_table",TYPE_UNDEFINED,(void*)&plugin_symtab))) return NULL;
  if ( (shl_findsym((shl_t*)d_handle, "util_table",TYPE_UNDEFINED,&plugin_utiltab))) return NULL;

  (*plugin_symtab)=&symbol_table;
  (*plugin_utiltab)=&UTIL_table;

  if ( (shl_findsym((shl_t*)d_handle, "function_list",TYPE_UNDEFINED,(func_ptr*)&function_list))) return NULL;

  if ( (dso_handle=(DSO_handle*)malloc(sizeof(DSO_handle))) == NULL) return NULL;

  dso_handle->handle=d_handle; /* needed to close again */
  dso_handle->function_list=function_list;
  if ( (dso_handle->filename=(char*)malloc(strlen(file))) == NULL) { free(dso_handle); return NULL; }
  strcpy(dso_handle->filename,file);

  return (void*)dso_handle;
}

undef_int
DSO_close(void *ptr) {
  DSO_handle *handle=(DSO_handle*) ptr;
  return !shl_unload((shl_t)(handle->handle));
}


#else


void*
DSO_open(char* file,char** evalstring) {
  void *d_handle,**plugin_symtab,**plugin_utiltab;
  int  rc,*iptr, (*fptr)(int);
  func_ptr *function_list;
  DSO_handle *dso_handle;
  int i;
  
  *evalstring=NULL;
  if ( (d_handle = dlopen(file, RTLD_LAZY)) == NULL) return NULL;
  if ( (*evalstring = (char *)dlsym(d_handle, "evalstr")) == NULL) return NULL;

  if ( (plugin_symtab = dlsym(d_handle, "symbol_table")) == NULL) return NULL;
  if ( (plugin_utiltab = dlsym(d_handle, "util_table")) == NULL) return NULL;

  (*plugin_symtab)=&symbol_table;
  (*plugin_utiltab)=&UTIL_table;

  if ( (function_list=(func_ptr *)dlsym(d_handle, "function_list")) == NULL) return NULL;
  if ( (dso_handle=(DSO_handle*)malloc(sizeof(DSO_handle))) == NULL) return NULL;
  
  dso_handle->handle=d_handle; /* needed to close again */
  dso_handle->function_list=function_list;
  if ( (dso_handle->filename=(char*)malloc(strlen(file))) == NULL) { free(dso_handle); return NULL; }
  strcpy(dso_handle->filename,file);
  
  return (void*)dso_handle;
}

undef_int
DSO_close(void *ptr) {
  DSO_handle *handle=(DSO_handle*) ptr;
  return !dlclose(handle->handle);
}

#endif
