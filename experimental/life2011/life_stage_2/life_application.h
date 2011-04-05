// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIFE_APPLICATION_H_
#define LIFE_APPLICATION_H_

#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/graphics_2d.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/rect.h>
#include <ppapi/cpp/size.h>

#include <cstdlib>
#include <map>
#include <memory>
#include <tr1/memory>
#include <vector>

#include "experimental/life2011/life_stage_2/condition_lock.h"
#include "experimental/life2011/life_stage_2/life.h"
#include "experimental/life2011/life_stage_2/locking_image_data.h"
#include "experimental/life2011/life_stage_2/pthread_ext.h"
#include "experimental/life2011/life_stage_2/scripting_bridge.h"
#include "experimental/life2011/life_stage_2/stamp.h"

namespace life {
// The main object that runs Conway's Life simulation (for details, see:
// http://en.wikipedia.org/wiki/Conway's_Game_of_Life).  This class holds all
// the Pepper objects (the 2D context and the instance) required to interface
// with the browser.  It also owns an instance of the simulation object.
class LifeApplication : public pp::Instance {
 public:
  // The states for the |sim_state_condition_| condition lock.
  enum SimulationState {
    kStopped,
    kRunning
  };

  explicit LifeApplication(PP_Instance instance);
  virtual ~LifeApplication();

  // Called by the browser when the NaCl module is loaded and all ready to go.
  virtual bool Init(uint32_t argc, const char* argn[], const char* argv[]);

  // Update the graphics context to the new size, and reallocate all new
  // buffers to the new size.
  virtual void DidChangeView(const pp::Rect& position, const pp::Rect& clip);

  // Return a pp::Var that represents the interface exposed to the browser.
  // The pp::Var takes over ownership of the returned script object.
  virtual pp::Var GetInstanceObject();

  // Runs a tick of the simulations, updating all buffers.  Flushes the
  // contents of |pixel_buffer_| to the 2D graphics context.
  void Update();

  // Replace the current stamp.  See stamp.h for a description of the stamp
  // format.  Exposed to the browser as "setCurrentStamp()".  |args[0]| is
  // expected to be a string variable that contains the stamp definition.
  // Returns a bool Var indicating success.  On failure, |exception| is set to
  // indicate the error. If |exception| is NULL, no error value is set.
  pp::Var SetCurrentStamp(const scripting::ScriptingBridge& bridge,
                          const std::vector<pp::Var>& args,
                          pp::Var* exception);

  // Set the automaton rules.  The rules are expressed as a string, with the
  // Birth and Keep Alive rules separated by a '/'.  The format follows the .LIF
  // 1.05 format here: http://psoup.math.wisc.edu/mcell/ca_files_formats.html
  // Survival/Birth.  Exposed to the browser as "setAutomatonRules()".
  // |args[0]| is expected to be a string type; if not then do nothing.
  // Returns a bool Var indicating success.  On failure, |exception| is set to
  // indicate the error. If |exception| is NULL, no error value is set.
  pp::Var SetAutomatonRules(const scripting::ScriptingBridge& bridge,
                            const std::vector<pp::Var>& args,
                            pp::Var* exception);

  // Clears the current simulation (resets back to all-dead, graphics buffer to
  // black).  Exposed to the browser as "clear()".  |args| can be empty.
  // Returns a bool Var indicating success.  On failure, |exception| is set to
  // indicate the error. If |exception| is NULL, no error value is set.
  pp::Var Clear(const scripting::ScriptingBridge& bridge,
                const std::vector<pp::Var>& args,
                pp::Var* exception);

  // Plot a new blob of life centered around (|args[0]|, |args[1]|).  There
  // must be at least two args, both of them number values.  This method is
  // exposed to the browser as "putStampAtPoint()".  Returns a bool Var
  // indicating success. On failure, |exception| is set to indicate the error.
  // If |exception| is NULL, no error value is set.
  pp::Var PutStampAtPoint(const scripting::ScriptingBridge& bridge,
                          const std::vector<pp::Var>& args,
                          pp::Var* exception);

  // Run the simulation in the sepcified mode.  If the mode is changed, then
  // the simulation is stoped and restarted in the new mode.  |args[0]| is
  // expected to be a string describing the mode, and can be one of
  // "random_seed" or "stamp".  Exposed to the browser as "runSimulation()".
  // Returns a bool Var indicating success.  On failure, |exception| is set to
  // indicate the error. If |exception| is NULL, no error value is set.
  pp::Var RunSimulation(const scripting::ScriptingBridge& bridge,
                        const std::vector<pp::Var>& args,
                        pp::Var* exception);

  // Stop the simulation.  Does nothing if the simulation is stopped.
  // Exposed to the browser as "stopSimulation()".  |args| can be empty.
  // Returns a bool Var indicating success.  On failure, |exception| is set to
  // indicate the error. If |exception| is NULL, no error value is set.
  pp::Var StopSimulation(const scripting::ScriptingBridge& bridge,
                         const std::vector<pp::Var>& args,
                         pp::Var* exception);

  int width() const {
    return shared_pixel_buffer_ ? shared_pixel_buffer_->size().width() : 0;
  }
  int height() const {
    return shared_pixel_buffer_ ? shared_pixel_buffer_->size().height() : 0;
  }

  // Indicate whether the simulation is running or paused.
  bool is_running() const {
    return life_simulation_.simulation_mode() != life::Life::kPaused;
  }

  // Indicate whether a flush is pending.  This can only be called from the
  // main thread; it is not thread safe.
  bool flush_pending() const {
    return flush_pending_;
  }
  void set_flush_pending(bool flag) {
    flush_pending_ = flag;
  }

 private:
  // Create and initialize the 2D context used for drawing.
  void CreateContext(const pp::Size& size);
  // Destroy the 2D drawing context.
  void DestroyContext();
  // Push the pixels to the browser, then attempt to flush the 2D context.  If
  // there is a pending flush on the 2D context, then update the pixels only
  // and do not flush.
  void FlushPixelBuffer();
  // Return a pointer to the pixels without acquiring the pixel buffer lock.
  uint32_t* PixelBufferNoLock();

  bool IsContextValid() const {
    return graphics_2d_context_ != NULL;
  }

  // The simulation.
  Life life_simulation_;

  // 2D context variables.
  std::tr1::shared_ptr<LockingImageData> shared_pixel_buffer_;
  pp::Graphics2D* graphics_2d_context_;
  bool flush_pending_;
  bool view_changed_size_;
  pp::Size view_size_;

  // The current stamp.  The dictionary of stamps is kept in the browser.
  std::auto_ptr<Stamp> stamp_;
};

}  // namespace life

#endif  // LIFE_APPLICATION_H_

