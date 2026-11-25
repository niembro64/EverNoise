export class NoiseAudio extends EventTarget {
  constructor(settings) {
    super();
    this.settings = settings;
    this.playing = false;
    this.id = 0;
    this.pending = new Map();
    this.ready = null;
    this.worker = null;
    this.busy = false;
    this.suspendTimer = null;
  }
  emit(type, detail) {
    this.dispatchEvent(new CustomEvent(type, { detail }));
  }
  async initialize() {
    if (this.ready) return this.ready;
    // Construct and resume inside the user's gesture, before network/wasm work.
    this.context = new AudioContext({
      sampleRate: 48000,
      latencyHint: "playback",
    });
    if (this.context.sampleRate !== 48000) {
      this.context.close();
      throw Error(
        "This browser cannot provide the required 48 kHz audio context.",
      );
    }
    this.context.resume();
    this.context.onstatechange = () => {
      if (this.playing && this.context.state !== "running")
        this.emit("interrupted", this.context.state);
    };
    this.ready = (async () => {
      const [wasm] = await Promise.all([
        fetch(new URL("./wasm/audio.wasm", import.meta.url)).then((r) => {
          if (!r.ok)
            throw Error(
              "Audio download failed. Please reconnect and try again.",
            );
          return r.arrayBuffer();
        }),
        this.context.audioWorklet.addModule(
          new URL("./audio-worklet.js", import.meta.url),
        ),
      ]);
      const seed = crypto.getRandomValues(new Uint32Array(1))[0];
      this.node = new AudioWorkletNode(this.context, "evernoise", {
        numberOfInputs: 0,
        numberOfOutputs: 1,
        outputChannelCount: [2],
        processorOptions: { wasm, seed, settings: this.settings },
      });
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(
          () => reject(Error("Audio initialization timed out.")),
          15000,
        );
        this.node.port.onmessage = ({ data }) => {
          if (data.type === "ready") {
            clearTimeout(timeout);
            resolve();
          }
          if (data.type === "error") {
            clearTimeout(timeout);
            reject(Error(data.message));
          }
          this.message(data);
        };
        this.node.onprocessorerror = () => {
          reject(Error("Audio processing stopped. Reload to restart."));
          this.emit("error", "Audio processing stopped. Reload to restart.");
        };
      });
      this.node.connect(this.context.destination);
    })().catch(async (error) => {
      this.ready = null;
      await this.context.close();
      throw error;
    });
    return this.ready;
  }
  message(data) {
    if (data.type === "playing") {
      this.pending.get(data.id)?.();
      this.pending.delete(data.id);
    }
    if (data.type === "silent" && !this.playing) {
      clearTimeout(this.suspendTimer);
      this.suspendTimer = setTimeout(() => {
        if (!this.playing) this.context.suspend();
      }, 300);
    }
    if (data.type === "samples" && this.worker && !this.busy) {
      this.busy = true;
      this.worker.postMessage(data, [data.pcm.buffer]);
    }
  }
  async play(value) {
    clearTimeout(this.suspendTimer);
    if (!value && !this.context) return;
    await this.initialize();
    await this.context.resume();
    this.playing = value;
    const id = ++this.id;
    const ack = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(Error("Audio did not respond. Tap Play to retry."));
      }, 4000);
      this.pending.set(id, () => {
        clearTimeout(timer);
        resolve();
      });
    });
    this.node.port.postMessage({ type: "play", value, id });
    await ack;
  }
  configure(settings) {
    this.settings = settings;
    this.node?.port.postMessage({ type: "settings", value: settings });
  }
  analysis(enabled) {
    this.node?.port.postMessage({ type: "capture", value: enabled });
    if (enabled && !this.worker) {
      this.worker = new Worker(
        new URL("./spectrum-worker.js", import.meta.url),
        { type: "module" },
      );
      this.worker.onmessage = ({ data }) => {
        if (data.type === "columns") this.emit("columns", data.columns);
        if (data.type === "consumed") this.busy = false;
      };
      this.worker.onerror = () => {
        this.analysis(false);
        this.emit("visual-error", "Spectrum unavailable on this browser.");
      };
      this.worker.postMessage({ type: "init" });
    }
    if (!enabled && this.worker) {
      this.worker.terminate();
      this.worker = null;
      this.busy = false;
    }
  }
}
