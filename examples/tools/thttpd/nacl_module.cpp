/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "nacl_module.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/mount.h>
#include <unistd.h>

#include <cstdio>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <utility>
#include <vector>

#include "json/json.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"
#include "nacl_io/nacl_io.h"

ThttpdInstance* ThttpdInstance::instance_ = NULL;

extern "C" int thttpd_main(int argc, char** argv);

static void* thttpd_thread_main(void* ptr) {
  pp::Instance* instance = ThttpdInstance::getInstance();
  int result = mount("", "/upload", "html5fs", 0, NULL);

  Json::Value writerRoot;
  if (result) {
    writerRoot["error"] = "could not mount";
    writerRoot["errnostr"] = strerror(errno);
  }
  writerRoot["result"] = result;
  writerRoot["type"] = "mount";

  Json::StyledWriter writer;
  instance->PostMessage(writer.write(writerRoot));
  if (result)
    return NULL;

  // Pass -D, otherwise thttpd will close stdin/stdout/stderr
  // and out syscall calls will not longer be visible.
  int argc = 2;
  char* argv[3] = { (char*)"thttpd", (char*)"-D", NULL };
  thttpd_main(argc, argv);
  return NULL;
};

ThttpdInstance::ThttpdInstance(PP_Instance instance) : pp::Instance(instance) {
  MakeUpFiles();
  instance_ = this;
  nacl_io_init_ppapi(pp_instance(), pp::Module::Get()->get_browser_interface());
  pthread_create(&thread_, NULL, thttpd_thread_main, NULL);
}

void ThttpdInstance::MakeUpFiles() {
  const char* path = "/index.html";
  mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
  mkdir("/boo", mode);
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, mode);
  if (fd >= 0) {
    const char* what = "<html>\n<body>\n<a href=\"/upload/\">upload</a>";
    write(fd, what, strlen(what));
    close(fd);
  }
}

void ThttpdInstance::HandleMessage(const pp::Var& var_message) {
  fprintf(stderr, "got unexpected HandleMessage");
}

pp::Instance* ThttpdModule::CreateInstance(PP_Instance instance) {
  ThttpdInstance* result = new ThttpdInstance(instance);
  return result;
}
