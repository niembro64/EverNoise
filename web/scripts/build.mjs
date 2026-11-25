import { cp, mkdir, rm, readdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import crypto from "node:crypto";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), ".."),
  out = path.join(root, "dist");
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await cp(path.join(root, "src"), out, { recursive: true });
for (const name of ["ribbon.vert", "ribbon.frag"])
  await cp(path.join(root, "../shared/visuals", name), path.join(out, name));
const all = [];
async function walk(dir) {
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) await walk(p);
    else all.push(path.relative(out, p));
  }
}
await walk(out);
for (const required of [
  "wasm/audio.wasm",
  "wasm/spectrum.wasm",
  "icon-192.png",
  "icon-512.png",
])
  if (!all.includes(required))
    throw Error(`Missing ${required}; see root build instructions.`);
const hash = crypto.createHash("sha256");
for (const f of all.sort()) hash.update(await readFile(path.join(out, f)));
const version = hash.digest("hex").slice(0, 16);
await writeFile(
  path.join(out, "sw.js"),
  `const CACHE='evernoise-${version}',FILES=${JSON.stringify(["./", ...all.map((p) => "./" + p)])};\nself.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES))));\nself.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('evernoise-')&&k!==CACHE).map(k=>caches.delete(k))))));\nself.addEventListener('fetch',e=>{if(e.request.method!=='GET'||new URL(e.request.url).origin!==self.location.origin)return;e.respondWith(caches.match(e.request).then(cached=>cached||fetch(e.request)));});\n`,
);
await writeFile(path.join(out, ".nojekyll"), "");
console.log(`Built offline web app ${version} (${all.length} assets)`);
