#include "image.h"
#include "io.h"
#include "log.h"


i_img *
i_readppm(i_img *im,int fd) {
  int type;
  int ic,rc,x,y,ind;
  char buf[256];
  memset(buf,0,256);
  read(fd,buf,3);
  
  /*  fprintf(stderr,"'%s'\n",buf); */
  
  type=0;
  if (!strncmp(buf,"P6\n",3)) { type=1; mm_log((1,"i_readppm: Type is P6\n")); }
  if (!strncmp(buf,"P3\n",3)) { type=2; mm_log((1,"i_readppm: Type is P3\n")); }
  if (!type) { mm_log((1,"Format is not ppm\n")); i_img_destroy(im); return NULL; }

  while(rc=myread(fd,buf,1)>0) { 
    if (buf[0] == '#') ic=1;
    if (!ic) { break; }
    if (buf[0] == '\n') ic=0;
    /* fprintf(stderr,"%c",buf[0]); */
  }
  lseek(fd, -1,SEEK_CUR);
  
  memset(buf,0,256);
  ind=0;
  while(rc=myread(fd,&buf[ind],1)>0) { 
    if (buf[ind] == '\n') break;
    /*    fprintf(stderr,"%c",buf[ind]); */
    ind++;
  }
  
  sscanf(buf,"%d %d\n",&x,&y);
  mm_log((1,"i_readppm: x=%d y=%d\n",x,y));
  
  while(rc=myread(fd,&buf[0],1)>0) { if (buf[0] == '\n') break; }
  
  im=i_img_empty(im,x,y);
  
  rc=myread(fd,im->data,im->bytes);
  if (rc<0) {
    mm_log((1,"i_readppm: unable to read ppm data.\n"));
    return(0);
  }

  return im;
}

undef_int
i_writeppm(i_img *im,int fd) {
  char header[255];
  int rc,bc;

  mm_log((1,"i_writeppm(im* 0x%x,fd %d)\n",im,fd));
  if (im->channels!=3) {
    mm_log((1,"i_writeppm: ppm is 3 channel only (current image is %d)\n",im->channels));
    return(0);
  }
  
  sprintf(header,"P6\n#CREATOR: Imager\n%d %d\n255\n",im->xsize,im->ysize);
  
  if (mywrite(fd,header,strlen(header))<0) {
    mm_log((1,"i_writeppm: unable to write ppm header.\n"));
    return(0);
  }
  
  rc=mywrite(fd,im->data,im->bytes);
  if (rc<0) {
    mm_log((1,"i_writeppm: unable to write ppm data.\n"));
    return(0);
  }
  return(1);
}







