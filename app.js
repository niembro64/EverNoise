import { load, normalize, DB } from "./state.js";
import { NoiseAudio } from "./audio.js";
import { RibbonScene, SpectrumScene, HUES } from "./visuals.js";
const $ = (id) => document.getElementById(id);
let settings = load(localStorage),
  playing = false,
  busy = false,
  installPrompt,
  wake,
  spectrum;
const audio = new NoiseAudio(settings);
const ribbons = new RibbonScene(
  $("ribbons"),
  document.querySelector(".artwork"),
);
const audible = () => settings.low + settings.mid + settings.high > 0;
ribbons
  .initialize()
  .catch((error) => console.warn("Ribbon rendering unavailable", error));
function save() {
  try {
    localStorage.setItem("evernoise-v1", JSON.stringify(settings));
  } catch {}
  audio.configure(settings);
  render();
}
for (const [name, index] of [
  ["high", 4],
  ["mid", 2],
  ["low", 0],
]) {
  const root = $(name);
  root.className = "band";
  root.style.setProperty(
    "--band",
    `rgb(${HUES[index].map((v) => Math.round(v * 255)).join(" ")})`,
  );
  root.innerHTML = `<h2 id="${name}-title">${name[0].toUpperCase() + name.slice(1)}</h2><div class="options" role="radiogroup" aria-labelledby="${name}-title"></div>`;
  for (let i = 0; i < 6; i++) {
    const b = document.createElement("button");
    b.className = "option";
    b.type = "button";
    b.dataset.level = i;
    b.setAttribute("role", "radio");
    b.setAttribute(
      "aria-label",
      i === 0 ? `${name} off` : `${name} ${i} of 5, ${DB[i]} decibels relative`,
    );
    b.innerHTML = `<span class="dot" style="--dot:${[10, 4, 7, 10, 14, 19][i]}px;--power:${[1, 0.25, 0.42, 0.59, 0.77, 1][i]}" aria-hidden="true"></span>`;
    b.onclick = () => {
      settings = { ...settings, [name]: i };
      save();
    };
    b.onkeydown = (e) => {
      const delta = ["ArrowRight", "ArrowUp"].includes(e.key)
        ? 1
        : ["ArrowLeft", "ArrowDown"].includes(e.key)
          ? -1
          : 0;
      if (delta) {
        e.preventDefault();
        const next = (i + delta + 6) % 6;
        settings = { ...settings, [name]: next };
        save();
        root.querySelectorAll("button")[next].focus();
      }
    };
    root.querySelector(".options").append(b);
  }
}
function segments(id, labels, key, values) {
  for (let i = 0; i < labels.length; i++) {
    const b = document.createElement("button");
    b.textContent = labels[i];
    b.type = "button";
    b.onclick = () => {
      settings = { ...settings, [key]: values ? values[i] : i };
      save();
    };
    $(id).append(b);
  }
}
segments("stereo", ["Mono", "Stereo"], "stereo", [false, true]);
segments("visuals", ["Off", "Low", "Med", "High", "Max"], "visuals");
function render() {
  document.body.classList.toggle("paused", !playing || !audible());
  for (const name of ["high", "mid", "low"])
    $(name)
      .querySelectorAll("button")
      .forEach((b, i) => {
        b.setAttribute("aria-checked", String(settings[name] === i));
        b.tabIndex = settings[name] === i ? 0 : -1;
      });
  $("stereo")
    .querySelectorAll("button")
    .forEach((b, i) =>
      b.setAttribute("aria-pressed", String(settings.stereo === Boolean(i))),
    );
  $("visuals")
    .querySelectorAll("button")
    .forEach((b, i) =>
      b.setAttribute("aria-pressed", String(settings.visuals === i)),
    );
  $("loudness").value = settings.offset;
  $("loudness-value").textContent =
    `${settings.offset > 0 ? "+" : ""}${settings.offset} dB`;
  $("awake").checked = settings.awake;
  $("play").setAttribute(
    "aria-label",
    playing ? "Pause EverNoise" : "Start EverNoise",
  );
  $("play-glyph").setAttribute(
    "d",
    playing ? "M10 7H14V25H10Z M20 7H24V25H20Z" : "M11 7 L26 16 L11 25 Z",
  );
  ribbons.configure(settings, playing);
  const max = settings.visuals === 4;
  $("spectrum").hidden = !max;
  $("frequency-labels").hidden = !max;
  $("spectrum").style.filter = playing ? "none" : "grayscale(1)";
  if (max && !spectrum) spectrum = new SpectrumScene($("spectrum"));
  $("warming").hidden = !max || !playing || spectrum?.count > 0;
  audio.analysis(max && playing && !document.hidden);
  if (navigator.mediaSession)
    navigator.mediaSession.playbackState = playing ? "playing" : "paused";
  updateWake();
}
async function setPlaying(value) {
  if (busy) return;
  busy = true;
  $("play").disabled = true;
  $("status").textContent = value ? "Starting your sound…" : "Pausing…";
  try {
    await audio.play(value);
    playing = value;
    $("status").textContent = playing
      ? audible()
        ? "Playing continuously"
        : "All bands off"
      : "Paused";
  } catch (error) {
    playing = false;
    $("status").textContent = error.message;
  } finally {
    busy = false;
    $("play").disabled = false;
    render();
  }
}
$("play").onclick = () => setPlaying(!playing);
$("settings").onclick = () => $("preferences").showModal();
$("loudness").oninput = (e) => {
  settings = { ...settings, offset: Number(e.target.value) };
  save();
};
$("awake").onchange = (e) => {
  settings = { ...settings, awake: e.target.checked };
  save();
};
audio.addEventListener("columns", (e) => {
  spectrum?.add(e.detail);
  $("warming").hidden = true;
});
audio.addEventListener("interrupted", () => {
  $("status").textContent =
    "Audio interrupted by the browser. Tap Play to resume.";
  playing = false;
  render();
});
audio.addEventListener("error", (e) => {
  $("status").textContent = e.detail;
  playing = false;
  render();
});
async function updateWake() {
  if (!settings.awake || !playing || document.hidden) {
    await wake?.release();
    wake = null;
    return;
  }
  if (!wake && navigator.wakeLock)
    try {
      wake = await navigator.wakeLock.request("screen");
      wake.addEventListener("release", () => (wake = null));
    } catch {}
}
document.addEventListener("visibilitychange", () => {
  render();
  if (!document.hidden) ribbons.request();
});
if (navigator.mediaSession) {
  navigator.mediaSession.metadata = new MediaMetadata({
    title: "EverNoise",
    artist: "Your sound. All night.",
    artwork: [
      {
        src: new URL("./icon-512.png", location.href).href,
        sizes: "512x512",
        type: "image/png",
      },
    ],
  });
  for (const [name, fn] of [
    ["play", () => setPlaying(true)],
    ["pause", () => setPlaying(false)],
    ["stop", () => setPlaying(false)],
  ])
    navigator.mediaSession.setActionHandler(name, fn);
}
window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault();
  installPrompt = e;
  $("install").hidden = false;
});
$("install").onclick = async () => {
  await installPrompt?.prompt();
  installPrompt = null;
  $("install").hidden = true;
};
if (
  "serviceWorker" in navigator &&
  !["localhost", "127.0.0.1"].includes(location.hostname)
)
  navigator.serviceWorker
    .register(new URL("./sw.js", import.meta.url))
    .catch(() => {});
render();

$("frequency-labels")
  .querySelectorAll("span")
  .forEach(
    (label, i) =>
      (label.style.top = `${100 * (1 - Math.log([48000, 2000, 200, 20, 2][i] / 2) / Math.log(24000))}%`),
  );
