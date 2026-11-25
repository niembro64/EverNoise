export const DB = [null, -30, -18, -12, -6, 0];
export const DEFAULTS = Object.freeze({
  low: 3,
  mid: 3,
  high: 2,
  stereo: true,
  offset: 0,
  visuals: 2,
  awake: false,
});
const integer = (n, f, min, max) =>
  Number.isFinite(n) ? Math.max(min, Math.min(max, Math.round(n))) : f;
export function normalize(value = {}) {
  if (!value || typeof value !== "object") value = {};
  return {
    low: integer(value.low, 3, 0, 5),
    mid: integer(value.mid, 3, 0, 5),
    high: integer(value.high, 2, 0, 5),
    stereo: typeof value.stereo === "boolean" ? value.stereo : true,
    offset: integer(value.offset, 0, -18, 3),
    visuals: integer(value.visuals, 2, 0, 4),
    awake: value.awake === true,
  };
}
export function load(storage) {
  try {
    return normalize(JSON.parse(storage.getItem("evernoise-v1")));
  } catch {
    return { ...DEFAULTS };
  }
}
export function power(level) {
  return level === 0 ? 0 : 10 ** (DB[level] / 10);
}
export function decode(v) {
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
}
export function encode(v) {
  return v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055;
}
