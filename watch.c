#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/aio.h>
#include <unistd.h>

#define BUFFER_SIZE sizeof(char)*1024
#define AIOCB_SIZE 1

static void signal_read_ready(union sigval event)
{
  printf( "nofied of read ready by :%d\n", event.sival_int );
}

static void setup_aio_read( struct aiocb *io_ops, int fd, volatile char *buffer )
{
  io_ops->aio_fildes = fd;
  io_ops->aio_offset = 0;
  io_ops->aio_buf = buffer;
  io_ops->aio_nbytes = 16;
  io_ops->aio_reqprio = 0;
  io_ops->aio_sigevent.sigev_notify = SIGEV_SIGNAL;
  io_ops->aio_sigevent.sigev_signo = SA_SIGINFO;
  io_ops->aio_sigevent.sigev_value.sival_int = fd; // pass the fd
  io_ops->aio_sigevent.sigev_notify_function = signal_read_ready;
  io_ops->aio_lio_opcode = LIO_READ;
}
static void setup_aio_readers( struct aiocb list[], int size, int fd, volatile char *buffer )
{
  int i;
  for( i = 0; i < size; ++i ){
    setup_aio_read( &(list[i]), fd, buffer );
  }
}

int main( int argc, char **argv )
{
  struct aiocb io_ops[AIOCB_SIZE];
  volatile char *buffer = malloc(BUFFER_SIZE);
  int fd = open("test.log",  O_RDONLY | O_NONBLOCK, 0000400 );

  setup_aio_readers( io_ops, AIOCB_SIZE, fd, buffer );

  printf( "calling...\n" );
  lio_listio( LIO_WAIT, (struct aiocb **)&io_ops, AIOCB_SIZE, NULL );
  sleep(1);
  printf( "called...\n" );

  close( fd );

  return 0;
}
