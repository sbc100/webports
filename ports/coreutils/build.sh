# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BARE_EXECUTABLES="\
[ basename cat chgrp chmod chown cksum comm cp csplit cut date dd dir dircolors
dirname du echo env expand expr factor false fmt fold ginstall head hostname id
join kill link ln logname ls md5sum mkdir mkfifo mknod mv nl nohup od paste
pathchk pr printenv printf ptx pwd readlink rm rmdir seq setuidgid sha1sum
shred sleep sort split stat stty su sum sync tac tail tee test touch tr true
tsort tty unexpand uniq unlink vdir wc whoami yes"

EXECUTABLES=""
for exe in ${BARE_EXECUTABLES}; do
  EXECUTABLES+=" src/${exe}"
done

TRANSLATE_PEXES=no

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -lppapi_simple \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

InstallStep() {
  PublishByArchForDevEnv
}
