import { decode, encode, power } from "./state.js";
export const HUES = [
  [0.679977, 0.422528, 0.40132],
  [0.580084, 0.493912, 0.253602],
  [0.373181, 0.556164, 0.377719],
  [0.202675, 0.562493, 0.581097],
  [0.404896, 0.499108, 0.704015],
  [0.604564, 0.432928, 0.613018],
];
const LINEAR = HUES.map((c) => c.map(decode));
export class RibbonScene {
  constructor(canvas, art) {
    this.canvas = canvas;
    this.art = art;
    this.phase = 0;
    this.active = 0;
    this.target = 0;
    this.raf = 0;
    this.previous = 0;
    this.p = [0, 0, 0];
    this.mix = [0, 0, 0];
    this.level = 2;
    this.reduced = matchMedia("(prefers-reduced-motion: reduce)");
    this.reduced.addEventListener("change", () => this.request());
    this.resizeObserver = new ResizeObserver(() => this.request());
    this.resizeObserver.observe(document.body);
  }
  async initialize() {
    const gl = this.canvas.getContext("webgl2", {
      alpha: false,
      antialias: false,
      powerPreference: "low-power",
    });
    if (!gl) return;
    this.gl = gl;
    const [vert, frag] = await Promise.all(
      ["ribbon.vert", "ribbon.frag"].map((p) =>
        fetch(new URL("./" + p, import.meta.url)).then((r) => r.text()),
      ),
    );
    const compile = (type, source) => {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS))
        throw Error(gl.getShaderInfoLog(shader));
      return shader;
    };
    this.program = gl.createProgram();
    gl.attachShader(this.program, compile(gl.VERTEX_SHADER, vert));
    gl.attachShader(this.program, compile(gl.FRAGMENT_SHADER, frag));
    gl.linkProgram(this.program);
    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS))
      throw Error(gl.getProgramInfoLog(this.program));
    gl.useProgram(this.program);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
      gl.STATIC_DRAW,
    );
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    this.uniforms = Object.fromEntries(
      [
        "canvas",
        "infinityRect",
        "phase",
        "activity",
        "ambience",
        "chosen",
        "power",
        "hues",
      ].map((n) => [n, gl.getUniformLocation(this.program, n)]),
    );
    gl.uniform3fv(this.uniforms.hues, LINEAR.flat());
    this.request();
  }
  configure(settings, playing) {
    this.settings = settings;
    this.target =
      playing && settings.low + settings.mid + settings.high > 0 ? 1 : 0;
    this.level = settings.visuals;
    this.request();
  }
  request() {
    if (!this.raf && !document.hidden)
      this.raf = requestAnimationFrame((t) => this.draw(t));
  }
  draw(time) {
    this.raf = 0;
    if (document.hidden) return;
    const dt = Math.min(0.1, (time - (this.previous || time)) / 1000);
    this.previous = time;
    const ease = 1 - Math.exp(-dt / 1.15);
    this.active += (this.target - this.active) * ease;
    const values = ["low", "mid", "high"].map((k) =>
      power(this.settings?.[k] ?? 0),
    );
    for (let i = 0; i < 3; i++) this.p[i] += (values[i] - this.p[i]) * ease;
    if (this.level >= 2 && !this.reduced.matches)
      this.phase =
        (this.phase + (dt * this.active * Math.PI) / 120) % (2 * Math.PI);
    const gl = this.gl;
    if (!gl || !this.uniforms) return;
    const ratio = Math.min(1.5, devicePixelRatio || 1);
    const width = Math.round(innerWidth * ratio),
      height = Math.round(innerHeight * ratio);
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
      gl.viewport(0, 0, width, height);
    }
    gl.useProgram(this.program);
    if (this.level === 0 || this.level === 4) {
      gl.clearColor(0, 0, 0, 1);
      gl.clear(gl.COLOR_BUFFER_BIT);
    } else {
      const box = this.art.getBoundingClientRect();
      const u = this.uniforms;
      gl.uniform2f(u.canvas, width, height);
      gl.uniform4f(
        u.infinityRect,
        box.x * ratio,
        box.y * ratio,
        box.width * ratio,
        box.height * ratio,
      );
      gl.uniform1f(u.phase, this.phase);
      gl.uniform1f(u.activity, this.active);
      gl.uniform1f(u.ambience, this.level === 3 ? 1 : 0);
      gl.uniform3fv(u.power, this.p);
      gl.uniform3fv(
        u.chosen,
        [0, 1, 2].map(
          (ch) =>
            LINEAR[0][ch] * this.p[0] +
            LINEAR[2][ch] * this.p[1] +
            LINEAR[4][ch] * this.p[2],
        ),
      );
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
    if (
      this.level > 0 &&
      this.level < 4 &&
      ((this.level >= 2 && this.target && !this.reduced.matches) ||
        Math.abs(this.target - this.active) > 0.001 ||
        this.p.some((x, i) => Math.abs(x - values[i]) > 0.001))
    )
      this.request();
  }
}

export function spectrumColor(row, db) {
  if (!Number.isFinite(db)) return [0, 0, 0];
  const hz = 2 * 24000 ** (row / 1023);
  const t = (f) =>
    Math.tan((Math.PI * Math.min(hz, 23999.99)) / 48000) /
    Math.tan((Math.PI * f) / 48000);
  const low = 1 / (1 + t(200) ** 4),
    middle = (1 - low) / (1 + t(2000) ** 4),
    high = 1 - low - middle;
  const color = [0, 1, 2].map(
    (ch) => LINEAR[0][ch] * low + LINEAR[2][ch] * middle + LINEAR[4][ch] * high,
  );
  const lum = color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722;
  const intensity = Math.max(0, 2 ** ((db + 35) / 10) - 2 ** -6.5);
  const lightness = 70 * (1 - 1 / (1 + intensity));
  const y =
    lightness <= 8 ? lightness / (24389 / 27) : ((lightness + 16) / 116) ** 3;
  return color.map((c) =>
    Math.round(255 * Math.max(0, Math.min(1, encode((c / lum) * y)))),
  );
}
export class SpectrumScene {
  constructor(canvas) {
    this.canvas = canvas;
    canvas.width = 1320;
    canvas.height = 1024;
    this.context = canvas.getContext("2d", { alpha: false });
    this.column = this.context.createImageData(1, 1024);
    this.count = 0;
    this.palette = new Uint8Array(1024 * 401 * 3);
    for (let row = 0; row < 1024; row++)
      for (let i = 0; i <= 400; i++)
        this.palette.set(
          spectrumColor(row, -110 + i * 0.25),
          (row * 401 + i) * 3,
        );
  }
  add(columns) {
    const count = columns.length / 1024;
    this.context.drawImage(this.canvas, -count, 0);
    for (let n = 0; n < count; n++) {
      for (let row = 0; row < 1024; row++) {
        const db = columns[n * 1024 + row];
        const at =
          (row * 401 + Math.max(0, Math.min(400, Math.round((db + 110) * 4)))) *
          3;
        const i = (1023 - row) * 4;
        for (let ch = 0; ch < 3; ch++)
          this.column.data[i + ch] = Number.isFinite(db)
            ? this.palette[at + ch]
            : 0;
        this.column.data[i + 3] = 255;
      }
      this.context.putImageData(this.column, 1320 - count + n, 0);
    }
    this.count += count;
  }
}
