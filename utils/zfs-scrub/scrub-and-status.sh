#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Exactly one argument must be passed, the name of the zpool to scrub"
    exit 1
fi

# TODO
# add binary version check here!!

set -x

zpool scrub -w "$1"
zpool status "$1"
