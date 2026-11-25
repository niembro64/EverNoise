#include <jni.h>
#include <stdlib.h>
#include "BrownNoiseDSP.h"
#include "SpectrumAnalysis.h"
enum { Capacity = 2048, Columns = 4 };
typedef struct {
    BNMixGenerator *mix;
    BNCapture *capture;
    float left[Capacity], right[Capacity];
} Engine;
typedef struct { BNSpectrum *s; BNCapturedFrame frames[Capacity]; uint64_t ends[Columns]; } Analyzer;
#define FN(name) Java_io_niemo_evernoise_NativeAudio_##name
JNIEXPORT jlong JNICALL FN(create)(JNIEnv *env, jclass c, jlong seed) {
    (void)env; (void)c;
    Engine *e = calloc(1,sizeof(*e)); if (!e) return 0;
    e->mix = BNMixCreate(seed); e->capture = BNCaptureCreate();
    if (!e->mix || !e->capture) { if(e->mix) BNMixDestroy(e->mix); if(e->capture) BNCaptureDestroy(e->capture); free(e); return 0; }
    return (jlong)e;
}
JNIEXPORT void JNICALL FN(destroy)(JNIEnv *env,jclass c,jlong handle) { (void)env;(void)c; Engine *e=(Engine*)handle; BNCaptureDestroy(e->capture); BNMixDestroy(e->mix);free(e); }
JNIEXPORT void JNICALL FN(configure)(JNIEnv *env,jclass c,jlong handle,jint low,jint mid,jint high,jboolean stereo,jint offset,jboolean capture) {
    (void)env;(void)c; Engine *e=(Engine*)handle; BNMixSetLevels(e->mix,low,mid,high); BNMixSetStereo(e->mix,stereo); BNMixSetOffsetDB(e->mix,offset); BNCaptureSetEnabled(e->capture,capture);
}
JNIEXPORT void JNICALL FN(play)(JNIEnv *env,jclass c,jlong handle,jboolean play) { (void)env;(void)c; BNMixSetPlaying(((Engine*)handle)->mix,play); }
JNIEXPORT void JNICALL FN(fadeIn)(JNIEnv *env,jclass c,jlong handle) { (void)env;(void)c; BNMixBeginFadeIn(((Engine*)handle)->mix); }
JNIEXPORT jboolean JNICALL FN(silent)(JNIEnv *env,jclass c,jlong handle) { (void)env;(void)c;return BNMixIsSilent(((Engine*)handle)->mix); }
JNIEXPORT jlong JNICALL FN(frames)(JNIEnv *env,jclass c,jlong handle) { (void)env;(void)c;return BNMixRenderedFrames(((Engine*)handle)->mix); }
JNIEXPORT void JNICALL FN(render)(JNIEnv *env,jclass c,jlong handle,jobject buffer,jint count) {
    (void)c; Engine *e=(Engine*)handle; float *out=(*env)->GetDirectBufferAddress(env,buffer);
    if (!out || count<0 || count>Capacity || (*env)->GetDirectBufferCapacity(env,buffer)<count*8) return;
    BNMixRender(e->mix,e->left,e->right,count); BNCapturePlanar(e->capture,e->left,e->right,count);
    for(int i=0;i<count;i++){out[2*i]=e->left[i];out[2*i+1]=e->right[i];}
}
JNIEXPORT jlong JNICALL FN(createAnalyzer)(JNIEnv *env,jclass c) { (void)env;(void)c;Analyzer *a=calloc(1,sizeof(*a));if(!a)return 0;a->s=BNSpectrumCreate();if(!a->s){free(a);return 0;}return (jlong)a; }
JNIEXPORT void JNICALL FN(destroyAnalyzer)(JNIEnv *env,jclass c,jlong handle) { (void)env;(void)c;Analyzer *a=(Analyzer*)handle;BNSpectrumDestroy(a->s);free(a); }
JNIEXPORT jint JNICALL FN(analyze)(JNIEnv *env,jclass c,jlong handle,jlong analyzer,jobject buffer) {
    (void)c;Engine *e=(Engine*)handle;Analyzer *a=(Analyzer*)analyzer;float *out=(*env)->GetDirectBufferAddress(env,buffer);
    if(!out || (*env)->GetDirectBufferCapacity(env,buffer)<Columns*BNSpectrumRows*4)return 0;
    unsigned count=BNCaptureRead(e->capture,a->frames,Capacity);
    if(!count)return 0;
    return BNSpectrumConsume(a->s,a->frames,count,out,a->ends,Columns);
}
