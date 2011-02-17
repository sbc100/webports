// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo/scripting_bridge.h"

#include <assert.h>
#include <string.h>
#include <tr1/memory>

#include "examples/graphics/photo/callback.h"

namespace photo {

bool ScriptingBridge::AddMethodNamed(const std::string& method_name,
                                     SharedMethodCallbackExecutor method) {
  if (method_name.size() == 0 || method == NULL)
    return false;
  method_dictionary_.insert(
      std::pair<std::string, SharedMethodCallbackExecutor>(method_name,
                                                           method));
  return true;
}

bool ScriptingBridge::AddPropertyNamed(
    const std::string& property_name,
    SharedPropertyAccessorCallbackExecutor property_accessor,
    SharedPropertyMutatorCallbackExecutor property_mutator) {
  if (property_name.size() == 0 || property_accessor == NULL)
    return false;
  property_accessor_dictionary_.insert(
      std::pair<std::string,
      SharedPropertyAccessorCallbackExecutor>(property_name,
                                              property_accessor));
  if (property_mutator) {
    property_mutator_dictionary_.insert(
        std::pair<std::string,
        SharedPropertyMutatorCallbackExecutor>(property_name,
                                               property_mutator));
  }
  return true;
}

bool ScriptingBridge::HasMethod(const pp::Var& method, pp::Var* exception) {
  if (!method.is_string()) {
    return false;
  }
  MethodDictionary::const_iterator i;
  i = method_dictionary_.find(method.AsString());
  return i != method_dictionary_.end();
}

bool ScriptingBridge::HasProperty(const pp::Var& name, pp::Var* exception) {
  if (!name.is_string()) {
    return false;
  }
  PropertyAccessorDictionary::const_iterator i;
  i = property_accessor_dictionary_.find(name.AsString());
  return i != property_accessor_dictionary_.end();
}

pp::Var ScriptingBridge::GetProperty(const pp::Var& name, pp::Var* exception) {
  if (!name.is_string()) {
    // TODO(dspringer): Set the exception here.
    return pp::Var();
  }
  PropertyAccessorDictionary::iterator i;
  i = property_accessor_dictionary_.find(name.AsString());
  if (i != property_accessor_dictionary_.end()) {
    return (*i->second).Execute(*this);
  }
  return pp::Var();
}

void ScriptingBridge::SetProperty(const pp::Var& name,
                                  const pp::Var& value,
                                  pp::Var* exception) {
  if (!name.is_string()) {
    // TODO(dspringer): Set the exception here.
    return;
  }
  PropertyMutatorDictionary::iterator i;
  i = property_mutator_dictionary_.find(name.AsString());
  if (i != property_mutator_dictionary_.end()) {
    if (!(*i->second).Execute(*this, value)) {
      // TODO(dspringer): Set the exception here.
      return;
    }
  }
}

pp::Var ScriptingBridge::Call(const pp::Var& method,
                              const std::vector<pp::Var>& args,
                              pp::Var* exception) {
  if (!method.is_string()) {
    return pp::Var();
  }
  MethodDictionary::iterator i;
  i = method_dictionary_.find(method.AsString());
  if (i != method_dictionary_.end()) {
    return (*i->second).Execute(*this, args);
  }
  return pp::Var();
}

}  // namespace photo
