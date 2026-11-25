#!/usr/bin/env python3
"""Use the stock Lean file reader for small imports on x86-64 Linux."""

import ctypes
import errno
import os
import platform
import sys


class Comparison(ctypes.Structure):
    _fields_ = [
        ("argument", ctypes.c_uint), ("operator", ctypes.c_int),
        ("value", ctypes.c_uint64), ("second_value", ctypes.c_uint64),
    ]


def apply_filter(max_bytes):
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise RuntimeError("this mmap filter was verified on x86-64 Linux")
    if not 1 <= max_bytes <= 2**63 - 1:
        raise ValueError("maximum import size must be a positive byte count")

    lib = ctypes.CDLL("libseccomp.so.2")
    lib.seccomp_init.argtypes = [ctypes.c_uint32]
    lib.seccomp_init.restype = ctypes.c_void_p
    lib.seccomp_syscall_resolve_name.argtypes = [ctypes.c_char_p]
    lib.seccomp_rule_add_array.argtypes = [
        ctypes.c_void_p, ctypes.c_uint32, ctypes.c_int, ctypes.c_uint,
        ctypes.POINTER(Comparison),
    ]
    lib.seccomp_load.argtypes = [ctypes.c_void_p]
    lib.seccomp_release.argtypes = [ctypes.c_void_p]
    lib.seccomp_release.restype = None

    # Match Lean's mmap request: MAP_PRIVATE | MAP_FIXED_NOREPLACE, offset 0.
    # EEXIST selects the released loader's ordinary read-and-relocate path.
    equal, less_or_equal = 4, 3
    conditions = (Comparison * 3)(
        Comparison(3, equal, 0x100002, 0),
        Comparison(5, equal, 0, 0),
        Comparison(1, less_or_equal, max_bytes, 0),
    )
    allow, return_errno = 0x7FFF0000, 0x00050000
    context = lib.seccomp_init(allow)
    if not context:
        raise RuntimeError("seccomp_init failed")
    try:
        syscall = lib.seccomp_syscall_resolve_name(b"mmap")
        if syscall < 0:
            raise RuntimeError("mmap syscall unavailable")
        rc = lib.seccomp_rule_add_array(
            context, return_errno | errno.EEXIST, syscall, len(conditions), conditions,
        )
        if rc < 0:
            raise OSError(-rc, os.strerror(-rc))
        rc = lib.seccomp_load(context)
        if rc < 0:
            raise OSError(-rc, os.strerror(-rc))
    finally:
        lib.seccomp_release(context)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("usage: read_small_imports.py MAX_BYTES PROGRAM [ARG ...]")
    apply_filter(int(sys.argv[1]))
    os.execvp(sys.argv[2], sys.argv[2:])
