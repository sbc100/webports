// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

/// @file
/// This example demonstrates loading, running and scripting a very simple NaCl
/// module.  To load the NaCl module, the browser first looks for the
/// CreateModule() factory method (at the end of this file).  It calls
/// CreateModule() once to load the module code from your .nexe.  After the
/// .nexe code is loaded, CreateModule() is not called again.
///
/// Once the .nexe code is loaded, the browser calls the ComputeUsingString()
/// and ComputeUsingArray() methods on the object returned by CreateModule().
/// Both of these methods are passed an array of numbers: one as a string with
/// the numbers separated by spaces, and the other as a Javascript array.
/// Both methods sum the numbers of the array -- having the two methods is used
/// to measure the relative performance of each approach.
///

#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <string>
#include <vector>

namespace {

/// method name for computeSumOfIntsInArray, as seen by Javascript code.
const char* const kProcessArrayMethodId = "computeSumOfIntsInArray";
/// method name for computeSumOfIntsInString, as seen by Javascript code.
const char* const kProcessStringMethodId = "computeSumOfIntsInString";

/// Use @a delims to identify all the elements in @ the_string, and add
/// these elements to the end of @a the_data.  Return how many elements
/// were found.
/// @param the_string [in] A string containing the data to be parsed.
/// @param delims [in] A string containing the characters used as delimiters.
/// @param the_data [out] A pointer to vector of strings to which the elements
/// are added.
/// @return The number of elements added to @ the_data.
int GetElementsFromString(std::string the_string, std::string delims,
                          std::vector<std::string>* the_data) {
  size_t element_start = 0, element_end;
  unsigned int elements_found = 0;
  bool found_an_element = false;
  do {
    found_an_element = false;
    // find first non-delimeter
    element_start = the_string.find_first_not_of(delims, element_start);
    if (element_start != std::string::npos) {
      found_an_element = true;
      element_end = the_string.find_first_of(delims, element_start+1);
      std::string the_element = the_string.substr(element_start,
                                                  element_end - element_start);
      the_data->push_back(the_element);
      ++elements_found;
      // Set element_start (where to look for non-delim) to element_end, which
      // is where we found the last delim.  Don't add 1 to element_end, or else
      // we may start past the end of the string when last delim was last char
      // of the string.
      element_start = element_end;
    }
  } while (found_an_element);
  return elements_found;
}

///
/// Given an integer value, use snprintf to convert it to a quoted char array
/// and then convert that to a string.  Checks for truncation and ensures the
/// char array is null-terminated
///
std::string IntToString(int val) {
  const int kBuffSize = 255;
  char buffer[kBuffSize+1];
  // ensure null-termination of buffer
  buffer[kBuffSize] = '\0';
  // snprintf only puts null character on end if there is space, so we tell
  // give the size as kBuffSize when it's really kBuffSize+1 so that we can
  // always guarantee a null character on the end.
  int len = snprintf(buffer, kBuffSize, "%d", val);
  if (len >= kBuffSize) {
    printf("%d was truncated when converting\n", val);
  }
  return std::string(buffer);
}

// Called from browser -- this is a function that is passed a Javascript
// string containing space-separated numbers.  This method uses
// GetElementsFromString to get the values and returns their sum.
std::string ComputeUsingString(const pp::Var& arg) {
  // The arg should be a string
  if (!arg.is_string()) {
    return "Arg from Javascript is not a string!";
  }

  pp::Var exception;  // Use initial "undefined" Var for exception
  std::string arg_string = arg.AsString();

  std::vector<std::string> words;
  GetElementsFromString(arg_string, std::string(" "), &words);

  double sum = 0.0;
  for (std::vector<std::string>::iterator iter = words.begin();
       iter != words.end(); ++iter) {
      std::string a_word = *iter;
      int a_number = atoi(a_word.c_str());
      sum += a_number;
  }
  return IntToString(sum);
}

// Called from browser -- this is a function that is passed a Javascript
// array containing doubles.  This method asks the array for its length, then
// asks for the indices (0...|length|-1), converting each to a double.
std::string ComputeUsingArray(const pp::Var& arg) {
  // The arg should be an object
  if (!arg.is_object()) {
    return "Arg from Javascript is not an object!";
  }

  pp::Var exception;  // Use initial "undefined" Var for exception
  pp::Var var_length = arg.GetProperty("length", &exception);
  if (!exception.is_undefined()) {
    return "Error: Exception encountered when getting length";
  }

  int length = var_length.AsInt();
  int sum = 0;
  // Fill the initial_matrix with values from the JS array object
  for (int i = 0; i < length; ++i) {
    std::string str_index = IntToString(i);
    bool has_prop = arg.HasProperty(str_index, &exception);
    if (!exception.is_undefined()) {
      return "Error: Exception encountered when getting index property";
    }
    if (has_prop) {
      pp::Var index_var = arg.GetProperty(str_index, &exception);
      if (!exception.is_undefined()) {
        return "Error: Exception encountered when getting property";
      }
      int value;
      if (index_var.is_number())
        value = index_var.AsInt();
      sum += value;
    }
  }
  return IntToString(sum);
}

}  // namespace

/// This class exposes the scripting interface for this NaCl module.  The
/// HasMethod() method is called by the browser when executing a method call on
/// the @a perfTestModule object (see the reverseText() function in
/// perf_test.html).  The name of the JavaScript function (e.g. "fortyTwo") is
/// passed in the @a method parameter as a string pp::Var.  If HasMethod()
/// returns @a true, then the browser will call the Call() method to actually
/// invoke the method.
class PerfTestScriptableObject : public pp::deprecated::ScriptableObject {
 public:
  /// Determines whether a given method is implemented in this object.
  /// @param method [in] A JavaScript string containing the method name to check
  /// @param exception Unused
  /// @return @a true if @a method is one of the exposed method names.
  virtual bool HasMethod(const pp::Var& method, pp::Var* exception);

  /// Invoke the function associated with @a method.  The argument list passed
  /// via JavaScript is marshaled into a vector of pp::Vars.  None of the
  /// functions in this example take arguments, so this vector is always empty.
  /// @param method [in] A JavaScript string with the name of the method to call
  /// @param args [in] A list of the JavaScript parameters passed to this method
  /// @param exception unused
  /// @return the return value of the invoked method
  virtual pp::Var Call(const pp::Var& method,
                       const std::vector<pp::Var>& args,
                       pp::Var* exception);
};

bool PerfTestScriptableObject::HasMethod(const pp::Var& method,
                                           pp::Var* /* exception */) {
  if (!method.is_string()) {
    return false;
  }
  std::string method_name = method.AsString();
  bool has_method =
      method_name == kProcessArrayMethodId ||
      method_name == kProcessStringMethodId;
  return has_method;
}

pp::Var PerfTestScriptableObject::Call(const pp::Var& method,
                                       const std::vector<pp::Var>& args,
                                       pp::Var* /* exception */) {
  if (!method.is_string()) {
    return pp::Var();
  }
  // Both of the exposed functions take a single argument.
  if (args.size() != 1) {
    return pp::Var("Unexpected number of args");
  }
  // Now that we checked args.size, pass args[0] to functions.
  std::string method_name = method.AsString();
  if (method_name == kProcessArrayMethodId) {
    return pp::Var(ComputeUsingArray(args[0]));
  } else if (method_name == kProcessStringMethodId) {
    return pp::Var(ComputeUsingString(args[0]));
  }
  return pp::Var();
}

/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurrence of the <embed> tag.
/// The Instance can return a ScriptableObject representing itself.  When the
/// browser encounters JavaScript that wants to access the Instance, it calls
/// the GetInstanceObject() method.  All the scripting work is done through
/// the returned ScriptableObject.
class PerfTestInstance : public pp::Instance {
 public:
  explicit PerfTestInstance(PP_Instance instance) : pp::Instance(instance) {}
  virtual ~PerfTestInstance() {}

  /// @return a new pp::deprecated::ScriptableObject as a JavaScript @a Var
  /// @note The pp::Var takes over ownership of the PerfTestScriptableObject
  ///       and is responsible for deallocating memory.
  virtual pp::Var GetInstanceObject() {
    PerfTestScriptableObject* hw_object = new PerfTestScriptableObject();
    return pp::Var(this, hw_object);
  }
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of you NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with
/// <code>type="application/x-nacl"</code>.
class PerfTestModule : public pp::Module {
 public:
  PerfTestModule() : pp::Module() {}
  virtual ~PerfTestModule() {}

  /// Create and return a PerfTestInstance object.
  /// @param instance [in] a handle to a plug-in instance.
  /// @return a newly created PerfTestInstance.
  /// @note The browser is responsible for calling @a delete when done.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new PerfTestInstance(instance);
  }
};

namespace pp {
/// Factory function called by the browser when the module is first loaded.
/// The browser keeps a singleton of this module.  It calls the
/// CreateInstance() method on the object you return to make instances.  There
/// is one instance per <embed> tag on the page.  This is the main binding
/// point for your NaCl module with the browser.
/// @return new PerfTestModule.
/// @note The browser is responsible for deleting returned @a Module.
Module* CreateModule() {
  return new PerfTestModule();
}
}  // namespace pp

