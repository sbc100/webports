// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_SCRIPTABLE_MATRIX_MATRIX_COMP_H_
#define EXAMPLES_SCRIPTABLE_MATRIX_MATRIX_COMP_H_

#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/var.h>
#include <string>
#include <vector>

namespace {
  const char* kComputeAnswer = "ComputeAnswer";
  const char* kComputeUsingArray = "ComputeUsingArray";
};

// Extends pp::ScriptableObject and adds the plugin's specific functionality.
class MatrixScriptableObject : public  pp::deprecated::ScriptableObject {
 private:
  static std::string ComputeAnswer(const std::vector<pp::Var>& args);
  static std::string ComputeUsingArray(const std::vector<pp::Var>& args);
 public:
  MatrixScriptableObject();
  virtual ~MatrixScriptableObject();

 private:
  virtual bool HasMethod(const pp::Var& method, pp::Var* exception) {
    if (!method.is_string()) {
       return false;
    }
    std::string method_name = method.AsString();
    bool has_method = method_name == kComputeAnswer ||
        method_name == kComputeUsingArray;
    return has_method;
  }
  virtual pp::Var Call(const pp::Var& method,
                       const std::vector<pp::Var>& args,
                       pp::Var* exception) {
    if (!method.is_string()) {
      return pp::Var();
    }
    std::string method_name = method.AsString();
    if (method_name == kComputeAnswer)
      return pp::Var(ComputeAnswer(args));
    else if (method_name == kComputeUsingArray)
      return pp::Var(ComputeUsingArray(args));
    return pp::Var();
  }

};

#endif  // EXAMPLES_SCRIPTABLE_MATRIX_MATRIX_COMP_H_
