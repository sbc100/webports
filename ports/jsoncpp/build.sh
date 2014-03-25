#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

BuildStep() {
  export CXXCMD="${NACLCC} -Iinclude -I."
  LogExecute ${CXXCMD} -c src/lib_json/json_reader.cpp
  LogExecute ${CXXCMD} -c src/lib_json/json_value.cpp
  LogExecute ${CXXCMD} -c src/lib_json/json_writer.cpp

  LogExecute ${NACLAR} rcs libjsoncpp.a \
    json_reader.o \
    json_value.o \
    json_writer.o

  LogExecute ${NACLRANLIB} libjsoncpp.a
}


InstallStep() {
  MakeDir ${DESTDIR_LIB}
  MakeDir ${DESTDIR_INCLUDE}
  LogExecute cp libjsoncpp.a ${DESTDIR_LIB}
  LogExecute cp -R include/json ${DESTDIR_INCLUDE}
}
