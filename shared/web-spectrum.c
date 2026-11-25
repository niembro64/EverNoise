#include "SpectrumAnalysis.h"
#include <stdlib.h>
enum { ENInputCapacity = 4096, ENColumnCapacity = 6 };
typedef struct {
    BNSpectrum *s;
    float input[ENInputCapacity * 2], columns[ENColumnCapacity * BNSpectrumRows];
    BNCapturedFrame frames[ENInputCapacity];
    uint64_t ends[ENColumnCapacity];
} ENSpectrum;
ENSpectrum *ENSpectrumCreate(void) {
    ENSpectrum *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    s->s = BNSpectrumCreate();
    if (!s->s) { free(s); return NULL; }
    return s;
}
void ENSpectrumDestroy(ENSpectrum *s) { BNSpectrumDestroy(s->s); free(s); }
float *ENSpectrumInput(ENSpectrum *s) { return s->input; }
float *ENSpectrumColumns(ENSpectrum *s) { return s->columns; }
int ENSpectrumConsume(ENSpectrum *s, unsigned count, double startFrame) {
    if (count > ENInputCapacity) return 0;
    for (unsigned i = 0; i < count; ++i) s->frames[i] = (BNCapturedFrame){s->input[i*2],s->input[i*2+1],(uint64_t)startFrame+i};
    return BNSpectrumConsume(s->s, s->frames, count, s->columns, s->ends, ENColumnCapacity);
}
