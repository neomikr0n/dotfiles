#define main controller_main
#include "rme-volume.c"
#undef main
#include <assert.h>
int main(void){
 assert(allowed_up(-120,1));assert(!allowed_up(-119,1));
 assert(!allowed_up(-120,2));assert(allowed_up(-180,2));
 for(int v=-1145;v<=60;v++){
  int w=v&4095;unsigned char b[]={0xf0,0,0x20,0xd,0x71,1,0x1b,(w>>7)&31,w&127,0xf7};
  memset(seen,0,sizeof(seen));parse(b,sizeof(b));assert(seen[12]&&values[12]==v);
 }
 unsigned char mute[]={0xf0,0,0x20,0xd,0x71,1,0x1b,0x60,1,0xf7};
 memset(seen,0,sizeof(seen));parse(mute,sizeof(mute));assert(seen[15]&&values[15]==1&&!seen[12]);
 mute[4]=0x73;memset(seen,0,sizeof(seen));parse(mute,sizeof(mute));assert(!seen[15]);
 puts("PASS: volume range, -12 dB ceiling, reference ceiling, mute, model validation");
}
