#!/bin/bash

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../packages

export NACL_SDK_ROOT="${SCRIPT_DIR}/../"

if ! make clean ; then
  echo "Error cleaning!" 1>&2
  exit 1
fi

exit 0
