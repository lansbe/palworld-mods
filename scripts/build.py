#!/usr/bin/env python3
"""Build the independent native runtime from verified upstream Lua sources."""
import argparse
import concurrent.futures
import hashlib
import pathlib
import subprocess
import tarfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
LUA_VERSION = "5.4.8"
LUA_SHA256 = "4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae"


def run(args):
    subprocess.run(args, check=True)


def lua_sources():
    cache = ROOT / ".cache"
    cache.mkdir(exist_ok=True)
    archive = cache / f"lua-{LUA_VERSION}.tar.gz"
    if not archive.exists():
        with urllib.request.urlopen(f"https://www.lua.org/ftp/{archive.name}", timeout=30) as response:
            data = response.read(2 * 1024 * 1024)
        if hashlib.sha256(data).hexdigest() != LUA_SHA256:
            raise RuntimeError("Lua download checksum mismatch")
        archive.write_bytes(data)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != LUA_SHA256:
        raise RuntimeError("Cached Lua checksum mismatch")
    source = cache / f"lua-{LUA_VERSION}"
    if not source.exists():
        with tarfile.open(archive) as package:
            for member in package.getmembers():
                target = (cache / member.name).resolve()
                if not target.is_relative_to(cache.resolve()) or member.issym() or member.islnk():
                    raise RuntimeError("Unsafe source archive")
            package.extractall(cache, filter="data")
    return source / "src"


def build(development=False):
    build_dir = ROOT / "build"
    objects = build_dir / "lua"
    objects.mkdir(parents=True, exist_ok=True)
    source = lua_sources()

    def compile_one(path):
        target = objects / (path.stem + ".o")
        if not target.exists() or target.stat().st_mtime < path.stat().st_mtime:
            run(["xcrun", "clang", "-arch", "arm64", "-O2", "-DLUA_USE_MACOSX",
                 "-fvisibility=hidden", f"-ffile-prefix-map={ROOT}=.", "-c", str(path), "-o", str(target)])
        return str(target)

    files = sorted(p for p in source.glob("*.c") if p.name not in {"lua.c", "luac.c"})
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        compiled = list(pool.map(compile_one, files))
    chunks = []
    for path in sorted((ROOT / "src/runtime").rglob("*.lua")):
        name = path.relative_to(ROOT / "src/runtime").with_suffix("").as_posix().replace("/", ".")
        content = path.read_text()
        if ')PAL_LUA"' in content:
            raise RuntimeError("Embedded source delimiter conflict")
        chunks.append('{"' + name + '", R"PAL_LUA(' + content + ')PAL_LUA"}')
    if development:
        source_text = (ROOT / 'scripts/development.lua').read_text()
        chunks.append('{"development", R"PAL_LUA(' + source_text + ')PAL_LUA"}')
    (build_dir / "embedded.hpp").write_text(
        '#pragma once\nstruct EmbeddedModule { const char* name; const char* source; };\n'
        'inline const EmbeddedModule embeddedModules[] = {\n' + ',\n'.join(chunks) + '\n};\n')
    output = build_dir / "libPalMods.dylib"
    temporary = build_dir / "libPalMods-new.dylib"
    run(["xcrun", "clang++", "-std=c++20", "-arch", "arm64", "-O2", "-Wall", "-Wextra",
         *(["-DPALMODS_DEVELOPMENT"] if development else []),
         "-Werror", "-fvisibility=hidden", "-dynamiclib", "-Wl,-install_name,@rpath/libPalMods.dylib", "-framework", "CoreFoundation", "-framework", "Foundation", "-fobjc-arc",
         "-I", str(source), "-I", str(build_dir), f"-ffile-prefix-map={ROOT}=.", *map(str, sorted([*(ROOT / "src/native").glob("*.cpp"), *(ROOT / "src/native").glob("*.mm")])),
         *compiled, "-o", str(temporary)])
    run(["codesign", "--force", "--sign", "-", str(temporary)])
    temporary.replace(output)
    print(f"Built {output.name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--development", action="store_true")
    build(parser.parse_args().development)
