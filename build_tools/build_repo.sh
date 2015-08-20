# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -o errexit
set -o nounset

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
NACLPORTS_ROOT="$(cd ${SCRIPT_DIR}/.. && pwd)"

PKG_HOST_DIR=${NACLPORTS_ROOT}/out/pkg_host/
PKG_FILENAME=pkg-1.5.6
PKG_URL=http://storage.googleapis.com/naclports/mirror/${PKG_FILENAME}.tar.gz
SDK_VERSION=pepper_46

#
# Attempt to download a file from a given URL
# $1 - URL to fetch
# $2 - Filename to write to.
#
Fetch() {
  local URL=$1
  local FILENAME=$2
  # Send curl's status messages to stdout rather then stderr
  CURL_ARGS="--fail --location --stderr -"
  if [ -t 1 ]; then
      # Add --progress-bar but only if stdout is a TTY device.
      CURL_ARGS+=" --progress-bar"
  else
      # otherwise suppress all status output, since curl always
      # assumes a TTY and writes \r and \b characters.
      CURL_ARGS+=" --silent"
  fi
  if which curl > /dev/null ; then
      curl ${CURL_ARGS} -o "${FILENAME}" "${URL}"
  else
      echo "error: could not find 'curl' in your PATH"
      exit 1
  fi
}

BuildPkg() {
  if [ -d ${PKG_HOST_DIR} ]; then
      return
  fi
  mkdir -p ${PKG_HOST_DIR}
  Fetch ${PKG_URL} ${PKG_HOST_DIR}/${PKG_FILENAME}
  cd "${PKG_HOST_DIR}"
  tar -xvf ${PKG_FILENAME}
  cd ${PKG_FILENAME}
  ./autogen.sh
  ./configure --with-ldns
  make
}

WriteMetaFile() {
  echo "version = 1;" > $1
  echo "packing_format = "tbz";" >> $1
  echo "digest_format = "sha256_base32";" >> $1
  echo "digests = "digests";" >> $1
  echo "manifests = "packagesite.yaml";" >> $1
  echo "filesite = "filesite.yaml";" >> $1
  echo "digests_archive = "digests";" >> $1
  echo "manifests_archive = "packagesite";" >> $1
  echo "filesite_archive = "filesite";" >> $1
}

BuildRepo() {
  cd ${SCRIPT_DIR}
  ./download_pkg.py $1
  local REPO_DIR=${NACLPORTS_ROOT}/out/packages/prebuilt/repo
  for pkg_dir in ${NACLPORTS_ROOT}/out/packages/prebuilt/pkg/*/ ; do
    WriteMetaFile "${pkg_dir}/meta"
    local SUB_REPO_DIR=${REPO_DIR}/$(basename ${pkg_dir})
    mkdir -p "${SUB_REPO_DIR}"
    "${PKG_HOST_DIR}/${PKG_FILENAME}/src/pkg" repo \
                 -m "${pkg_dir}/meta" -o "${SUB_REPO_DIR}" "${pkg_dir}"
    cd ${SUB_REPO_DIR}
    tar -xf packagesite.txz
    tar -xf digests.txz
    tar -jcf packagesite.tbz packagesite.yaml
    tar -jcf digests.tbz digests
    cd ${SCRIPT_DIR}
    gsutil cp -a public-read "${SUB_REPO_DIR}/meta.txz" \
        gs://naclports/builds/${SDK_VERSION}/"$1"/publish/$(basename ${pkg_dir})
    gsutil cp -a public-read "${SUB_REPO_DIR}/*.tbz" \
        gs://naclports/builds/${SDK_VERSION}/"$1"/publish/$(basename ${pkg_dir})
  done
}

BuildLocalRepo() {
  local REPO_DIR=${NACLPORTS_ROOT}/out/publish/
  for pkg_dir in ${REPO_DIR}/pkg_*/ ; do
    WriteMetaFile "${pkg_dir}/meta"
    "${PKG_HOST_DIR}/${PKG_FILENAME}/src/pkg" repo \
                 -m "${pkg_dir}/meta" "${pkg_dir}"
    cd ${pkg_dir}
    tar -xf packagesite.txz
    tar -xf digests.txz
    tar -jcf packagesite.tbz packagesite.yaml
    tar -jcf digests.tbz digests
    cd ${SCRIPT_DIR}
  done
}

UsageHelp() {
  echo "./build_repo.sh - Build pkg repository using \
local/remote built packages"
  echo ""
  echo "./build_repo.sh [-l] [-r REVISION]"
  echo "Either provide a revision(-r) for remote built pakcages or \
use -l for local built packages"
  echo ""
  echo "Description"
  echo "-h   show help messages"
  echo "-l   build pkg repository using local built packages"
  echo "-r   build pkg repository using remote built packages"
}

if [[ $# -lt 1 ]]; then
  UsageHelp
  exit 1
fi

OPTIND=1

while getopts "h?lr:" opt; do
  case "$opt" in
    h|\?)
        UsageHelp
        exit 0
        ;;
    l)  local=1
        ;;
    r)  local=0
        revision=$OPTARG
        ;;
  esac
done

shift $((OPTIND - 1))

BuildPkg
if [ ${local} = "1" ]; then
  BuildLocalRepo
else
  BuildRepo $revision
fi

