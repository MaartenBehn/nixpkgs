import http from "node:http";
import { createReadStream, existsSync, statSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { server as wisp } from "@mercuryworkshop/wisp-js/server";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const DEMO_PORT = Number(process.env.DEMO_PORT || 4141);
const WISP_PORT = Number(process.env.WISP_PORT || 4142);
const DEMO_HOST = process.env.DEMO_HOST || "127.0.0.1";
const WISP_HOST = process.env.WISP_HOST || "127.0.0.1";
const WISP_URL = process.env.WISP_URL || `ws://localhost:${WISP_PORT}/`;

// dist output produced at BUILD time (see Nix changes below)
const DEMO_DIST = path.join(__dirname, "packages/demo/dist");

if (!existsSync(DEMO_DIST)) {
	console.error(
		`Demo dist directory not found at ${DEMO_DIST}. This package must be built with the demo's production build output included.`
	);
	process.exit(1);
}

wisp.options.allow_private_ips = true;
wisp.options.allow_loopback_ips = true;

const wispserver = http.createServer((_req, res) => {
	res.writeHead(200, { "Content-Type": "text/plain" });
	res.end("wisp server js rewrite");
});
wispserver.on("upgrade", (req, socket, head) => {
	wisp.routeRequest(req, socket, head);
});
wispserver.listen(WISP_PORT, WISP_HOST);

const MIME_TYPES: Record<string, string> = {
	".html": "text/html; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".mjs": "text/javascript; charset=utf-8",
	".css": "text/css; charset=utf-8",
	".json": "application/json; charset=utf-8",
	".wasm": "application/wasm",
	".svg": "image/svg+xml",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".ico": "image/x-icon",
	".woff": "font/woff",
	".woff2": "font/woff2",
	".map": "application/json; charset=utf-8",
};

function safeJoin(root: string, urlPath: string): string | null {
	const decoded = decodeURIComponent(urlPath.split("?")[0]);
	const resolved = path.normalize(path.join(root, decoded));
	if (!resolved.startsWith(path.normalize(root))) return null; // block path traversal
	return resolved;
}

function serveConfigJs(res: http.ServerResponse) {
	res.writeHead(200, { "Content-Type": "text/javascript; charset=utf-8" });
	res.end(`window.__WISP_URL__ = ${JSON.stringify(WISP_URL)};`);
}

const demoServer = http.createServer((req, res) => {
	const reqPath = req.url || "/";

	if (reqPath === "/__config.js") {
		serveConfigJs(res);
		return;
	}

	let filePath = safeJoin(DEMO_DIST, reqPath === "/" ? "/index.html" : reqPath);

	if (!filePath) {
		res.writeHead(400);
		res.end("Bad request");
		return;
	}

	if (!existsSync(filePath) || statSync(filePath).isDirectory()) {
		filePath = path.join(DEMO_DIST, "index.html");
	}

	if (!existsSync(filePath)) {
		res.writeHead(404);
		res.end("Not found");
		return;
	}

	const ext = path.extname(filePath).toLowerCase();

	if (path.basename(filePath) === "index.html") {
		let html = readFileSync(filePath, "utf-8");
		html = html.replace(
			"</head>",
			`<script src="/__config.js"></script></head>`
		);
		res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
		res.end(html);
		return;
	}

	const contentType = MIME_TYPES[ext] || "application/octet-stream";
	res.writeHead(200, { "Content-Type": contentType });
	createReadStream(filePath).pipe(res);
});

demoServer.listen(DEMO_PORT, DEMO_HOST, () => {
	console.log(`scramjet demo  -> http://${DEMO_HOST}:${DEMO_PORT}/`);
	console.log(`wisp server    -> ws://${WISP_HOST}:${WISP_PORT}/`);
});
