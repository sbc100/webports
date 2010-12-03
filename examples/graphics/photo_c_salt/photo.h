// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_GRAPHICS_PHOTO_C_SALT_PHOTO_H_
#define EXAMPLES_GRAPHICS_PHOTO_C_SALT_PHOTO_H_

#include <boost/shared_ptr.hpp>
#include <map>
#include <string>

#include "c_salt/instance.h"
#include "c_salt/module.h"
#include "c_salt/scripting_bridge.h"

#include "examples/graphics/photo_c_salt/image.h"
#include "examples/graphics/photo_c_salt/graphics_2d_context.h"
#include "examples/graphics/photo_c_salt/url_loader.h"

namespace photo {

// A photo editing demo for Native Client using open source Javascript sliders
// from Carpe Design.  For more info on these sliders, please see:
// http://carpe.ambiprospect.com/slider/

class Photo : public c_salt::Instance {
 public:
  explicit Photo(NPP npp);
  ~Photo();

  // Specialization of c_salt::Instance informal protocol.
  virtual bool InstanceDidLoad(int width, int height);

  // Called whenever the in-browser window changes size.
  virtual void WindowDidChangeSize(int width, int height);
  virtual void OnURLLoaded(const char* data, size_t data_sz);

  // Bind and publish the module's methods to JavaScript.
  virtual void InitializeMethods(c_salt::ScriptingBridge* bridge);

  // Initiates a GET request to the URL.
  // This method is bound to the JavaScript "loadImage" method and is
  // called like this:
  //    module.loadImage(url);
  bool LoadImageFromURL(std::string url);

  // Set a value in |parameter_dictionary_|; the requested key must already
  // exist in |parameter_dictionary_|.  See ModuleDidLoad() for a list of
  // available keys.
  // This method is bound to the JavaScript "setValueForKey" method and is
  // called like this:
  //     module.setValueForKey('myKey', value);
  bool SetValueForKey(std::string key, double value);

  // Returns number of frames per second.
  // This method is bound to the JavaScript "getFPS" method and is
  // called like this:
  //     var fps = module.getFPS();
  int32_t GetFPS();

  // Called when the GET request initiated in LoadImageFromURL() completes.
  // At thispoint, the file is available to the module.
  void OnImageDownloaded();

  // Apply the current values in |parameter_dictionary_| to |processed_photo_|.
  void ApplyColorTransform();

 private:
  typedef std::map<std::string, float> ParameterDictionary;

  // Copy the fully constructed photo to the Pepper 2D context and flush it
  // to the browser.
  void Paint();

  // Apply the current values in |parameter_dictionary_| to |scaled_photo_|
  // and puts the results in |processed_photo_|.
  void ProcessPhoto();

  // The dimensions of the module's window in the browser.
  int window_width_;
  int window_height_;

  // A dictionary of photo editing parameters.  This is populated with keys and
  // default values in ModuleDidLoad().
  ParameterDictionary parameter_dictionary_;

  // The various images used to assemble the final processed image.
  c_salt::Image original_photo_;
  c_salt::Image scaled_photo_;
  c_salt::Image processed_photo_;

  c_salt::Graphics2DContext graphics_context_;
  c_salt::URLLoader url_loader_;
  int32_t frames_per_seconds_;
};

class PhotoModule : public c_salt::Module {
  public:
    virtual c_salt::Instance* CreateInstance(const NPP& npp_instance) {
      boost::shared_ptr<Photo> photo_ptr(new Photo(npp_instance));
      photo_ptr->CreateScriptingBridgeForObject(photo_ptr);
      return photo_ptr.get();
    }
  };

}  // namespace photo

#endif  // EXAMPLES_GRAPHICS_PHOTO_C_SALT_PHOTO_H_

