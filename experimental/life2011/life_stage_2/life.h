// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIFE_H_
#define LIFE_H_

#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/graphics_2d.h>
#include <ppapi/cpp/image_data.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/rect.h>
#include <ppapi/cpp/size.h>
#include <pthread.h>

#include <cstdlib>
#include <map>
#include <vector>

namespace life {
// The main object that runs Conway's Life simulation (for details, see:
// http://en.wikipedia.org/wiki/Conway's_Game_of_Life).  The Update() method
// is called by the browser to do a single tick of the simulation.
class Life : public pp::Instance {
 public:
  // The possible play modes.  These are set by RunSimulation().
  enum PlayMode {
    kRandomSeedMode,
    kStampMode
  };

  explicit Life(PP_Instance instance);
  virtual ~Life();

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

  // Clears the current simulation (resets back to all-dead, graphcis buffer to
  // black).  Exposed to the browser as "clear()".
  void Clear();

  // Plot a new blob of life centered around (|var_x|, |var_y|).  This method
  // is exposed to the browser as "addCellAtPoint()".
  void AddCellAtPoint(const pp::Var& var_x, const pp::Var& var_y);

  // Run the simulation in a mode.  If the mode is changed, then the simulation
  // is stoped and restarted in the new mode.  |simulation_mode| is expected
  // to be a string.  Exposed to the browser as "runSimulation()".
  void RunSimulation(const pp::Var& simulation_mode);

  // Stop the simulation.  Does nothing if the simulation is stopped.
  // Exposed to the browser as "stopSimulation()".
  void StopSimulation();

  int width() const {
    return pixel_buffer_ ? pixel_buffer_->size().width() : 0;
  }
  int height() const {
    return pixel_buffer_ ? pixel_buffer_->size().height() : 0;
  }
  PlayMode play_mode() const {
    return play_mode_;
  }

  // Indicate whether the simulation is running or paused.
  bool is_running() const {
    return is_running_;
  }
  void set_is_running(bool flag) {
    is_running_ = flag;
  }

  // Indicate whether a flush is pending.  This can only be called from the
  // main thread; it is not thread safe.
  bool flush_pending() const {
    return flush_pending_;
  }
  void set_flush_pending(bool flag) {
    flush_pending_ = flag;
  }

  // Cheap bit used by the simulation thread to decide when it should shut
  // down.
  bool is_simulation_running() const {
    return is_simulation_running_;
  }
  void set_is_simulation_running(bool flag) {
    is_simulation_running_ = flag;
  }

  friend class ScopedPixelLock;

 private:
  // This class exposes the scripting interface for this NaCl module.  The
  // HasMethod method is called by the browser when executing a method call on
  // the |life| object (see, e.g. the update() function in
  // life.html).  The name of the JavaScript function (e.g. "paint") is
  // passed in the |method| parameter as a string pp::Var.  If HasMethod()
  // returns |true|, then the browser will call the Call() method to actually
  // invoke the method.
  class LifeScriptObject : public pp::deprecated::ScriptableObject {
   public:
    explicit LifeScriptObject(Life* app_instance)
        : pp::deprecated::ScriptableObject(),
          app_instance_(app_instance) {}
    virtual ~LifeScriptObject() {}
    // Return |true| if |method| is one of the exposed method names.
    virtual bool HasMethod(const pp::Var& method, pp::Var* exception);

    // Invoke the function associated with |method|.  The argument list passed
    // in via JavaScript is marshaled into a vector of pp::Vars.
    virtual pp::Var Call(const pp::Var& method,
                         const std::vector<pp::Var>& args,
                         pp::Var* exception);
   private:
    Life* app_instance_;  // weak reference.
  };

  // Produce single bit random values.  Successive calls to value() should
  // return 0 or 1 with a random distribution.
  class RandomBitGenerator {
   public:
    // Initialize the random number generator with |initial_seed|.
    explicit RandomBitGenerator(unsigned int initial_seed)
        : random_bit_seed_(initial_seed) {}
    // Return the next random bit value.  Note that value() can't be a const
    // function because it changes the internal state machine as part of its
    // mechanism.
    uint8_t value();

   private:
    unsigned int random_bit_seed_;
    RandomBitGenerator();  // Not implemented, do not use.
  };

  // Plot a new seed cell in the simulation.  If |x| or |y| fall outside of the
  // size of the 2D context, then do nothing.
  void Plot(int x, int y);

  // Add in some random noise to the borders of the simulation, which is used
  // to determine the life of adjacent cells.  This is part of a simulation
  // tick.
  void AddRandomSeed();

  // Draw the current state of the simulation into the pixel buffer.
  void UpdateCells();

  // Swap the input and output cell arrays.
  void Swap();

  // Clear out the cell buffers (reset to all-dead).  Note: this assumes that
  // the mutex locking the cell buffers has ben acquired.
  void ResetCells();

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

  // The main game loop.  This loop runs the Life simulation.  |param| is a
  // pointer to the Life instance.  This routins is run on its own thread.
  static void* LifeSimulation(void* param);

  // Thread support variables.
  pthread_t life_simulation_thread_;
  bool is_simulation_running_;
  mutable pthread_mutex_t pixel_buffer_mutex_;

  // 2D context variables.
  pp::Graphics2D* graphics_2d_context_;
  pp::ImageData* pixel_buffer_;
  bool flush_pending_;
  bool view_changed_size_;
  pp::Size view_size_;

  // Simulation variables.
  PlayMode play_mode_;
  bool is_running_;
  RandomBitGenerator random_bits_;
  uint8_t* cell_in_;
  uint8_t* cell_out_;
};

}  // namespace life

#endif  // LIFE_H_

