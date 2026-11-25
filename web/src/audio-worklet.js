import createAudio from "./wasm/audio.js";
class NoiseProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super();
    this.ready = false;
    this.playing = false;
    this.capture = false;
    this.batch = new Float32Array(4096);
    this.batchFrames = 0;
    this.frame = 0;
    this.ack = 0;
    this.port.onmessage = ({ data }) => {
      if (!this.ready) return;
      if (data.type === "settings") {
        this.settings = data.value;
        this.configure();
      }
      if (data.type === "play") {
        this.playing = data.value;
        this.ack = data.id;
        this.module._ENAudioPlay(this.handle, data.value ? 1 : 0);
      }
      if (data.type === "capture") {
        this.capture = data.value;
        this.batchFrames = 0;
      }
    };
    createAudio({
      locateFile: () => "audio.wasm",
      wasmBinary: options.processorOptions.wasm,
    })
      .then((module) => {
        this.module = module;
        this.handle = module._ENAudioCreate(options.processorOptions.seed);
        if (!this.handle) throw Error("Audio allocation failed");
        this.left = module._ENAudioLeft(this.handle) / 4;
        this.right = module._ENAudioRight(this.handle) / 4;
        this.settings = options.processorOptions.settings;
        this.configure();
        this.module._ENAudioPlay(this.handle, 0);
        this.ready = true;
        this.port.postMessage({ type: "ready" });
      })
      .catch((error) =>
        this.port.postMessage({ type: "error", message: error.message }),
      );
  }
  configure() {
    const s = this.settings;
    this.module._ENAudioConfigure(
      this.handle,
      s.low,
      s.mid,
      s.high,
      s.stereo ? 1 : 0,
      s.offset,
    );
  }
  process(inputs, outputs) {
    const [left, right] = outputs[0];
    if (!this.ready) return true;
    if (!this.playing && this.module._ENAudioSilent(this.handle)) {
      if (this.ack) {
        this.port.postMessage({ type: "playing", value: false, id: this.ack });
        this.ack = 0;
        this.port.postMessage({ type: "silent" });
      }
      return true;
    }
    this.module._ENAudioRender(this.handle, left.length);
    const heap = this.module.HEAPF32;
    for (let i = 0; i < left.length; i++) {
      left[i] = heap[this.left + i];
      right[i] = heap[this.right + i];
    }
    if (this.capture) {
      for (let i = 0; i < left.length; i++) {
        this.batch[this.batchFrames * 2] = left[i];
        this.batch[this.batchFrames * 2 + 1] = right[i];
        this.batchFrames++;
        if (this.batchFrames === 2048) {
          this.port.postMessage({
            type: "samples",
            frame: this.frame + i + 1 - 2048,
            pcm: this.batch,
          });
          this.batchFrames = 0;
        }
      }
    }
    this.frame += left.length;
    if (this.ack) {
      this.port.postMessage({
        type: "playing",
        value: this.playing,
        id: this.ack,
      });
      this.ack = 0;
    }
    if (!this.playing && this.module._ENAudioSilent(this.handle))
      this.port.postMessage({ type: "silent" });
    return true;
  }
}
registerProcessor("evernoise", NoiseProcessor);
