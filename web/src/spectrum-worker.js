import createSpectrum from "./wasm/spectrum.js";
let module, handle, ready;
self.onmessage = async ({ data }) => {
  if (data.type === "init") {
    ready = createSpectrum({
      locateFile: (p) => new URL("./wasm/" + p, import.meta.url).href,
    }).then((m) => {
      module = m;
      handle = m._ENSpectrumCreate();
      if (!handle) throw Error("Spectrum allocation failed");
    });
    await ready;
    self.postMessage({ type: "ready" });
    return;
  }
  if (data.type === "samples") {
    await ready;
    module.HEAPF32.set(data.pcm, module._ENSpectrumInput(handle) / 4);
    const count = module._ENSpectrumConsume(
      handle,
      data.pcm.length / 2,
      data.frame,
    );
    if (count) {
      const offset = module._ENSpectrumColumns(handle) / 4;
      const columns = module.HEAPF32.slice(offset, offset + count * 1024);
      self.postMessage({ type: "columns", columns }, [columns.buffer]);
    }
    self.postMessage({ type: "consumed" });
  }
};
