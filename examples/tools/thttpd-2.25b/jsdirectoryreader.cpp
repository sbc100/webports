/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "jsdirectoryreader.h"
#include <json/json.h>
#include <nacl-mounts/pepper/PepperFileIOJob.h>
#include <nacl-mounts/util/DebugPrint.h>
#include <cstdio>
#include <set>
#include <string>
#include "shelljob.h"

int JSDirectoryReader::ReadDirectory(const std::string& path,
  std::set<std::string>* entries, const pp::CompletionCallback& cc) {
  ++id;
  cc_[id] = cc;
  entries_[id] = entries;
  char str[12];
  snprintf(str, sizeof(str), "%d", id);
  std::string message = std::string("[\"ReadDirectory\",\"")
    + path + "\",\""+std::string(str)+"\"]";
  instance_->PostMessage(pp::Var(message));
}

void JSDirectoryReader::HandleResponse(const std::string& response) {
  int rid = 0;
  Json::Reader reader;
  Json::Value root;
  if (!reader.parse(response, root)) {
    dbgprintf("ReadDirectory parsing error\n");
    cc_[id].Run(PP_ERROR_BADARGUMENT);
    return;
  }
  if (!root.isArray()) {
    dbgprintf("ReadDirectory result is not array\n");
    cc_[id].Run(PP_ERROR_BADARGUMENT);
    return;
  }
  int i = 0;
  for (Json::Value::iterator it = root.begin(); it != root.end(); ++it) {
    if (i == 0) {
      sscanf((*it).asString().c_str(), "%d", &rid);
    } else {
      entries_[rid]->insert((*it).asString());
    }
    ++i;
  }
  if (rid == 0) {
    dbgprintf("incorrect result: missing rid\n");
    cc_[id].Run(PP_ERROR_BADARGUMENT);
    return;
  }
  cc_[rid].Run(PP_OK);
}

