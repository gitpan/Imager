#ifndef _IOLAYER_H_
#define _IOLAYER_H_


/* How the IO layer works:
 * 
 * Start by getting an io_glue object.  Then define its
 * datasource via io_obj_setp_buffer or io_obj_setp_cb.  Before
 * using the io_glue object be sure to call io_glue_commit_types().
 * After that data can be read via the io_glue->readcb() method.
 *
 */


#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>

#define BBSIZ 1024
#define IO_FAKE_SEEK 1<<0L
#define IO_TEMP_SEEK 1<<1L


typedef union { int i; void *p; } iorp;

typedef enum { FDSEEK, FDNOSEEK, BUFFER, CBSEEK, CBNOSEEK } io_type;

struct _io_glue;

/* Callbacks we give out */

typedef ssize_t(*readp) (struct _io_glue *ig, void *buf, size_t count);
typedef ssize_t(*writep)(struct _io_glue *ig, const void *buf, size_t count);
typedef off_t  (*seekp) (struct _io_glue *ig, off_t offset, int whence);
typedef void   (*closep)(struct _io_glue *ig);
typedef ssize_t(*sizep) (struct _io_glue *ig);



/* Callbacks we get */

typedef ssize_t(*readl) (int fd, void *buf, size_t count);
typedef ssize_t(*writel)(int fd, const void *buf, size_t count);
typedef off_t  (*seekl) (int fd, off_t offset, int whence);
typedef ssize_t(*sizel) (int fd);

extern char *io_type_names[];


struct _io_blink {
  char buf[BBSIZ];
  size_t len;
  struct _io_blink *next;
  struct _io_blink *prev;
};

/* Structures that describe callback interfaces */

typedef struct _io_blink io_blink;
typedef struct {
  off_t offset;
  off_t cpos;
} io_ex_rseek;


typedef struct {
  off_t offset;
  off_t cpos;
  io_blink *head;
  io_blink *tail;
  io_blink *cp;
} io_ex_fseek;


/* Structures to describe data sources */

typedef struct {
  io_type	type;
  int		fd;
} io_fdseek;

typedef struct {
  io_type	type;		/* Must be first parameter */
  char		*name;		/* Data source name */
  char		*c;
  size_t	len;
} io_buffer;

typedef struct {
  io_type	type;		/* Must be first parameter */
  char		*name;		/* Data source name */
  void		*p;		/* Callback data */
  readl		readcb;
  writel	writecb;
  seekl		seekcb;
} io_cb;

typedef union {
  io_type       type;
  io_fdseek     fdseek;
  io_buffer	buffer;
  io_cb		cb;
} io_obj;

typedef struct _io_glue {
  io_obj	source;
  int		flags;		/* Flags */
  void		*exdata;	/* Pair specific data */
  readp		readcb;
  writep	writecb;
  seekp		seekcb;
  closep	closecb;
  sizep		sizecb;
} io_glue;

void io_obj_setp_buffer  (io_obj *io, void *p, size_t len);
void io_obj_setp_cb      (io_obj *io, void *p, readl readcb, writel writecb, seekl seekcb);
void io_glue_commit_types(io_glue *ig);
void io_glue_gettypes    (io_glue *ig, int reqmeth);


/* XS functions */
io_glue *io_new_fd(int fd);
void io_glue_DESTROY(io_glue *ig);

#endif /* _IOLAYER_H_ */