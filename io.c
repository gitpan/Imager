#include "io.h"
#include <stdlib.h>
#include <unistd.h>





/* FIXME: make allocation dynamic */

#ifdef IMAGER_DEBUG_MALLOC

#define MAXMAL 1024
#define MAXDESC 65

typedef struct {
  void* point;
  size_t size;
  char  comm[MAXDESC];
} malloc_entry;

malloc_entry malloc_pointers[MAXMAL];
static int malloc_need_init=1;

#define mymalloc(x) (mymalloc_file_line(x,__FILE__,__LINE__)) 

void
malloc_state() {
  int i, total;
  total=0;
  mm_log((0,"malloc_state()\n"));
  for(i=0;i<MAXMAL;i++) if (malloc_pointers[i].point!=NULL) {
    mm_log((0,"%d: %d (0x%x) : %s\n",i,malloc_pointers[i].size,malloc_pointers[i].point,malloc_pointers[i].comm));
    total+=malloc_pointers[i].size;
  }
  if (total==0 ) mm_log((0,"No memory currently used!\n"))
  else mm_log((0,"total: %d\n",total));
}

void*
mymalloc_file_line(int size,char* file,int line) {
  void *buf;
  int i;
  if (malloc_need_init) {
    for(i=0;i<MAXMAL;i++) malloc_pointers[i].point=NULL;
    malloc_need_init=0;
    atexit(malloc_state);
  }
  
  if ((buf=malloc(size))==NULL) { mm_log((1,"Unable to allocate %i for %s (%i)\n", size, file, line)); exit(3); }

  for(i=0;i<MAXMAL;i++) if (malloc_pointers[i].point==NULL) {
    malloc_pointers[i].point=buf;
    malloc_pointers[i].size=size;
    sprintf(malloc_pointers[i].comm,"%s (%d)",file,line);
    mm_log((2,"pointer %i %i bytes allocated for %s (%d)\n", i, size, file, line));
    return buf; 
  }
  mm_log((0,"more than %d segments allocated at %s (%d)\n",MAXMAL, file, line));
  exit(255);
  return NULL;
}

void*
mymalloc_comm(int size,char *comm) {
  void *buf;
  int i;
  if (malloc_need_init) {
    for(i=0;i<MAXMAL;i++) malloc_pointers[i].point=NULL;
    malloc_need_init=0;
  }
  
  if ((buf=malloc(size))==NULL) { mm_log((1,"Unable to malloc.\n")); exit(3); }

  for(i=0;i<MAXMAL;i++) if (malloc_pointers[i].point==NULL) {
    malloc_pointers[i].point=buf;
    malloc_pointers[i].size=size;
    strncpy(malloc_pointers[i].comm,comm,MAXDESC-1);
    return buf;
  }
  mm_log((0,"more than %d segments malloced\n",MAXMAL));
  exit(255);
  return NULL;
}



void
myfree_file_line(void *p, char *file, int line) {
  int i;
  free(p);
  for(i=0;i<MAXMAL;i++) 
    if (malloc_pointers[i].point==p) {
        mm_log((1,"pointer %i (%s) freed at %s (%i)\n", i, malloc_pointers[i].comm, file, line));
        malloc_pointers[i].point=NULL;
    }
}

#else 

#define malloc_comm(a,b) (mymalloc(a))

void
malloc_state() {
  printf("malloc_state: not in debug mode\n");
}

void*
mymalloc(int size) {
  void *buf;
  if ((buf=malloc(size))==NULL) { fprintf(stderr,"Unable to malloc.\n"); exit(3); }
  return buf;
}

void
myfree(void *p) {
  free(p);
}

#endif /* IMAGER_MALLOC_DEBUG */










int
min(int a,int b) {
  if (a<b) return a; else return b;
}

int
max(int a,int b) {
  if (a>b) return a; else return b;
}

int
myread(int fd,void *buf,int len) {
  unsigned char* bufc;
  int bc,rc;
  bufc=(unsigned char*)buf;
  bc=0;
  while(((rc=read(fd,bufc+bc,len-bc))>0) && (bc!=len)) bc+=rc;
  if (rc<0) return rc;
  else return bc;
}

int
mywrite(int fd,void *buf,int len) {
  unsigned char* bufc;
  int bc,rc;
  bufc=(unsigned char*)buf;
  bc=0;
  while(((rc=write(fd,bufc+bc,len-bc))>0) && (bc!=len)) bc+=rc;
  if (rc<0) return rc;
  else return bc;
}

void
interleave(unsigned char *inbuffer,unsigned char *outbuffer,int rowsize,int channels) {
  int ch,ind,i;
  i=0;
  if (inbuffer==outbuffer) return; /* Check if data is already in interleaved format */
  for(ind=0;ind<rowsize;ind++) for (ch=0;ch<channels;ch++) outbuffer[i++]=inbuffer[rowsize*ch+ind]; 
}










