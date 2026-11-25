#!/usr/bin/python3
import os
import sys

args = sys.argv[1:]
split = args.index('--')
kernel = args[split + 1]
base = os.path.basename(kernel)
if base in ('leanchecker-paranoid', 'leanchecker'):
    if '--clearenv' not in args[:split] or '--unshare-all' not in args[:split]:
        raise SystemExit('Expected the standard Comparator isolation arguments')
    if args[split + 2:split + 4] != ['--silent', '--from-export']:
        raise SystemExit('Expected the standard Lean export replay')
    args[split:split] = ['--setenv', 'MIMALLOC_GENERIC_COLLECT', '1000000']
os.execv('/usr/bin/bwrap', ['bwrap', *args])
