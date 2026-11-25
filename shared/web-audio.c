#include "BrownNoiseDSP.h"
#include <stdlib.h>
enum { ENCapacity = 4096 };
typedef struct { BNMixGenerator *mix; float left[ENCapacity], right[ENCapacity]; } ENAudio;
ENAudio *ENAudioCreate(unsigned seed) {
    ENAudio *a = calloc(1, sizeof(*a));
    if (!a) return NULL;
    a->mix = BNMixCreate(seed);
    if (!a->mix) { free(a); return NULL; }
    return a;
}
void ENAudioDestroy(ENAudio *a) { BNMixDestroy(a->mix); free(a); }
void ENAudioConfigure(ENAudio *a, int low, int mid, int high, int stereo, int offset) {
    BNMixSetLevels(a->mix, low, mid, high); BNMixSetStereo(a->mix, stereo); BNMixSetOffsetDB(a->mix, offset);
}
void ENAudioPlay(ENAudio *a, int play) { BNMixSetPlaying(a->mix, play); }
int ENAudioSilent(ENAudio *a) { return BNMixIsSilent(a->mix); }
void ENAudioRender(ENAudio *a, unsigned frames) {
    if (frames <= ENCapacity) BNMixRender(a->mix, a->left, a->right, frames);
}
float *ENAudioLeft(ENAudio *a) { return a->left; }
float *ENAudioRight(ENAudio *a) { return a->right; }
double ENAudioFrames(ENAudio *a) { return (double)BNMixRenderedFrames(a->mix); }
