#include "dynaload.h"

/* These functions are all shared - then comes platform dependant code */


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


#ifdef OS_hpux

void*
DSO_open(char* file,char** evalstring) {
  shl_t tt_handle;
  void *d_handle,**plugin_symtab,**plugin_utiltab;
  int  rc,*iptr, (*fptr)(int);
  func_ptr *function_list;
  DSO_handle *dso_handle;
  int i;

  *evalstring=NULL;

  

  if ( (tt_handle = shl_load(file, BIND_DEFERRED,0L)) == NULL) return NULL; 
  if ( (shl_findsym(&tt_handle, "evalstr",TYPE_UNDEFINED,(void*)evalstring))) return NULL;
  if ( (shl_findsym(&tt_handle, "symbol_table",TYPE_UNDEFINED,(void*)&plugin_symtab))) return NULL;
  if ( (shl_findsym(&tt_handle, "util_table",TYPE_UNDEFINED,&plugin_utiltab))) return NULL;

  (*plugin_symtab)=&symbol_table;
  (*plugin_utiltab)=&UTIL_table;

  if ( (shl_findsym(&tt_handle, "function_list",TYPE_UNDEFINED,(func_ptr*)&function_list))) return NULL;

  if ( (dso_handle=(DSO_handle*)malloc(sizeof(DSO_handle))) == NULL) return NULL;

  dso_handle->handle=tt_handle; /* needed to close again */
  dso_handle->function_list=function_list;
  if ( (dso_handle->filename=(char*)malloc(strlen(file))) == NULL) { free(dso_handle); return NULL; }
  strcpy(dso_handle->filename,file);

  return (void*)dso_handle;
}

undef_int
DSO_close(void *ptr) {
  DSO_handle *handle=(DSO_handle*) ptr;
  return !shl_unload((handle->handle));
}


#else

/* OS/2 has no dlclose; Perl doesn't provide one. */
#ifdef __EMX__ /* OS/2 */
int
dlclose(minthandle_t h) {
  return DosFreeModule(h) ? -1 : 0;
}
#endif /* __EMX__ */


void*
DSO_open(char* file,char** evalstring) {
  void *d_handle,**plugin_symtab,**plugin_utiltab;
  int  rc,*iptr, (*fptr)(int);
  func_ptr *function_list;
  DSO_handle *dso_handle;
  int i;
  void (*f)(void *s,void *u); /* these will just have to be void for now */
  
  *evalstring=NULL;

  mm_log( (1,"DSO_open(file '%s' (0x%08X), evalstring 0x%08X)\n",file,file,evalstring) );

  if ( (d_handle = dlopen(file, RTLD_LAZY)) == NULL) {
    mm_log( (1,"DSO_open: dlopen failed: %s.\n",dlerror()) );
    return NULL;
  }

  if ( (*evalstring = (char *)dlsym(d_handle, I_EVALSTR)) == NULL) {
    mm_log( (1,"DSO_open: dlsym didn't find '%s': %s.\n",I_EVALSTR,dlerror()) );
    return NULL;
  }

  /*

    I'll just leave this thing in here for now if I need it real soon

   mm_log( (1,"DSO_open: going to dlsym '%s'\n", I_SYMBOL_TABLE ));
   if ( (plugin_symtab = dlsym(d_handle, I_SYMBOL_TABLE)) == NULL) {
     mm_log( (1,"DSO_open: dlsym didn't find '%s': %s.\n",I_SYMBOL_TABLE,dlerror()) );
     return NULL;
   }
  
   mm_log( (1,"DSO_open: going to dlsym '%s'\n", I_UTIL_TABLE ));
    if ( (plugin_utiltab = dlsym(d_handle, I_UTIL_TABLE)) == NULL) {
     mm_log( (1,"DSO_open: dlsym didn't find '%s': %s.\n",I_UTIL_TABLE,dlerror()) );
     return NULL;
   }

  */


  mm_log( (1,"DSO_open: going to dlsym '%s'\n", I_INSTALL_TABLES ));
  if ( (f = dlsym(d_handle, I_INSTALL_TABLES)) == NULL) {
    mm_log( (1,"DSO_open: dlsym didn't find '%s': %s.\n",I_INSTALL_TABLES,dlerror()) );
    return NULL;
  }

  mm_log( (1,"Calling install_tables\n") );
  f(&symbol_table,&UTIL_table);
  mm_log( (1,"Call ok.\n") );

  /* (*plugin_symtab)=&symbol_table;
     (*plugin_utiltab)=&UTIL_table; */
  
  mm_log( (1,"DSO_open: going to dlsym '%s'\n", I_FUNCTION_LIST ));
  if ( (function_list=(func_ptr *)dlsym(d_handle, I_FUNCTION_LIST)) == NULL) {
    mm_log( (1,"DSO_open: dlsym didn't find '%s': %s.\n",I_FUNCTION_LIST,dlerror()) );
    return NULL;
  }
  
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








