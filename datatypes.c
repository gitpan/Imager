#include "datatypes.h"
#include <stdlib.h>


struct octt *
octt_new() {
  int i;
        struct octt *t;

        t=(struct octt*)mymalloc(sizeof(struct octt));
        for(i=0;i<8;i++) t->t[i]=NULL;
        t->cnt=0;
        return t;
}


/* returns 1 if the colors wasn't in the octtree already */


int
octt_add(struct octt *ct,unsigned char r,unsigned char g,unsigned char b) {
  struct octt *c;
  int i,cm;
  int ci,idx[8];
  int rc;
  rc=0;
  c=ct;
  /*  printf("[r,g,b]=[%d,%d,%d]\n",r,g,b); */
  ct->cnt++;
  for(i=7;i>-1;i--) {
    cm=1<<i;
    ci=((!!(r&cm))<<2)+((!!(g&cm))<<1)+!!(b&cm); 
    /* printf("idx[%d]=%d\n",i,ci); */
    if (c->t[ci] == NULL) { c->t[ci]=octt_new(); rc=1; }
    c=c->t[ci];
    c->cnt++;
    idx[i]=ci;
  }
  return rc;
}


void
octt_delete(struct octt *ct) {
  int i;
  for(i=0;i<8;i++) if (ct->t[i] != NULL) octt_delete(ct->t[i]);  /* do not free instance here because it will free itself */
  free(ct);
}


void
octt_dump(struct octt *ct) {
	int i;
	printf("node [0x%08X] -> (%d)\n",ct,ct->cnt);
	for(i=0;i<8;i++) if (ct->t[i] != NULL) printf("[ %d ] -> 0x%08X\n",i,ct->t[i]);	
	for(i=0;i<8;i++) if (ct->t[i] != NULL) octt_dump(ct->t[i]);
}

/* note that all calls of octt_count are operating on the same overflow 
   variable so all calls will know at the same time if an overflow
   has occured and stops there. */

void
octt_count(struct octt *ct,int *tot,int max,int *overflow) {
  int i,c;
  c=0;
  if (!(*overflow)) return;
  for(i=0;i<8;i++) if (ct->t[i]!=NULL) { 
    octt_count(ct->t[i],tot,max,overflow);
    c++;
  }
  if (!c) (*tot)++;
  if ( (*tot) > (*overflow) ) *overflow=0;
}
