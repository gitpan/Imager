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

void
octt_add(struct octt *ct,unsigned char r,unsigned char g,unsigned char b) {
  struct octt *c;
  int i,cm;
  int ci,idx[8];
  c=ct;
  /*  printf("[r,g,b]=[%d,%d,%d]\n",r,g,b); */
  ct->cnt++;
  for(i=7;i>-1;i--) {
    cm=1<<i;
    ci=((!!(r&cm))<<2)+((!!(g&cm))<<1)+!!(b&cm); 
    /* printf("idx[%d]=%d\n",i,ci); */
    if (c->t[ci] == NULL) c->t[ci]=octt_new();
    c=c->t[ci];
    c->cnt++;
    idx[i]=ci;
  }
}

void
octt_dump(struct octt *ct) {
	int i;
	printf("node [0x%08X] -> (%d)\n",ct,ct->cnt);
	for(i=0;i<8;i++) if (ct->t[i] != NULL) printf("[ %d ] -> 0x%08X\n",i,ct->t[i]);	
	for(i=0;i<8;i++) if (ct->t[i] != NULL) octt_dump(ct->t[i]);
}

void
octt_count(struct octt *ct,int *tot) {
	int i,c;
	c=0;
	for(i=0;i<8;i++) if (ct->t[i]!=NULL) { 
		octt_count(ct->t[i],tot);
		c++;
	}
	if (!c) (*tot)++;
}

/*

int main() {
int colorcnt;
struct octt *ct;
ct=octt_new();
octt_add(ct,127,52,233);
octt_add(ct,127,52,233);
octt_add(ct,122,77,246);

octt_dump(ct);
colorcnt=0;
octt_count(ct,&colorcnt);
printf("colors %d\n",colorcnt);
}

*/



