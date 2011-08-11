/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPIPEMOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPIPEMOUNT_H_

#include <map>
#include <string>
#include <vector>
#include "../base/BaseMount.h"
#include "../util/SimpleAutoLock.h"
#include "../util/macros.h"

// Interface for outbound pipe pool.
class JSOutboundPipeBridge {
 public:
  JSOutboundPipeBridge() {}

  // Called by JSPipeMount to write to the bridge.
  // Arguments:
  //   buf: a block of bytes of size count
  //   count: size of the block to send outgoing
  // Write is assumed to be non-blocking and always successful.
  // JSPipeMount will encode and decode the pipe id into the message.
  virtual void Post(const void *buf, size_t count) = 0;

 private:
  DISALLOW_COPY_AND_ASSIGN(JSOutboundPipeBridge);
};

// JSPipeMount redirects I/O to a pipe bridge structured to work with
// javascript.
// It can pretend to be a tty for use in terminal emulation (the default).
// It assumes a numerical pipe path like:
//    /dev/jspipe/0
class JSPipeMount : public BaseMount {
 public:
  JSPipeMount();
  virtual ~JSPipeMount();

  // Select the outbound bridge to write to.
  void set_outbound_bridge(JSOutboundPipeBridge *outbound_bridge) {
    outbound_bridge_ = outbound_bridge;
  }

  // Selects if this pipe mount is for ttys.
  void set_is_tty(int is_tty) { is_tty_ = is_tty; }

  // Selects a prefix that will be prepended to incoming and outgoing messages.
  void set_prefix(const std::string& prefix) { prefix_ = prefix; }

  // Creat() is successful if the path is a non-zero integer.
  int Creat(const std::string& path, mode_t mode, struct stat* st);

  // GetNode() is successful if the path is a non-zero integer.
  int GetNode(const std::string& path, struct stat* st);

  int Stat(ino_t node, struct stat *buf);
  ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  ssize_t Write(ino_t node, off_t offset, const void *buf, size_t count);
  int Isatty(ino_t node) { return is_tty_; }

  // Called by external writer (javascript HandleMessage) to inject incoming
  // data to a pipe.
  // Arguments:
  //   buf: a block of bytes of size count
  //   count: size of the block to send outgoing
  // Returns:
  //   A flag indicating if the message was consumed, allowing multiple
  //       kinds of incoming messages. Prefixes are used to multiplex.
  virtual bool Receive(const void *buf, size_t count);

 private:
  int is_tty_;
  JSOutboundPipeBridge *outbound_bridge_;
  std::map<int, std::vector<char> > incoming_;
  pthread_mutex_t incoming_lock_;
  std::string prefix_;

  DISALLOW_COPY_AND_ASSIGN(JSPipeMount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPIPEMOUNT_H_
