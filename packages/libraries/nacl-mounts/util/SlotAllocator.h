/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_UTIL_SLOTALLOCATOR_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_UTIL_SLOTALLOCATOR_H_

#include <stdint.h>
#include <algorithm>
#include <vector>
#include "macros.h"

// The slot allocator class is a memory management tool.
// This class allocates memory for the templated class
// and uses a slot index to direct the user to that
// memory.
template <class T>
class SlotAllocator {
 public:
  SlotAllocator() {}
  // The destructor loops through each slot.  If the slot
  // contains an object, that object is deleted (freeing
  // the memory).
  virtual ~SlotAllocator();

  // Alloc() allocates memory for an object of type T
  // and returns the slot index in this SlotAllocator
  // that corresponds to that memory.
  int Alloc();

  // Free() frees the memory in the given slot.  If
  // no memory has been allocated to the slot, this
  // method does nothing.
  void Free(int slot);

  // At() returns the pointer to the allocated memory
  // at the given slot.  At() returns NULL if:
  // (1) the slot is out of range
  // (2) no memory has been allocated at slot
  T *At(int slot);

 private:
  std::vector<T*> slots_;
  std::vector<int> heap_;

  static bool comp(int i, int j) { return i > j; }

  DISALLOW_COPY_AND_ASSIGN(SlotAllocator);
};

// template implementations
template <class T>
SlotAllocator<T>::~SlotAllocator() {
  for (uint32_t i = 0; i < slots_.size(); ++i) {
    if (slots_[i]) {
      delete slots_[i];
      slots_[i] = NULL;
    }
  }
}

template <class T>
int SlotAllocator<T>::Alloc() {
  if (heap_.size() == 0) {
    slots_.push_back(new T);
    return slots_.size()-1;
  }
  int index = heap_.front();
  std::pop_heap(heap_.begin(), heap_.end(), comp);
  heap_.pop_back();
  slots_[index] = new T;
  return index;
}

template <class T>
void SlotAllocator<T>::Free(int slot) {
  if (slot < 0 ||
      static_cast<uint32_t>(slot) >= slots_.size() ||
      !slots_[slot]) {
    return;
  }
  delete slots_[slot];
  slots_[slot] = NULL;
  heap_.push_back(slot);
  std::push_heap(heap_.begin(), heap_.end(), comp);
}

template <class T>
T *SlotAllocator<T>::At(int slot) {
  if (slot < 0 || static_cast<uint32_t>(slot) >= slots_.size()) {
    return NULL;
  }
  return slots_[slot];
}

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_UTIL_SLOTALLOCATOR_H_
