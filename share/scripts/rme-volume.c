/* RME official MIDI protocol v0.2. Only Line Out volume and mute (address 3,index 12/15).
 * No saved-volume assumptions, no automatic unmute/unlock, no gain or EQ writes. */
#include <alsa/asoundlib.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
static snd_seq_t *seq;
static int port, remote=-1, rp=-1;
static int values[32], seen[32];
static long ms(void){struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
static void die(const char *s){fprintf(stderr,"RME: %s\n",s);exit(1);}
static void send_bytes(unsigned char *b,int n){snd_seq_event_t e;snd_seq_ev_clear(&e);snd_seq_ev_set_source(&e,port);snd_seq_ev_set_dest(&e,remote,rp);snd_seq_ev_set_direct(&e);snd_seq_ev_set_sysex(&e,n,b);if(snd_seq_event_output_direct(seq,&e)<0)die("Error MIDI; no reintento de escritura.");}
static void parse(unsigned char *b,int n){
 if(n<7 || memcmp(b,"\xf0\x00\x20\x0d\x71\x01",6) || b[n-1]!=0xf7 || (n-7)%3)return;
 for(int i=6;i<n-1;i+=3){if((b[i]|b[i+1]|b[i+2])&128)return;int addr=b[i]>>3,idx=((b[i]&7)<<2)|(b[i+1]>>5);int v=((b[i+1]&31)<<7)|b[i+2];if(v&2048)v-=4096;if(addr==3){values[idx]=v;seen[idx]=1;}}
}
static int read_mode=1; /* 0: drain updates, 1: full state, 2: volume confirmation */
static int complete(void){if(read_mode==0)return 0;if(read_mode==2)return seen[12];if(read_mode==3)return seen[15];return seen[12]&&seen[13]&&seen[2]&&seen[3]&&seen[15]&&seen[16];}
static int allowed_up(int target,int ref){return target<=-150 && target+(-50+60*ref)+60<=-80;}
static void read_for(int duration){unsigned char buf[4096];int len=0;long end=ms()+duration;while(ms()<end){snd_seq_event_t *e=NULL;int r=snd_seq_event_input(seq,&e);if(r==-EAGAIN){usleep(2000);continue;}if(r<0)die("Error leyendo MIDI.");if(e->source.client==remote && e->source.port==rp && e->type==SND_SEQ_EVENT_SYSEX){unsigned char *p=e->data.ext.ptr;for(unsigned int i=0;i<e->data.ext.len;i++){unsigned char c=p[i];if(c>=0xf8)continue;if(c==0xf0)len=0;if(len<(int)sizeof(buf))buf[len++]=c;else len=0;if(c==0xf7){parse(buf,len);len=0;}}}snd_seq_free_event(e);if(complete())return;}}
static void query(void){snd_seq_drop_input(seq);memset(seen,0,sizeof(seen));unsigned char b[]={0xf0,0,0x20,0x0d,0x71,3,9,0xf7};send_bytes(b,sizeof(b));read_for(180);if(!seen[12]||!seen[13]||!seen[2]||!seen[3]||!seen[15]||!seen[16])die("Respuesta incompleta: no se cambia el volumen.");if(values[12]<-1145||values[12]>60||values[2]<0||values[2]>3||values[3]<0||values[3]>1||values[13]<0||values[13]>1||values[15]<0||values[15]>1||values[16]<0||values[16]>1)die("Respuesta fuera de rango.");}
int main(int argc,char **argv){
 if(argc!=2 || (strcmp(argv[1],"status")&&strcmp(argv[1],"up")&&strcmp(argv[1],"down")&&strcmp(argv[1],"check-up")&&strcmp(argv[1],"check-down")&&strcmp(argv[1],"up5")&&strcmp(argv[1],"down5")&&strcmp(argv[1],"check-up5")&&strcmp(argv[1],"check-down5")&&strcmp(argv[1],"mute")&&strcmp(argv[1],"check-mute")))die("Uso: rme-volume {status|up|down|up5|down5|mute|check-up|check-down|check-up5|check-down5|check-mute}");
 char lockpath[256];snprintf(lockpath,sizeof(lockpath),"/run/user/%u/rme-volume.lock",getuid());int fd=open(lockpath,O_CREAT|O_RDWR|O_NOFOLLOW,0600);if(fd<0)die("No se puede crear bloqueo.");if(flock(fd,LOCK_EX|LOCK_NB)<0)return 0;
 /* Limit held keys to at most 10 dB/s; no pending queue of raises. */
 if(!strcmp(argv[1],"up")||!strcmp(argv[1],"down")){
  long last=0,now=ms();if(pread(fd,&last,sizeof(last),0)==sizeof(last)&&now>=last&&now-last<100)return 0;
  if(pwrite(fd,&now,sizeof(now),0)!=sizeof(now))die("No se puede limitar la repeticion.");
 }
 if(snd_seq_open(&seq,"default",SND_SEQ_OPEN_DUPLEX,SND_SEQ_NONBLOCK)<0)die("No hay acceso al secuenciador ALSA.");
 snd_seq_set_client_name(seq,"RME volume keys");
 snd_seq_client_info_t *ci;snd_seq_port_info_t *pi;snd_seq_client_info_alloca(&ci);snd_seq_port_info_alloca(&pi);snd_seq_client_info_set_client(ci,-1);
 while(snd_seq_query_next_client(seq,ci)>=0){const char *name=snd_seq_client_info_get_name(ci);if(strcmp(name,"ADI-2 DAC (51100523)"))continue;int c=snd_seq_client_info_get_client(ci);snd_seq_port_info_set_client(pi,c);snd_seq_port_info_set_port(pi,-1);while(snd_seq_query_next_port(seq,pi)>=0){unsigned caps=snd_seq_port_info_get_capability(pi);if((caps&(SND_SEQ_PORT_CAP_READ|SND_SEQ_PORT_CAP_WRITE))==(SND_SEQ_PORT_CAP_READ|SND_SEQ_PORT_CAP_WRITE)){if(remote!=-1)die("Puerto ambiguo.");remote=c;rp=snd_seq_port_info_get_port(pi);}}}
 if(remote<0)die("RME 51100523 no conectado por USB.");
 port=snd_seq_create_simple_port(seq,"volume",SND_SEQ_PORT_CAP_READ|SND_SEQ_PORT_CAP_WRITE|SND_SEQ_PORT_CAP_SUBS_READ|SND_SEQ_PORT_CAP_SUBS_WRITE,SND_SEQ_PORT_TYPE_APPLICATION);
 if(port<0||snd_seq_connect_from(seq,port,remote,rp)<0)die("No se puede suscribir a MIDI.");
 query();int v=values[12],ref=values[2],aut=values[3];printf("Line Out %.1f dB; Ref=%d Auto=%d Lock=%d Mute=%d Dim=%d\n",v/10.,ref,aut,values[13],values[15],values[16]);
 if(!strcmp(argv[1],"status")){snd_seq_close(seq);return 0;}
 if(!strcmp(argv[1],"mute")||!strcmp(argv[1],"check-mute")){
  int before=values[15],target=!before;
  /* Muting is always allowed. Unmuting must obey the same output ceiling. */
  if(!target&&(aut||!allowed_up(v,ref)))die("Limite o Auto Ref: no se reactiva el sonido por encima del techo.");
  if(!strcmp(argv[1],"check-mute")){printf("Simulacion Mute: %d -> %d (sin escritura).\n",before,target);snd_seq_close(seq);return 0;}
  read_mode=0;read_for(5);read_mode=1;
  if(values[15]!=before||(!target&&(values[12]!=v||values[2]!=ref||values[3]!=aut)))die("Estado cambio durante la operacion; no se escribe.");
  unsigned char msg[]={0xf0,0,0x20,0x0d,0x71,2,0x1b,0x60,target,0xf7};
  seen[15]=0;send_bytes(msg,sizeof(msg));
  unsigned char request[]={0xf0,0,0x20,0x0d,0x71,3,9,0xf7};send_bytes(request,sizeof(request));
  read_mode=3;read_for(180);read_mode=1;
  if(!seen[15]||values[15]!=target)die("El RME no confirmo Mute; no se reintenta.");
  printf("RME Mute: %s\n",target?"ON":"OFF");snd_seq_close(seq);return 0;
 }
 int up=strstr(argv[1],"up")!=NULL,check=!strncmp(argv[1],"check-",6);
 if(values[13])die("Volumen bloqueado en el RME: desbloquear manualmente; no se modifica Lock.");
 if(up && (values[15]||values[16]))die("Mute/Dim activo: no se permite subir.");
 /* User-authorized ceiling: -15 dB, Ref +1 dBu RCA
  * (+7 dBu XLR), hence nominal unprocessed full-scale output <= -8 dBu.
  * Auto Ref uses a different scale: fail closed on increases until calibrated.
  * This is an operational bound, not a guarantee of safe acoustic SPL. */
 if(up && aut)die("Auto Ref activo: subida deshabilitada hasta calibrar la escala.");
 int step=strchr(argv[1],'5')?50:10;
 int target=v+(up?step:-step);
 if(up){int ceiling=-80-(-50+60*ref)-60;if(ceiling>-150)ceiling=-150;if(v>=ceiling)die("Limite conservador alcanzado: no se sube.");if(target>ceiling)target=ceiling;}if(target < -1145)target=-1145;
 if(up && !allowed_up(target,ref))die("Limite conservador alcanzado: no se sube.");
 if(target==v){snd_seq_close(seq);return 0;}
 if(check){printf("Simulacion: %.1f -> %.1f dB (sin escritura).\n",v/10.,target/10.);snd_seq_close(seq);return 0;}
 /* Consume live device updates before writing; reject concurrent changes.
  * Do not request a second full dump (it adds transport latency). */
 read_mode=0;read_for(5);read_mode=1;if(values[12]!=v||values[2]!=ref||values[3]!=aut||values[13]||(up&&(values[15]||values[16])))die("Estado cambio durante la operacion; no se escribe.");
 int word=target&4095;unsigned char b[]={0xf0,0,0x20,0x0d,0x71,2,0x1b,(word>>7)&31,word&127,0xf7};seen[12]=0;send_bytes(b,sizeof(b));
 unsigned char confirm[]={0xf0,0,0x20,0x0d,0x71,3,9,0xf7};send_bytes(confirm,sizeof(confirm));
 read_mode=2;read_for(180);read_mode=1;if(!seen[12]||values[12]!=target)die("El RME no confirmo el cambio; no se reintenta.");printf("RME Line Out: %.1f dB\n",target/10.);snd_seq_close(seq);return 0;
}
