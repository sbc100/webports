// Copyright (c) 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include "AppEngineMount.h"
#include "../base/UrlLoaderJob.h"
#include "../base/KernelProxy.h"
#include "../base/MountManager.h"
#include <pthread.h>
#include <stdio.h>

class AppEngineTestInstance : public pp::Instance {
 public:
  explicit AppEngineTestInstance(PP_Instance instance)
    : pp::Instance(instance),
      runner_(this),
      app_engine_thread_(0) {
    KernelProxy *kp = KernelProxy::KPInstance();
    MountManager *mm = kp->mm();
    AppEngineMount *mount = new AppEngineMount(&runner_, "/_file");
    mm->RemoveMount("/");
    mm->AddMount(mount, "/");
    mount_ = mount;
    kp_ = kp;
    count_ = 0;
  }
  virtual ~AppEngineTestInstance() {}

  virtual void HandleMessage(const pp::Var& var_message);
  static void *WriteTestShim(void *p);
  void WriteTest(void);


 private:
  MainThreadRunner runner_;
  KernelProxy *kp_;
  AppEngineMount *mount_;
  pthread_t app_engine_thread_;
  int32_t count_;
};

void *AppEngineTestInstance::WriteTestShim(void *p) {
  AppEngineTestInstance *inst = (AppEngineTestInstance *)p;
  inst->WriteTest();
  return NULL;
}

void AppEngineTestInstance::WriteTest(void) {
  fprintf(stderr, "Running AppEngine Storage Tests\n");
  int fd;
  fprintf(stderr, "open should be 0: %d\n", fd = kp_->open("/tester.txt", O_CREAT | O_RDWR, 0));
  char *buf = (char *)malloc(10);
  buf[0] = '1';
  buf[1] = '2';
  buf[2] = '3';
  buf[3] = '4';
  buf[4] = 'b';
  buf[5] = '6';
  buf[8] = 0;
  buf[9] = 0;
  fprintf(stderr, "write should be 9: %d\n", kp_->write(fd, buf, 9));
  fprintf(stderr, "fsync should be 0: %d\n", kp_->fsync(fd));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd));
  fprintf(stderr, "remove should be 0: %d\n", kp_->remove("/tester.txt"));
	  
  fprintf(stderr, "open should be 0: %d\n", fd = kp_->open("/tester2.txt", O_CREAT | O_RDWR, 0));
  fprintf(stderr, "write should be 9: %d\n", kp_->write(fd, buf, 9));
  fprintf(stderr, "fsync should be 0: %d\n", kp_->fsync(fd));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd));
  fprintf(stderr, "remove should be 0: %d\n", kp_->remove("/tester2.txt"));
  fprintf(stderr, "---------------------------\n");
  int fd1, fd2, fd3;
  char *buf2 = (char *)malloc(1001);
  buf[405] = 'a';
  fprintf(stderr, "open should be 0: %d\n", fd1 = kp_->open("/test/tester1.txt", O_CREAT | O_RDWR, 0));
  fprintf(stderr, "write should be 1001: %d\n", kp_->write(fd1, buf2, 1001));
  fprintf(stderr, "fsync should be 0: %d\n", kp_->fsync(fd1));
  fprintf(stderr, "open should be 1: %d\n", fd2 = kp_->open("/test/tester2.txt", O_CREAT | O_RDWR, 0));
  fprintf(stderr, "write should be 8: %d\n", kp_->write(fd2, buf, 8));
  fprintf(stderr, "fsync should be 0: %d\n", kp_->fsync(fd2));
  fprintf(stderr, "open should be 2: %d\n", fd3 = kp_->open("/test/tester3.txt", O_CREAT | O_RDWR, 0));
  fprintf(stderr, "write should be 1001: %d\n", kp_->write(fd3, buf2, 1001));
  fprintf(stderr, "fsync should be 0: %d\n", kp_->fsync(fd3));
  fprintf(stderr, "open should be 3: %d\n", fd = kp_->open("/test", O_CREAT | O_RDWR, 0));
  fprintf(stderr, "fsync should be -1: %d\n", kp_->fsync(fd));
  fprintf(stderr, "write should be -1: %d\n", kp_->write(fd, buf, 9));
  
  char *buf3 = (char *)malloc(2048);
  fprintf(stderr, "Getdents should be 280*3 = 840: %d\n", kp_->getdents(fd, buf3, 2048));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd1));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd2));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd3));

  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd));
  fprintf(stderr, "open should be 0: %d\n", fd1 = kp_->open("/test/tester1.txt", O_RDWR, 0));
  fprintf(stderr, "close should be 0: %d\n", kp_->close(fd1));

  fprintf(stderr, "remove should be 0: %d\n", kp_->remove("/test/tester1.txt"));
  fprintf(stderr, "remove should be 0: %d\n", kp_->remove("/test/tester2.txt"));
  fprintf(stderr, "remove should be 0: %d\n", kp_->remove("/test/tester3.txt"));
  fprintf(stderr, "remove should be -1: %d\n", kp_->remove("/test"));

  PostMessage(pp::Var(count_));
}

void AppEngineTestInstance::HandleMessage(const pp::Var& var_message) {
  if (!var_message.is_string()) {
    return;
  }

  fprintf(stderr, "About to create pthread\n");
  pthread_create(&app_engine_thread_, NULL, WriteTestShim, this);
}

class AppEngineTestModule : public pp::Module {
 public:
  AppEngineTestModule() : pp::Module() {
  }
  virtual ~AppEngineTestModule() {}

  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new AppEngineTestInstance(instance);
  }
};

namespace pp {
  Module* CreateModule() {
    return new AppEngineTestModule();
  }
}  // namespace pp
