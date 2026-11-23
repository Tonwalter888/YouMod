#!/usr/bin/env python3
"""Mach-O arm64 (thin) tools for the YouMod IPA workflow.

  margin  <exe>                              -> prints the header room, exits with code 1 if negative
  compact <orig_exe> <cyan_exe> <Frameworks> <loader.dylib> <output_list>
          -> replaces the injected LC_LOAD_DYLIBs with a single loader
  check   <orig_exe> <stage_ipa> <out_ipa>
          -> full "Check Mach-O header room" step: unpacks the IPA, compacts the
             injected dylibs into TweakLoader.dylib when they overflow into the
             code, and repacks the IPA
"""
import os
import shutil
import struct
import subprocess
import sys

HDR = 32
LC_SEGMENT_64 = 0x19
LC_LOAD_DYLIB = 0xC
LC_LOAD_WEAK_DYLIB = 0x80000018
DYLIB_CMDS = (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB)

WORK = '.ci'

TWEAKLOADER_C = r'''
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include "tweaks.h"

__attribute__((constructor))
static void tweakloader_init(void) {
    Dl_info info;
    if (!dladdr((const void *)&tweakloader_init, &info) || !info.dli_fname) return;
    char dir[1024];
    strlcpy(dir, info.dli_fname, sizeof dir);
    char *slash = strrchr(dir, '/');
    if (!slash) return;
    *slash = 0;
    for (int i = 0; kTweaks[i]; i++) {
        char path[1400];
        snprintf(path, sizeof path, "%s/%s", dir, kTweaks[i]);
        if (!dlopen(path, RTLD_NOW | RTLD_GLOBAL))
            fprintf(stderr, "[TweakLoader] %s: %s\n", kTweaks[i], dlerror());
    }
}
'''


def parse(data):
    magic, _, _, _, ncmds, sizeofcmds, _, _ = struct.unpack_from('<IiiIIIII', data, 0)
    if magic != 0xFEEDFACF:
        sys.exit("Thin 64-bit Mach-O expected (FAT or 32-bit is not supported)")
    cmds, off = [], HDR
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, off)
        cmds.append(bytes(data[off:off + size]))
        off += size
    return sizeofcmds, cmds


def first_content(cmds):
    first = None
    for c in cmds:
        if struct.unpack_from('<I', c, 0)[0] == LC_SEGMENT_64:
            for i in range(struct.unpack_from('<I', c, 64)[0]):
                o = struct.unpack_from('<I', c, 72 + i * 80 + 48)[0]
                if o:
                    first = o if first is None else min(first, o)
    return first


def dylib_name(c):
    off = struct.unpack_from('<I', c, 8)[0]
    return c[off:].split(b'\0', 1)[0].decode()


def build_load(name):
    raw = name.encode() + b'\0'
    size = (24 + len(raw) + 7) & ~7
    return struct.pack('<IIIIII', LC_LOAD_DYLIB, size, 24, 2, 0x10000, 0x10000) + raw.ljust(size - 24, b'\0')


def report(path):
    sizeofcmds, cmds = parse(open(path, 'rb').read())
    first, end = first_content(cmds), HDR + sizeofcmds
    nlibs = sum(1 for c in cmds if struct.unpack_from('<I', c, 0)[0] in DYLIB_CMDS)
    print(f"  {os.path.basename(path)}: load commands up to {end:#x}, "
          f"first content at {first:#x}, room {first - end} bytes, {nlibs} linked dylibs")
    return first - end


def compact(orig_path, new_path, frameworks, loader, list_out):
    orig = open(orig_path, 'rb').read()
    new = bytearray(open(new_path, 'rb').read())
    _, orig_cmds = parse(orig)
    sizeofcmds, new_cmds = parse(new)
    first, old_end = first_content(new_cmds), HDR + sizeofcmds

    pool, kept, removed = list(orig_cmds), [], []
    for c in new_cmds:
        if c in pool:                       # original command: keep it
            pool.remove(c)
            kept.append(c)
            continue
        if struct.unpack_from('<I', c, 0)[0] in DYLIB_CMDS:
            base = os.path.basename(dylib_name(c))
            if base.endswith('.dylib') and os.path.isfile(os.path.join(frameworks, base)):
                removed.append(base)        # injected tweak dylib: drop it
                continue
        kept.append(c)

    if not removed:
        sys.exit("No injected dylib to compact")
    loader_cmd = build_load('@rpath/' + loader)
    if kept and struct.unpack_from('<I', kept[-1], 0)[0] == 0x1D:   # LC_CODE_SIGNATURE must stay last
        kept.insert(len(kept) - 1, loader_cmd)
    else:
        kept.append(loader_cmd)
    body = b''.join(kept)
    if HDR + len(body) > first:
        sys.exit("Even compacted, the load commands list exceeds the header")

    if old_end > first:                     # restore the code overwritten by the overflow
        new[first:old_end] = orig[first:old_end]
    new[HDR:first] = body + bytes(first - HDR - len(body))
    struct.pack_into('<II', new, 16, len(kept), len(body))
    open(new_path, 'wb').write(new)
    open(list_out, 'w').write('\n'.join(removed) + '\n')
    print(f"  {len(removed)} dylibs removed from the load commands, 1 loader added")


def write_tweaks_header(list_path, header_path):
    names = [line for line in open(list_path).read().splitlines() if line]
    with open(header_path, 'w') as out:
        out.write('static const char *const kTweaks[] = {\n')
        for name in names:
            out.write(f'  "{name}",\n')
        out.write('  0 };\n')


def check(orig_path, stage_ipa, out_ipa):
    os.makedirs(WORK, exist_ok=True)
    shutil.rmtree('staged', ignore_errors=True)
    subprocess.run(['unzip', '-q', stage_ipa, '-d', 'staged'], check=True)
    app = os.path.join('staged', 'Payload', 'YouTube.app')
    exe = os.path.join(app, 'YouTube')

    print("Mach-O header room (before, then after injection):")
    if report(orig_path) < 0:
        sys.exit(1)
    if report(exe) >= 0:
        print("Enough room: no compaction needed.")
    else:
        print("::warning::The load commands overflow into the code: compacting the injected dylibs.")
        removed_txt = os.path.join(WORK, 'removed.txt')
        compact(orig_path, exe, os.path.join(app, 'Frameworks'), 'TweakLoader.dylib', removed_txt)
        write_tweaks_header(removed_txt, os.path.join(WORK, 'tweaks.h'))
        csrc = os.path.join(WORK, 'TweakLoader.c')
        open(csrc, 'w').write(TWEAKLOADER_C)
        subprocess.run(['xcrun', '--sdk', 'iphoneos', 'clang', '-arch', 'arm64', '-dynamiclib', '-O2',
                        '-miphoneos-version-min=14.0', '-install_name', '@rpath/TweakLoader.dylib',
                        '-I' + WORK, '-o', os.path.join(app, 'Frameworks', 'TweakLoader.dylib'), csrc],
                       check=True)
        if report(exe) < 0:
            sys.exit(1)
    subprocess.run(['zip', '-qry', os.path.abspath(out_ipa), '.'], cwd='staged', check=True)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == 'margin':
        sys.exit(0 if report(sys.argv[2]) >= 0 else 1)
    if len(sys.argv) == 7 and sys.argv[1] == 'compact':
        compact(*sys.argv[2:])
        sys.exit(0)
    if len(sys.argv) == 5 and sys.argv[1] == 'check':
        check(*sys.argv[2:])
        sys.exit(0)
    sys.exit(__doc__)
