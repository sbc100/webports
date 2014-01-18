#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io"
CONFIG_SUB=support/config.sub

BuildStep() {
  # Disable all assembly code by specifying none-none-none.
  DefaultBuildStep --target=none-none-none
}

InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"

  local nexes="\
[
base64
basename
cat
chcon
chgrp
chmod
chown
chroot
cksum
comm
cp
csplit
cut
date
dd
df
dir
dircolors
dirname
du
echo
env
expand
expr
factor
false
fmt
fold
getlimits
ginstall
groups
head
hostid
id
join
kill
link
ln
logname
ls
make-prime-list
md5sum
mkdir
mkfifo
mknod
mktemp
mv
nice
nl
nohup
nproc
numfmt
od
paste
pathchk
pinky
pr
printenv
printf
ptx
pwd
readlink
realpath
rm
rmdir
runcon
seq
setuidgid
sha1sum
sha224sum
sha256sum
sha384sum
sha512sum
shred
shuf
sleep
sort
split
stat
stdbuf
stty
sum
sync
tac
tail
tee
test
timeout
touch
tr
true
truncate
tsort
tty
uname
unexpand
uniq
unlink
uptime
users
vdir
wc
who
whoami
yes
"

  MakeDir ${PUBLISH_DIR}
  for name in ${nexes}; do
    cp src/${name}${NACL_EXEEXT} \
      ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
