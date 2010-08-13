#!/bin/bash

SDK_VERSION=latest

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
cd ${SCRIPT_DIR}/..
${SCRIPT_DIR}/download_sdk.py --version ${SDK_VERSION}
