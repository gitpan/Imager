#include "io.h"
#include "iolayer.h"
#include <stdlib.h>
#include <stdio.h>

#define IOL_DEB(x) 


char *io_type_names[] = { "FDSEEK", "FDNOSEEK", "BUFFER", "CBSEEK", "CBNOSEEK" };


/*
 * Callbacks for different sources 
 */

/* Read on an unseekable source */

/* fakeseek_read: read method for when emulating a seekable source */
  

/*
static
ssize_t
fakeseek_read(io_glue *ig, void *buf, size_t count) {
  io_ex_fseek *exdata = ig->exdata; 
  return 0;
}
*/



/*
 * Callbacks for sources that can seek 
 *
 */

static
ssize_t 
realseek_read(io_glue *ig, void *buf, size_t count) {
  io_ex_rseek *ier = ig->exdata;
  int fd           = (int)ig->source.cb.p;
  ssize_t       rc = 0;
  size_t        bc = 0;
  char       *cbuf = buf;

  IOL_DEB( printf("realseek_read: fd = %d, ier->cpos = %ld, buf = 0x%p, count = %d\n", fd, (long) ier->cpos, buf, count) );
  /* Is this a good idea? Would it be better to handle differently? skip handling? */
  while( count!=bc && (rc = ig->source.cb.readcb(fd,cbuf+bc,count-bc))>0 ) bc+=rc;
  
  ier->cpos += bc;
  IOL_DEB( printf("realseek_read: rc = %d, bc = %d\n", rc, bc) );
  return bc;
}


static
ssize_t 
realseek_write(io_glue *ig, const void *buf, size_t count) {
  io_ex_rseek *ier = ig->exdata;
  int           fd = (int)ig->source.cb.p;
  ssize_t       rc = 0;
  size_t        bc = 0;
  char       *cbuf = (char*)buf; 
  
  IOL_DEB( printf("realseek_write: fd = %d, ier->cpos = %ld, buf = 0x%p, count = %d\n", fd, (long) ier->cpos, buf, count) );
  /* Is this a good idea? Would it be better to handle differently? skip handling? */

  while( count!=bc && (rc = ig->source.cb.writecb(fd,cbuf+bc,count-bc))>0 ) bc+=rc;

  ier->cpos += bc;
  IOL_DEB( printf("realseek_write: rc = %d, bc = %d\n", rc, bc) );
  return bc;
}


static
void
realseek_close(io_glue *ig) {
  IOL_DEB( printf("realseek_close(ig 0x%p)\n", ig) );
  /* FIXME: Do stuff here */
}


static
off_t
realseek_seek(io_glue *ig, off_t offset, int whence) {
  /*  io_ex_rseek *ier = ig->exdata; Needed later */
  int fd           = (int)ig->source.cb.p;
  int rc;
  IOL_DEB( printf("realseek_seek(ig 0x%p, offset %ld, whence %d)\n", ig, (long) offset, whence) );
	rc = lseek(fd, offset, whence);

  IOL_DEB( printf("realseek_seek: rc %ld\n", (long) rc) );
  return rc;
  /* FIXME: How about implementing this offset handling stuff? */
}







/* Methods for setting up data source */

void
io_obj_setp_buffer(io_obj *io, void *p, size_t len) {
  io->buffer.type = BUFFER;
  io->buffer.c    = (char*) p;
  io->buffer.len  = len;
}

void
io_obj_setp_cb(io_obj *io, void *p, readl readcb, writel writecb, seekl seekcb) {
  io->cb.type    = CBSEEK;
  io->cb.p       = p;
  io->cb.readcb  = readcb;
  io->cb.writecb = writecb;
  io->cb.seekcb  = seekcb;
}

void
io_glue_commit_types(io_glue *ig) {
  io_ex_rseek *ier = mymalloc(sizeof(io_ex_rseek));
  /*
    io_type      inn = ig->source.type;
    printf("io_glue_commit_types(ig 0x%p)\n", ig);
    printf("io_glue_commit_types: source type %d (%s)\n", inn, io_type_names[inn]);
  */
  ier->offset = 0;
  ier->cpos   = 0;

  ig->exdata  = ier;
  ig->readcb  = realseek_read;
  ig->writecb = realseek_write;
  ig->seekcb  = realseek_seek;
  ig->closecb = realseek_close;
}

void
io_glue_gettypes(io_glue *ig, int reqmeth) {

  ig = NULL;
  reqmeth = 0;
  
  /* FIXME: Implement this function! */
  /* if (ig->source.type = 
     if (reqmeth & IO_BUFF) */ 

}


io_glue *
io_new_fd(int fd) {
  io_glue *ig = mymalloc(sizeof(io_glue));
  io_obj_setp_cb(&ig->source, (void*)fd, read, write, lseek);
  return ig;
}


void
io_glue_DESTROY(io_glue *ig) {
  free(ig);
  /* FIXME: Handle extradata and such */
}
