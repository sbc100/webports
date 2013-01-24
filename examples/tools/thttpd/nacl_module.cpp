/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "nacl_module.h"
#include <fcntl.h>
#include <nacl-mounts/base/BaseMount.h>
#include <nacl-mounts/base/KernelProxy.h>
#include <nacl-mounts/base/MainThreadRunner.h>
#include <nacl-mounts/base/MountManager.h>
#include <nacl-mounts/base/UrlLoaderJob.h>
#include <nacl-mounts/memory/MemMount.h>
#include <nacl-mounts/net/SocketSubSystem.h>
#include <nacl-mounts/pepper/PepperMount.h>
#include <nacl-mounts/util/DebugPrint.h>
#include <unistd.h>

#include <cstdio>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <utility>
#include <vector>

#include "json/json.h"
#include "mythread.h"
#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"
#include "shelljob.h"

ThttpdInstance* ThttpdInstance::instance_ = NULL;

void ThttpdInstance::setKernelProxy(KernelProxy* kp) {
  this->kp = kp;
  SocketSubSystem* ss = new SocketSubSystem(this);
  this->kp->SetSocketSubSystem(ss);
}

extern "C"  int my_main(int argc, char** argv);
static const char* path = "/ololo";
static pthread_t thread;

static void* mmain(void* ptr) {
  char** p = reinterpret_cast<char**>(malloc(sizeof(char**) * 2));
  if (!p) return NULL;
  p[1] = 0;
  p[0] = const_cast<char*>(path);
  my_main(1, p);
  return NULL;
};

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

static void DownloadFile(MainThreadRunner* runner, const std::string& path,
    const std::string& local_file) {
  dbgprintf("Downloading file from %s to %s\n", path.c_str(),
              local_file.c_str());
  UrlLoaderJob* job = new UrlLoaderJob();
  job->set_url(path.c_str());
  std::vector<char> data;
  job->set_dst(&data);
  dbgprintf("before runjob, %p\n", job);
  runner->RunJob(job);
  int fh = open(local_file.c_str(), O_CREAT | O_WRONLY);
  dbgprintf("resource fd = %d\n", fh);
  dbgprintf("wrote %d bytes\n", write(fh, &data[0], data.size()));
  close(fh);
}

#define MAXPATHLEN 256
void ThttpdInstance::HandleMessage(const pp::Var& var_message) {
  dbgprintf("HandleMessage called\n");
  if (var_message == NULL || !var_message.is_string()) {
    return;
  }
  pp::Var return_var;
  Json::Value null_value;
  int result = 1;  // no thread
  if (!var_message.is_string()) {
    dbgprintf("error: please send json messages only\n");
    return;
  }
  std::string message = var_message.AsString();
  Json::Value root;
  try {
    Json::Reader reader;
    if (!reader.parse(message, root)) {
      dbgprintf("failed to parse input request\n");
      PostMessage(return_var);
      return;
    }
    if (root.isArray()) {
      if (root.size() > 1 && root[Json::UInt(0)] == "ReadDirectory") {
        dbgprintf("calling ReadDirectory helper\n");
        char cwd[MAXPATHLEN];
        getcwd(cwd, MAXPATHLEN);
        std::pair<Mount*, std::string> pair =
          kp->mm()->GetMount(cwd);  // get cur dir mount
        PepperMount* p;
        if (!(p = static_cast<PepperMount*>(pair.first))) {
          dbgprintf("error: ReadDirectory on incorrect mount wd %s\n", cwd);
        }
        reader_.HandleResponse(root[Json::UInt(1)].asString());
        dbgprintf("HandleMessage finished after call\n");
        return;
      } else {
        dbgprintf("error: ReadDirectory array should contain 2 items:\n");
        dbgprintf("error (cont-d): token and result string\n");
        return;
      }
    } else if (root.isString()) {
      std::string url = root.asString();
      // TODO(vissi): enable file download
      // DownloadFile(runner_, url, std::string("/upload/")+"test.file");
    }
    const std::string action = root["action"].asString();
  }
  catch(const std::runtime_error& e) {
    dbgprintf("runtime error: %s\n", e.what());
  }
}

void ThttpdInstance::InternalThreadEntry() {
  dbgprintf("internal pepper mount\n");
  PepperMount* mount = new PepperMount(this->runner_, fs_, 0x100000);
  mount->SetDirectoryReader(&reader_);
  mount->SetPathPrefix("/");
  int result = kp->mount("/upload", mount);  // BufferMount for speed?

  Json::Value writerRoot;
  if (result) {
      writerRoot["error"] = "could not mount";
      writerRoot["errnostr"] = strerror(errno);
  }
  writerRoot["result"] = result;
  writerRoot["type"] = "mount";

  Json::StyledWriter writer;
  ShellJob* job = new ShellJob(writer.write(writerRoot), *this);
  runner_->RunJob(job);
}

void ThttpdInstance::MakeUpFs() {
  fs_ = new pp::FileSystem(this, PP_FILESYSTEMTYPE_LOCALPERSISTENT);
  StartInternalThread();
}

ThttpdModule::ThttpdModule() : pp::Module() {
  this->kp = KernelProxy::KPInstance();
  this->mm = this->kp->mm();
  std::pair<Mount*, std::string> res = mm->GetMount("/");
  mnt = res.first;
}

pp::Instance* ThttpdModule::CreateInstance(PP_Instance instance) {
  dbgprintf("CreateInstance\n");
  ThttpdInstance* result = new ThttpdInstance(instance);
  result->setKernelProxy(this->kp);
  pthread_create(&thread, NULL, mmain, NULL);
  return result;
}

