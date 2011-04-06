// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIFE_H_
#define LIFE_H_

#include <ppapi/cpp/image_data.h>
#include <ppapi/cpp/point.h>

#include <string>
#include <tr1/memory>
#include <vector>

#include "experimental/life2011/life_stage_2/stamp.h"

namespace life {
// The main object that runs Conway's Life simulation (for details, see:
// http://en.wikipedia.org/wiki/Conway's_Game_of_Life).
class Life {
 public:
  // The possible simulation modes.  Modes with "Run" in their name will cause
  // the simulation thread to start running if it was paused.
  enum SimulationMode {
    kRunRandomSeed,
    kRunStamp,
    kPaused
  };

  Life();
  virtual ~Life();

  // Run a single tick of the simulation.
  void LifeSimulation();

  // Set the automaton rules.  The rules are expressed as a string, with the
  // Birth and Keep Alive rules separated by a '/'.  The format follows the .LIF
  // 1.05 format here: http://psoup.math.wisc.edu/mcell/ca_files_formats.html
  // Survival/Birth.
  void SetAutomatonRules(const std::string& rule_string);

  // Resize the simulation to |width|, |height|.  This will delete and
  // reallocate all necessary buffer to the new size, and set all the
  // buffers to a new initial state.
  void Resize(int width, int height);

  // Delete all the cell buffers.  Sets the buffers to NULL.
  void DeleteCells();

  // Clear out the cell buffers (reset to all-dead).
  void ClearCells();

  // Stamp |stamp| at point |point| in both the pixel and cell buffers.
  void PutStampAtPoint(const Stamp& stamp, const pp::Point& point);

  // Stop the simulation.  Does nothing if the simulation is stopped.
  void StopSimulation();

  SimulationMode simulation_mode() const {
    return simulation_mode_;
  }
  void set_simulation_mode(SimulationMode new_mode) {
    simulation_mode_ = new_mode;
  }

  int width() const {
    return width_;
  }
  int height() const {
    return height_;
  }

  void set_pixel_buffer(
      const std::tr1::shared_ptr<pp::ImageData>& pixel_buffer) {
    shared_pixel_buffer_ = pixel_buffer;
  }

 private:
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

  // Take each character in |rule_string| and convert it into an index value,
  // set the bit in |life_rules_table_| at each of these indices, applying
  // |rule_offset|.  Assumes that all necessary locks have been acquired.  Does
  // no range checking or validation of the strings.
  void SetRuleFromString(size_t rule_offset,
                         const std::string& rule_string);

  // Add in some random noise to the borders of the simulation, which is used
  // to determine the life of adjacent cells.  This is part of a simulation
  // tick.
  void AddRandomSeed();

  // Draw the current state of the simulation into the pixel buffer.
  void UpdateCells();

  // Swap the input and output cell arrays.
  void Swap();

  std::tr1::shared_ptr<pp::ImageData> shared_pixel_buffer_;

  // Simulation variables.
  SimulationMode simulation_mode_;
  bool simulation_running_;
  int width_;
  int height_;
  RandomBitGenerator random_bits_;
  std::vector<uint8_t> life_rules_table_;
  uint8_t* cell_in_;
  uint8_t* cell_out_;
};

}  // namespace life

#endif  // LIFE_H_

