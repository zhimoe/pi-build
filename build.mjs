// Build one portable Windows x64 directory: dist/pi-offline
// Layout: app/ (Pi), tools/ (rg, fd), extensions/ (offline extension installer and packages)
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
    copyFileSync,
    existsSync,
    mkdirSync,
    readFileSync,
    readdirSync,
    renameSync,
    rmSync,
    writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const distDir = join(root, "dist");
const bundleName = "pi-offline";
const staging = join(distDir, `.${bundleName}-staging`);
const downloadsDir = join(root, "downloads");

const PI_VERSION = process.env.PI_VERSION ?? "1.5.2";
const EXTENSIONS = {
    "context-mode": "2.1.7",
    "pi-web-access": "0.47.0",
    "pi-smart-fetch": "0.3.23",
};
const TOOLS = {
    rg: {
        version: "15.2.0",
        url: "https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-pc-windows-msvc.zip",
        sha256: "71b2fef860abe467217a538ff31de02f5258807c0129f771846f87bd029aafc5",
        archive: "ripgrep-15.2.0-x86_64-pc-windows-msvc.zip",
        exe: "rg.exe",
    },
    fd: {
        version: "10.5.2",
        url: "https://github.com/sharkdp/fd/releases/download/v10.5.2/fd-v10.5.2-x86_64-pc-windows-msvc.zip",
        sha256: "7edac75ef96b7e9a01ebb251a21ee86ea365a09adcfb865f1ec3346a906153b6",
        archive: "fd-v10.5.2-x86_64-pc-windows-msvc.zip",
        exe: "fd.exe",
    },
};

function run(command, args, options = {}) {
    execFileSync(command, args, { stdio: "inherit", ...options });
}

function sha256File(path) {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
}

async function verifiedDownload(url, expectedSha256, archive) {
    mkdirSync(downloadsDir, { recursive: true });
    const target = join(downloadsDir, archive);
    if (existsSync(target) && sha256File(target) === expectedSha256) {
        console.log(`Using cached ${archive}`);
        return target;
    }
    console.log(`Downloading ${url}`);
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Download failed: ${response.status} ${response.statusText}`);
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    const actual = createHash("sha256").update(bytes).digest("hex");
    if (actual !== expectedSha256) {
        throw new Error(`Checksum mismatch for ${archive}: ${actual}`);
    }
    writeFileSync(target, bytes);
    return target;
}

function removeBinDirectories(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const path = join(dir, entry.name);
        if (entry.name === ".bin") {
            rmSync(path, { recursive: true, force: true });
        } else {
            removeBinDirectories(path);
        }
    }
}

function findFile(dir, name) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const path = join(dir, entry.name);
        if (entry.isFile() && entry.name.toLowerCase() === name.toLowerCase()) {
            return path;
        }
        if (entry.isDirectory()) {
            const found = findFile(path, name);
            if (found) return found;
        }
    }
    return undefined;
}

function installPi(appDir) {
    mkdirSync(appDir, { recursive: true });
    writeFileSync(
        join(appDir, "package.json"),
        `${JSON.stringify({
            name: "pi-offline-runtime",
            version: "1.0.0",
            private: true,
            dependencies: { "@earendil-works/pi-coding-agent": PI_VERSION },
        }, null, 2)}\n`,
    );
    console.log(`Installing @earendil-works/pi-coding-agent@${PI_VERSION}`);
    run("npm", [
        "install",
        "--ignore-scripts",
        "--omit=dev",
        "--no-audit",
        "--no-fund",
    ], { cwd: appDir, shell: process.platform === "win32" });
    removeBinDirectories(join(appDir, "node_modules"));
}

async function installTools(toolsDir) {
    mkdirSync(toolsDir, { recursive: true });
    for (const [key, tool] of Object.entries(TOOLS)) {
        await verifiedDownload(tool.url, tool.sha256, tool.archive);
        const temp = join(toolsDir, `_${key}_tmp`);
        rmSync(temp, { recursive: true, force: true });
        mkdirSync(temp, { recursive: true });
        run("7z", ["x", join(downloadsDir, tool.archive), `-o${temp}`, "-y"], { cwd: root });
        const exe = findFile(temp, tool.exe);
        if (!exe) throw new Error(`${tool.exe} not found in ${tool.archive}`);
        const target = join(toolsDir, key);
        rmSync(target, { recursive: true, force: true });
        renameSync(dirname(exe), target);
        rmSync(temp, { recursive: true, force: true });
        console.log(`Bundled ${tool.exe} ${tool.version}`);
    }
}

function installExtensions(extensionsDir) {
    const npmDir = join(extensionsDir, "npm");
    mkdirSync(npmDir, { recursive: true });
    writeFileSync(
        join(npmDir, "package.json"),
        `${JSON.stringify({ name: "pi-extensions", private: true }, null, 2)}\n`,
    );
    const specs = Object.entries(EXTENSIONS).map(([name, version]) => `${name}@${version}`);
    console.log(`Installing ${specs.join(", ")}`);
    run("npm", [
        "install",
        ...specs,
        "--save-exact",
        "--ignore-scripts",
        "--legacy-peer-deps",
        "--no-audit",
        "--no-fund",
    ], { cwd: npmDir, shell: process.platform === "win32" });

    // wreq-js ships native binaries for every platform. Keep only the Windows x64 one.
    const rustDir = join(npmDir, "node_modules", "wreq-js", "rust");
    if (existsSync(rustDir)) {
        for (const name of readdirSync(rustDir)) {
            if (name.endsWith(".node") && name !== "wreq-js.win32-x64-msvc.node") {
                rmSync(join(rustDir, name));
            }
        }
    }
    // npm bin shims are symlinks on Unix and not needed by Pi's extension loader.
    removeBinDirectories(join(npmDir, "node_modules"));

    copyFileSync(join(root, "extensions", "install.ps1"), join(extensionsDir, "install.ps1"));
    copyFileSync(join(root, "extensions", "README.md"), join(extensionsDir, "README.md"));
    writeFileSync(
        join(extensionsDir, "settings.example.json"),
        `${JSON.stringify({ packages: specs.map((spec) => `npm:${spec}`) }, null, 2)}\n`,
    );
}

function writeLauncher(bundleDir) {
    const launcher = [
        "@echo off",
        "setlocal",
        "set \"PATH=%~dp0tools\\rg;%~dp0tools\\fd;%PATH%\"",
        "set \"PI_OFFLINE=1\"",
        "node.exe \"%~dp0app\\node_modules\\@earendil-works\\pi-coding-agent\\dist\\bundle\\cli.js\" %*",
        "exit /b %errorlevel%",
        "",
    ].join("\r\n");
    writeFileSync(join(bundleDir, "pi.cmd"), launcher, "ascii");
}

async function main() {
    rmSync(distDir, { recursive: true, force: true });
    mkdirSync(staging, { recursive: true });
    try {
        installPi(join(staging, "app"));
        await installTools(join(staging, "tools"));
        installExtensions(join(staging, "extensions"));
        writeLauncher(staging);
        copyFileSync(join(root, "lite", "README.md"), join(staging, "README.md"));
        copyFileSync(join(root, "models.example.json"), join(staging, "models.example.json"));

        const bundleDir = join(distDir, bundleName);
        renameSync(staging, bundleDir);
        console.log(`\nCreated ${bundleDir}`);
        console.log(`  app: Pi ${PI_VERSION}`);
        console.log(`  tools: rg ${TOOLS.rg.version}, fd ${TOOLS.fd.version}`);
        console.log(`  extensions: ${Object.keys(EXTENSIONS).join(", ")}`);
    } catch (error) {
        rmSync(staging, { recursive: true, force: true });
        throw error;
    }
}

await main();
