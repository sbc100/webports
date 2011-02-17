// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef PHOTO_H_
#define PHOTO_H_

#include <boost/scoped_ptr.hpp>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/graphics_2d.h>
#include <ppapi/cpp/image_data.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/rect.h>
#include <ppapi/cpp/size.h>
#include <pthread.h>

#include <map>
#include <string>
#include <vector>

#include "examples/graphics/photo/callback.h"
#include "examples/graphics/photo/scripting_bridge.h"
#include "examples/graphics/photo/surface.h"

namespace photo {

// A photo editing demo for Native Client using open source Javascript sliders
// from Carpe Design.  For more info on these sliders, please see:
//     http://carpe.ambiprospect.com/slider/

class Photo : public pp::Instance {
 public:
  explicit Photo(PP_Instance instance) : pp::Instance(instance),
                                         window_width_(0),
                                         window_height_(0),
                                         graphics_2d_context_(NULL),
                                         pixel_buffer_(NULL) {}
  ~Photo();

  // The browser calls this function to get a handle, in form of a pp::Var,
  // to the Native Client-side scriptable object.  The pp::Var takes over
  // ownership of the returned object, meaning the browser can call its
  // destructor.
  // Returns the browser's handle to the plugin side instance.
  virtual pp::Var GetInstanceObject();

  // Called by the browser when the module is all loaded and ready to
  // run.
  virtual bool Init(uint32_t argc, const char* argn[], const char* argv[]);

  // Called whenever the in-browser window changes size.
  virtual void DidChangeView(const pp::Rect& position, const pp::Rect& clip);


  // Bind and publish the module's methods to JavaScript.
  void InitializeMethods(ScriptingBridge* bridge);
  // Bind and publish the module's properties to JavaScript.
  void InitializeProperties(ScriptingBridge* bridge);

  // Get the value for a key from |parameter_dictionary_|; the value is
  // returned via |return_value|.  If the key does not exist, then a NULL
  // value is returned.  |arg_count| must be atleast 1; |args[0]| is the key
  // and must be an NPString.  Return |true| on success.
  pp::Var GetValueForKey(const ScriptingBridge& bridge,
                         const std::vector<pp::Var>& args) const;

  // Set a value in |parameter_dictionary_|; the requested key must already
  // exist in |parameter_dictionary_|.  See ModuleDidLoad() for a list of
  // available keys.  |arg_count| must be at least 2; |args[0]| is the value,
  // and must be a simple type (int, double, string, bool).  Objects are not
  // accepted.  All values are converted to and stored as floats; for example
  // the string "1.3" is stored as a float 1.3f.  |args[1]| is the key and must
  // be an NPString.  Return |true| on success.
  // This method is bound to the JavaScript "setValueForKey" method and is
  // called like this:
  //     module.setValueForKey(value, 'myKey');
  pp::Var SetValueForKey(const ScriptingBridge& bridge,
                         const std::vector<pp::Var>& args);

  // Accessor for the "imageUrl" property.
  pp::Var GetImageUrl(const ScriptingBridge& bridge) const;

  // Mutator for the "imageUrl" property.  Copies the URL in |value| into local
  // storage and the initiates a GET request to the URL.
  bool SetImageUrl(const ScriptingBridge& bridge, const pp::Var& value);

  // Copy the original photo to the working photo, possbily resampling and
  // rotating the working photo.  The working photo has the same dimensions as
  // the module's window, inset by the border size.
  void FitPhotoToWorking();

  // Rotate |photo| by |angle| degrees, leaving the result in |rotated_photo|.
  void RotatePhoto(const Surface* photo, Surface* rotated_photo, float angle);

  // Apply the current values in |parameter_dictionary_| to |working_photo|
  // and puts the results in |final_photo|.
  void ApplyWorkingToFinal(const Surface* working_photo,
                           Surface* final_photo);

  // Called when the GET request initiated in SetImageUrl() completes.  At this
  // point, the file is available to the module.
  void URLDidDownload(const std::vector<uint8_t>& data, int32_t error);

  // Indicate whether a flush is pending.  This can only be called from the
  // main thread; it is not thread safe.
  bool flush_pending() const {
    return flush_pending_;
  }
  void set_flush_pending(bool flag) {
    flush_pending_ = flag;
  }

 private:
  typedef std::map<std::string, float> ParameterDictionary;

  // Create and initialize the 2D context used for drawing.
  void CreateContext(const pp::Size& size);
  // Destroy the 2D drawing context.
  void DestroyContext();
  // A context is valid when the Pepper device has been successfully acuqired
  // and initialized.
  bool IsContextValid();
  // Copy the fully constructed photo to the Pepper 2D context and flush it
  // to the browser.
  bool Paint();

  // Internal storage for the imageUrl property exposed to JavaScript.
  std::string image_url_;

  // The dimensions of the module's window in the browser.
  int window_width_;
  int window_height_;

  // A dictionary of photo editing parameters.  This is populated with keys and
  // default values in ModuleDidLoad().
  ParameterDictionary parameter_dictionary_;

  // The various surfaces used to assemble the final processed image.
  boost::scoped_ptr<Surface> original_photo_;
  boost::scoped_ptr<Surface> temp_photo_;
  boost::scoped_ptr<Surface> working_photo_;
  boost::scoped_ptr<Surface> rotated_photo_;
  boost::scoped_ptr<Surface> final_photo_;

  pp::Graphics2D* graphics_2d_context_;
  pp::ImageData* pixel_buffer_;
  bool flush_pending_;
};

}  // namespace photo

#endif  // PHOTO_H_
