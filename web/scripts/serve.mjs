import http from "node:http";
import { readFile, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../dist",
);
const types = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
  ".wasm": "application/wasm",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".webmanifest": "application/manifest+json",
  ".frag": "text/plain",
  ".vert": "text/plain",
};
http
  .createServer(async (req, res) => {
    try {
      const url = new URL(req.url, "http://localhost");
      let rel = decodeURIComponent(url.pathname).replace(/^\/EverNoise\//, "/");
      let p = path.resolve(root, "." + rel);
      if (!p.startsWith(root + path.sep) && p !== root) {
        res.writeHead(403).end();
        return;
      }
      if ((await stat(p)).isDirectory()) p = path.join(p, "index.html");
      const data = await readFile(p);
      res.writeHead(200, {
        "Content-Type": types[path.extname(p)] || "application/octet-stream",
        "Cache-Control": "no-cache",
      });
      res.end(data);
    } catch {
      res.writeHead(404).end("Not found");
    }
  })
  .listen(Number(process.env.PORT || 4173), "127.0.0.1", () =>
    console.log("EverNoise: http://127.0.0.1:4173"),
  );
