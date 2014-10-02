/* Copyright 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

/*
 * Sample set of libgit2 operations. The code in this file is generic
 * and should not depend on PPAPI or chrome (i.e. it should run just
 * run on desktop linux).
 */

#include "operations.h"

#include <git2.h>
#include <stdarg.h>
#include <stdio.h>

#include <string.h>
#include <unistd.h>

static void voutput(const char* message, va_list args) {
  va_list args_copy;
  va_copy(args_copy, args);

  // First send to stdout
  vfprintf(stdout, message, args);

  // Next send via postmessage
  char buffer[1024];
  vsnprintf(buffer, 1024, message, args_copy);
  post_message(buffer);
  va_end(args_copy);
}

void output(const char* message, ...) {
  va_list ap;
  va_start(ap, message);
  voutput(message, ap);
  va_end(ap);
}

static int transfer_progress(const git_transfer_progress* stats,
                             void* payload) {
  output("transfered: %d/%d %d KiB\n", stats->received_objects,
      stats->total_objects, stats->received_bytes/1024);
  return 0;
}

static int status_callback(const char* path, unsigned int flags,
                           void* payload) {
  output("%#x: %s\n", flags, path);
  return 0;
}

git_repository* init_repo(const char* repo_directory) {
  git_repository* repo = NULL;
  int rtn = git_repository_open(&repo, repo_directory);
  if (rtn != 0) {
    const git_error* err = giterr_last();
    output("git_repository_open failed %d [%d] %s\n", rtn,
        err->klass, err->message);
    return NULL;
  }

  return repo;
}

void do_git_status(const char* repo_directory) {
  time_t start = time(NULL);
  output("status: %s\n", repo_directory);
  git_repository* repo = init_repo(repo_directory);
  if (!repo)
    return;

  int rtn = git_status_foreach(repo, status_callback, NULL);
  if (rtn == 0) {
    output("status success [%d]\n", time(NULL) - start);
  } else {
    const git_error* err = giterr_last();
    output("status failed %d [%d] %s\n", rtn, err->klass, err->message);
  }

  git_repository_free(repo);
}

void do_git_init(const char* repo_directory) {
  output("init new git repo: %s\n", repo_directory);
  git_repository* repo;
  git_repository_init_options options = GIT_REPOSITORY_INIT_OPTIONS_INIT;
  options.flags = GIT_REPOSITORY_INIT_NO_REINIT | GIT_REPOSITORY_INIT_MKPATH;
  int rtn = git_repository_init_ext(&repo, repo_directory, &options);
  if (rtn == 0) {
    output("init success: %s\n", repo_directory);
  } else {
    const git_error* err = giterr_last();
    output("init failed %d [%d] %s\n", rtn, err->klass, err->message);
  }

  git_repository_free(repo);
}

void do_git_clone(const char* repo_directory, const char* url) {
  git_repository* repo;
  git_remote_callbacks callbacks = GIT_REMOTE_CALLBACKS_INIT;
  callbacks.transfer_progress = &transfer_progress;

  git_clone_options opts = GIT_CHECKOUT_OPTIONS_INIT;
  opts.remote_callbacks = callbacks;
  opts.ignore_cert_errors = 1;

  output("cloning %s -> %s\n", url, repo_directory);
  int rtn = git_clone(&repo, url, repo_directory, &opts);
  if (rtn == 0) {
    output("clone success\n");
    git_repository_free(repo);
  } else {
    const git_error* err = giterr_last();
    output("clone failed %d [%d] %s\n", rtn, err->klass, err->message);
  }
}
