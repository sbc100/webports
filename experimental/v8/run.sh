#!/bin/bash

DEPS=("gclient"
      "svn"
      "patch"
      "scons")

function run() {
  echo "$@" >&2
  eval "( $@ )" || exit 1
}

function check_deps() {
  local EXIT=false
  for i in ${DEPS[@]}
  do
    if test -z "$(which $i)"
    then
      echo \"$i\" not found
      EXIT=true
    fi
  done
  if test $EXIT == true
  then
    echo "Dependency missing"
    exit 1
  fi
}

function define_arch() {
  if [[ "$(uname -m)" == "x86_64" ]]
  then
    ARCH=64
  elif [[ "$(uname -m)" == "i"[3-6]"86" ]]
  then
    ARCH=32
  else
    echo "Unsupported platform:" $(uname -m)
    exit 1
  fi
}

function define_os() {
  if [[ "$(uname -s)" == "Linux" ]]
  then
    OS="linux"
  elif [[ "$(uname -s)" == "Darwin" ]]
  then
    OS="mac"
  else
    echo Unknown OS: $(uname -s)
    exit 1
  fi
}


check_deps
define_arch
define_os


if ! test -d nacl
then
  run mkdir nacl
fi

if ! test -f nacl/.gclient
then
  cat > nacl/.gclient  << EOF
solutions = [
  { "name"        : "native_client",
    "url"         : "http://src.chromium.org/native_client/trunk/src/native_client",
    "custom_deps" : {
    },
    "safesync_url": "",
  },
]
EOF
fi

# checkout native client revision 3669
if ! test -d nacl/native_client
then
  echo cd nacl && gclient sync --revision 3669
  ( cd nacl && gclient sync --revision 3669 )
  if [[ "$?" == "0" ]]
  then
    echo "the first run supposed to fail"
    exit 1
  fi
  run "cd nacl/native_client && patch -p0 < ../../nacl-r3669-checkout.patch"
  run "cd nacl && gclient sync --revision 3669 --force"
  
  # patch native client
  run "cd nacl/native_client && patch -p0 < ../../nacl-r3669-v8.patch"
fi

# build native client
if ! test -f nacl/native_client/scons-out/opt-$OS-x86-32/staging/sel_ldr
then
  run "cd nacl/native_client && ./scons MODE=opt-$OS platform=x86-32 sdl=none sel_ldr"
fi
if ! test -f nacl/native_client/scons-out/opt-$OS-x86-64/staging/sel_ldr && test $ARCH == 64
then
  run "cd nacl/native_client && ./scons MODE=opt-$OS platform=x86-64 sdl=none sel_ldr"
fi

V8S=(
    "v8-ia32-2.2.19"      "-r4925" "v8-ia32-2.2.19.patch"
    "v8-ia32-3.1.4"       "-r6795" "v8-ia32-3.1.4.patch"
    "nacl-v8-ia32-2.2.19" "-r4925" "nacl-v8-ia32-2.2.19.patch"
    "nacl-v8-ia32-3.1.4"  "-r6795" "nacl-v8-ia32-3.1.4.patch"
    )

if test $ARCH == 64
then
V8S+=(
    "v8-x64-2.2.19"       "-r4925" "v8-x64-2.2.19.patch"
    "nacl-v8-x64-2.2.19"  "-r4925" "nacl-v8-x64-2.2.19.patch"
     )
fi

for (( i=0; i<${#V8S[@]}; i+=3 ))
do
  NAME=${V8S[$i]}
  REV=${V8S[$i+1]}
  PATCH=${V8S[$i+2]}
  
  if ! test -d $NAME
  then
    if ! test -d "v8$REV"
    then
      run svn checkout http://v8.googlecode.com/svn/trunk/ "v8$REV" $REV
    fi
    run cp -r "v8$REV" $NAME
    if ! test -d "sunspider"
    then
      run svn checkout http://svn.webkit.org/repository/webkit/trunk/PerformanceTests/SunSpider/ sunspider -r27790
      run "cd sunspider && patch -p0 < ../sunspider-r27790.patch"
    fi
    run cp -r sunspider $NAME/SunSpider
    run "cd $NAME && patch -p0 < ../$PATCH"
    run chmod +x $NAME/run.sh
  fi

  if ! test -f $NAME/shell
  then
    run "cd $NAME && ./run.sh release"
  fi
done

V8S=(
    "v8-ia32-2.2.19"      "Unmodified V8-ia32 2.2.19 (revision 4925)"
    "nacl-v8-ia32-2.2.19" "NaCl V8-ia32 2.2.19 (revision 4925)"
    "v8-ia32-3.1.4"       "Unmodified V8-ia32 3.1.4 CrankShaft (revision 6795)"
    "nacl-v8-ia32-3.1.4"  "NaCl V8-ia32 3.1.4 CrankShaft (revision 6795)"
    )

if test $ARCH == 64
then
V8S+=(
    "v8-x64-2.2.19"       "Unmodified V8-x64 2.2.19 (revision 4925)"
    "nacl-v8-x64-2.2.19"  "NaCl V8-x64 2.2.19 (revision 4925)"
     )
fi

for (( i=0; i<${#V8S[@]}; i+=2 ))
do
  NAME=${V8S[$i]}
  MES=${V8S[$i+1]}
  
  echo
  echo $MES - V8 Benchmark Suite
  echo

  run "cd $NAME && ./run.sh release benchmark"

   echo
  echo $MES - SunSpider100 Benchmark Suite
  echo

  run "cd $NAME && ./run.sh release sunspider"
done

#clean
run rm -rf v8-r* sunspider 
