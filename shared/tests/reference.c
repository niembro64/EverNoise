#include "../web-audio.c"
#include "SpectrumAnalysis.h"
#include <stdio.h>
#include <string.h>
#include <math.h>
int main(int argc,char**argv){
 if(argc!=3)return 1;
 FILE *pcm=fopen(argv[1],"wb");if(!pcm)return 2;
 ENAudio*a=ENAudioCreate(12345);ENAudioConfigure(a,3,3,2,1,0);ENAudioPlay(a,1);
 for(int n=0;n<200;n++){ENAudioRender(a,1024);for(int i=0;i<1024;i++){fwrite(a->left+i,4,1,pcm);fwrite(a->right+i,4,1,pcm);}}
 fclose(pcm);ENAudioDestroy(a);
 BNSpectrum*s=BNSpectrumCreate();if(!s)return 3;BNCapturedFrame frames[4096];float columns[6*BNSpectrumRows];uint64_t ends[6];float last[BNSpectrumRows];
 for(int b=0;b<100;b++){for(int i=0;i<4096;i++){uint64_t f=b*4096+i;double x=sin(2*M_PI*1000*f/48000),lo=sin(2*M_PI*31*f/48000);frames[i]=(BNCapturedFrame){.1*x+.02*lo,-.1*x+.03*sin(2*M_PI*8000*f/48000),f};}unsigned n=BNSpectrumConsume(s,frames,4096,columns,ends,6);if(n)memcpy(last,columns+(n-1)*1024,sizeof(last));}
 FILE*out=fopen(argv[2],"wb");if(!out)return 4;fwrite(last,sizeof(last),1,out);fclose(out);BNSpectrumDestroy(s);return 0;
}
