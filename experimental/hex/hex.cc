// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

/// @file
/// This example demonstrates loading, running and scripting a very simple NaCl
/// module.  To load the NaCl module, the browser first looks for the
/// CreateModule() factory method (at the end of this file).  It calls
/// CreateModule() once to load the module code from your .nexe.  After the
/// .nexe code is loaded, CreateModule() is not called again.
///
/// Once the .nexe code is loaded, the browser then calls the
/// HelloWorldModule::CreateInstance()
/// method on the object returned by CreateModule().  It calls CreateInstance()
/// each time it encounters an <embed> tag that references your NaCl module.
///
/// When the browser encounters JavaScript that references your NaCl module, it
/// calls the GetInstanceObject() method on the object returned from
/// CreateInstance().  In this example, the returned object is a subclass of
/// ScriptableObject, which handles the scripting support.

#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include <algorithm>  // for reverse
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <iterator>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

namespace {
/// method name for ReverseText, as seen by JavaScript code.
const char* const kReverseTextMethodId = "reverseText";

/// method name for FortyTwo, as seen by Javascript code.
const char* const kProcessArrayMethodId = "processArray";

/// method name for FortyTwo, as seen by Javascript code.
const char* const kProcessIntArrayMethodId = "processIntArray";

/// method name for FortyTwo, as seen by Javascript code.
const char* const kProcessStringMethodId = "processString";


/// Use @a delims to identify all the elements in @ the_string, and add
/// Invoke the function associated with @a method.  The argument list passed
/// via JavaScript is marshaled into a vector of pp::Vars.  None of the
/// functions in this example take arguments, so this vector is always empty.
/// these elements to the end of @a the_data.  Return how many elements
/// were found.
/// @param the_string [in] A string containing the data to be parsed.
/// @param delims [in] A string containing the characters used as delimiters.
/// @param the_data [out] A vector of strings to which the elements are added.
/// @return The number of elements added to @ the_data.
int GetElementsFromString(std::string the_string, std::string delims,
                      std::vector<std::string>& the_data) {
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
      the_data.push_back(the_element);
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

void RemoveTrailingSpaces(std::string* str)
{
  int pos = str->length() - 1;
  while( pos > 0 && isspace((*str)[pos]) ) {
    str->erase(pos);
    --pos;
  }
}

struct Coord {
  int x_, y_;
  Coord() : x_(0), y_(0) {}
  Coord(int x, int y) : x_(x), y_(y) {}

  bool operator == (const Coord& rhs) const {
    return (x_ == rhs.x_ && y_ == rhs.y_);
  }
  bool operator < (const Coord& rhs) const {
    return (x_ < rhs.x_ ||
            (x_ == rhs.x_ && y_ < rhs.y_));
  }
  std::string toString() {
    std::ostringstream ss;
    ss << x_ << ":" << y_;
    return ss.str();
  }
};
std::ostream& operator<< (std::ostream& os, const Coord& c) {
  os << c.x_ << "," << c.y_ << " ";
  return os;
}

class CombatResultsTable {
  private:
    static CombatResultsTable* singleton_;
  public:
    static int getD6() {
      static bool init = false;
      if (!init) {
        srand((unsigned)time(NULL));
      }
      return rand() % 6 + 1; //value 1...6
    }
    static CombatResultsTable* CRT();
    static std::string GetResult(int attack_str, int defense_str) {
      int attack_ratio, defense_ratio;
      if (attack_str < defense_str) {
        attack_ratio = 1;
        defense_ratio = defense_str / attack_str;
        // if there is a remainder, increase defense_str
        if (defense_str % attack_str != 0) {
          defense_str++;
        }
      } else if (attack_str >= defense_str) {
        defense_ratio = 1;
        attack_ratio = attack_str / defense_str;
      }
      printf(" attack_str=%d defense_str=%d  %d:%d\n",
             attack_str, defense_str, attack_ratio, defense_ratio);
      std::string results_[] = {
        "AE", "AE", "AE", "AE", "AE", "AE",
        // results_[6] is the low end of 1:1
        "AE", "AR", "EX", "EX", "DR", "DR",
        "DR", "DE", "DE", "DE", "DE", "DE",
        "DE", "DE", "DE", "DE", "DE", "DE"
       };
       int start_index = 6;
       start_index += (attack_ratio - defense_ratio);
       if (start_index < 0)
         start_index = 0;
       if (start_index > 18)
         start_index = 18;
       printf("CHART :");
       for (int i=0; i<6; ++i) {
         printf(" %s ", results_[start_index+i].c_str());
       }
       printf("\n");
       int final_index = start_index + CombatResultsTable::getD6() - 1;
       printf(" start_index=%d final_index=%d\n", start_index, final_index);
       return "DR";  //FIXME
       // return results_[final_index];
    }
};
CombatResultsTable* CombatResultsTable::singleton_ = NULL;
CombatResultsTable* CombatResultsTable::CRT() {
  if (!singleton_) {
    singleton_ = new CombatResultsTable();
  }
  return singleton_;
}

class Hex {
  public:  
    virtual int getMoveCost() const {return 1;}
    virtual int getDefenseMultiplier() const { return 1;}
    virtual std::string getName() const = 0;
    virtual int getType() const = 0;
};
class ClearHex : public Hex {
  public:
    std::string getName() const { return "ClearHex";}
    int getType() const { return 0;}
};
class ForestHex : public Hex {
  public:
    std::string getName() const { return "ForestHex";}
    int getType() const { return 1;}
    int getMoveCost() const {return 2;}
    int getDefenseMultiplier() const { return 2;}
};
class DesertHex : public Hex {
  public:
    std::string getName() const { return "DesertHex";}
    int getType() const { return 2;}
};
class HillHex : public Hex {
  public:
    std::string getName() const { return "HillHex";}
    int getType() const { return 3;}
    int getMoveCost() const {return 2;}
    int getDefenseMultiplier() const { return 2;}
};
class MountainHex : public Hex {
  public:
    std::string getName() const { return "MountainHex";}
    int getType() const { return 4;}
    int getMoveCost() const {return 3;}
    int getDefenseMultiplier() const { return 3;}
};
class SeaHex : public Hex {
  public:
    std::string getName() const { return "SeaHex";}
    int getType() const { return 5;}
    int getMoveCost() const {return 99;}
};
class CityHex : public Hex {
  public:
    std::string getName() const { return "CityHex";}
    int getType() const { return 6;}
    int getDefenseMultiplier() const { return 2;}
};
class ImpassableHex : public Hex {
  public:
    std::string getName() const { return "ImpassableHex"; }
    int getType() const { return 7;}
    int getMoveCost() const {return 999;}
};

class Board {
  public:
    Board(int columns, int rows);
    enum HexType{CLEAR=0, FOREST, DESERT, HILL, MOUNTAIN, SEA, CITY, IMPASSABLE};
    virtual ~Board() {delete [] hexData_;}
    HexType get(int c, int r);
    void set(int c, int r, HexType h);
    int getColumns() const { return columns_;}
    int getRows() const { return rows_;} 

    int getMoveCost(int c, int r);
    int getDefenseValue(int c, int r);
  private:
    HexType *hexData_;
    int columns_;
    int rows_;
    unsigned int totalSize_;

    ClearHex clearHex_;
    ForestHex forestHex_;
    DesertHex desertHex_;
    HillHex hillHex_;
    MountainHex mountainHex_;
    SeaHex seaHex_;
    CityHex cityHex_;
    ImpassableHex impassableHex_;
    // Hex *hexPtr_[]; // array of pointers to a const object
    Hex **hexPtr_; // array of pointers to a const object
};
Board *theBoard = NULL;

// For a given hex, we 6 adjacent hexes:
//   1 above, 1 below, 2 right and 2 left.
int GetAdjacent(int c, int r, std::vector<Coord>* adjacent_coords) {
  // straight above
  if (r > 0)
    adjacent_coords->push_back( Coord(c, r-1) );

  // straight below
  if (r < theBoard->getRows()-1 )
    adjacent_coords->push_back( Coord(c, r+1));

  // check left
  if (c > 0) {
    // left, same height
    adjacent_coords->push_back( Coord(c-1, r) );
    if (c%2==1) {
      // left and down
      if (r < theBoard->getRows()-1) {
        adjacent_coords->push_back( Coord(c-1, r+1) );
      }
    } else {
      if (r > 0) {
        adjacent_coords->push_back( Coord(c-1, r-1) );
      }
    }
  }

  // check right
  if (c < theBoard->getColumns()-1) {
    // right, same height
    adjacent_coords->push_back( Coord(c+1, r) );
    // right and down
    if (c%2==1) {
      if (r < theBoard->getRows()-1) {
        adjacent_coords->push_back( Coord(c+1, r+1) );
      } 
    } else {
      if (r > 0) {
        adjacent_coords->push_back( Coord(c+1, r-1) );
      } 
    }
  }
  return adjacent_coords->size();
}




class Unit {
  public:
    virtual int Index() const {return index_;}
    virtual int Attack() const {return attack_;}
    virtual int Move() const {return move_;}
    virtual int HexX() const {return hexX_;}
    virtual int HexY() const {return hexY_;}
    virtual void SetHexX(int x) { hexX_ = x;}
    virtual void SetHexY(int y) { hexY_ = y;}
    virtual std::string LocationString() const;
    virtual std::string Type() = 0;
    virtual std::string Side() {return side_;}
    // Unit() {}
    Unit(int idx, int x, int y, int attack, int move, std::string side) :
        index_(idx), hexX_(x), hexY_(y), attack_(attack), move_(move),
        side_(side) {}
    virtual ~Unit() {}
    static Unit* createUnit(int idx, int x, int y,
                            int attack, int move, std::string unit_type, std::string size);
  private:
    int index_;
    int hexX_;
    int hexY_;
    int attack_;
    int move_;
    std::string side_;
};
std::string Unit::LocationString() const {
  std::ostringstream val_ss;
  val_ss << " " << hexX_ << "," << hexY_;
  return val_ss.str();
}

class ArmoredUnit : public Unit {
  public:
    // ArmoredUnit() :  Unit() {}
    ArmoredUnit(int idx, int x, int y, int attack, int move, std::string side) :
        Unit(idx, x, y, attack, move, side) {}
    std::string Type() {return "ARM";}
};

class InfantryUnit : public Unit {
  public:
    // InfantryUnit() :  Unit() {}
    InfantryUnit(int idx, int x, int y, int attack, int move, std::string side) :
        Unit(idx, x, y, attack, move, side) {}
    std::string Type() {return "INF";}
};


class UnitManager {
  public:
    static UnitManager* GetUnitManager(); 
    void AddUnit(int index, Unit* u);
    Unit* GetUnit(int index) {
      std::map<int, Unit*>::iterator it = unitMap_.find(index);
      if (it == unitMap_.end()) {
        printf("Did not find index %d in unit map\n", index);
        return NULL; 
      }
      return (*it).second;
    }
    void RemoveUnit(int index) {
      std::map<int, Unit*>::iterator it = unitMap_.find(index);
      if (it == unitMap_.end()) {
        printf("Did not find index %d in unit map\n", index);
      } else {
        Unit *u = (*it).second;
        delete u;
        unitMap_.erase(it);
        return;
      }
    }
    // Return Unit* for all units @ x:y
    int GetUnitInXY(int x, int y, std::vector<Unit*> *unit_vec);

    // Return Unit* for all units adjacent to x:y
    int GetUnitAdjToXY(int x, int y, std::string side,
                       std::vector<Unit*> *unit_vec);
  private:
    static UnitManager* unitMgrSingleton_;
    UnitManager() {}
    std::map<int, Unit*> unitMap_;
};

void UnitManager::AddUnit(int index, Unit* u) {
  if (unitMap_[index]) {
    printf("Deleting unit at index %d\n", index);
    delete unitMap_[index];
  }
  printf("Added unit for idx %d\n", index);
  unitMap_[index] = u;
}

UnitManager* UnitManager::unitMgrSingleton_ = NULL;
UnitManager* UnitManager::GetUnitManager() {
  if (!unitMgrSingleton_) {
    unitMgrSingleton_ = new UnitManager();
  }
  return unitMgrSingleton_;
}

int UnitManager::GetUnitInXY(int x, int y, std::vector<Unit*> *unit_vec) {
  static bool printed = false;
  for (std::map<int, Unit*>::iterator it = unitMap_.begin();
       it != unitMap_.end(); ++it) {
    Unit *u = (*it).second;
    // printf("Unit %d  %d:%d\n", u->Index(), u->HexX(), u->HexY());
    if (u->HexX()==x && u->HexY()==y) {
      unit_vec->push_back(u);
    }
  }
  printed = true;
  return unit_vec->size();
}

// if side is passed in, then return units adjacent to x:y
// that do *NOT* match side -- i.e. are enemy units
int UnitManager::GetUnitAdjToXY(int x, int y, std::string side,
                                std::vector<Unit*> *unit_vec) {
  std::vector< Coord > adjCoord;
  GetAdjacent(x,y, &adjCoord);
  for (std::map<int, Unit*>::iterator it = unitMap_.begin();
       it != unitMap_.end(); ++it) {
    Unit *u = (*it).second;
    // Check if the unit |u| is in any of the adjacent hexes.
    for (std::vector<Coord>::iterator coord_iter = adjCoord.begin();
         coord_iter != adjCoord.end(); ++coord_iter) {
      int coord_x = (*coord_iter).x_;
      int coord_y = (*coord_iter).y_;
      if (u->HexX()==coord_x && u->HexY()==coord_y) {
        // if side is an empty string, or if side does NOT match
        // then we've found an adjacent unit we care about
        if(side.empty() || side != u->Side()) {
          unit_vec->push_back(u);
        }
      }
    }
  }
  return unit_vec->size();
}

Unit* Unit::createUnit(int idx, int x, int y,
                       int attack, int move, std::string unit_type,
                       std::string side) {
  if (unit_type=="ARM") {
    return new ArmoredUnit(idx, x, y, attack, move, side);
  } else if (unit_type=="INF") {
    return new InfantryUnit(idx, x, y, attack, move, side);
  } else {
    printf("ERROR: unit_type=%s\n", unit_type.c_str());
    return NULL;
  }
}


/// This is the module's function that does the work to compute the value 42.
/// The ScriptableObject that called this function then returns the result back
/// to the browser as a JavaScript value.
int32_t FortyTwo() {
  return 42;
}

std::string ComputeUsingString(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be a string
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    return "Arg from Javascript is not a string!";
  }

  pp::Var exception;  // Use initial "void" Var for exception
  pp::Var arg0 = args[0];
  std::string arg_string = arg0.AsString();

  std::ostringstream val_ss;

  std::istringstream arg_ss(arg_string);
  std::vector<std::string> words;
  copy(std::istream_iterator<std::string>(arg_ss),
       std::istream_iterator<std::string>(),
       std::back_inserter<std::vector<std::string> >(words));
  double sum = 0.0;
  for (std::vector<std::string>::iterator iter = words.begin();
       iter != words.end(); ++iter) {
      std::string a_word = *iter;
      int a_number = atoi(a_word.c_str());
      sum += a_number;
  }
  val_ss << sum;
  return val_ss.str();
}

// Called by Javascript -- this is a static method that is passed a javascript
// array containing doubles.  This method asks the array for its length, then
// asks for the indices (0...|length|-1), converting each to a double.
std::string ComputeUsingIntArray(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  if (!args[0].is_object()) {
    return "Arg from Javascript is not an object!";
  }

  pp::Var exception;  // Use initial "void" Var for exception
  pp::Var arg0 = args[0];
  pp::Var var_length = arg0.GetProperty("length", &exception);

  std::ostringstream val_ss;
  int length = var_length.AsInt();
  int sum = 0;
  // Fill the initial_matrix with values from the JS array object
  for (int i = 0; i < length; ++i) {
    std::ostringstream oss;
    oss << i;

    bool has_prop = arg0.HasProperty(oss.str(), &exception);
    if (has_prop) {
      pp::Var indexVar = arg0.GetProperty(oss.str(), &exception);
      double value = 0;
      if (indexVar.is_double()) {
        value = indexVar.AsDouble();
      } else {
        val_ss << " error converting arg " << i;
        val_ss << " is_int: " << indexVar.is_int()
               << " is_double: " << indexVar.is_double();
      }
      sum += static_cast<int>(value);
    }
  }
  val_ss << sum;
  return val_ss.str();
}

// Called by Javascript -- this is a static method that is passed a javascript
// array containing doubles.  This method asks the array for its length, then
// asks for the indices (0...|length|-1), converting each to a double.
std::string ComputeUsingArray(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  if (!args[0].is_object()) {
    return "Arg from Javascript is not an object!";
  }

  pp::Var exception;  // Use initial "void" Var for exception
  pp::Var arg0 = args[0];
  pp::Var var_length = arg0.GetProperty("length", &exception);

  int length = var_length.AsInt();
  double sum = 0.0;
  std::ostringstream val_ss;

  // Fill the initial_matrix with values from the JS array object
  for (int i = 0; i < length; ++i) {
    std::ostringstream oss;
    oss << i;

    bool has_prop = arg0.HasProperty(oss.str(), &exception);
    if (has_prop) {
      pp::Var indexVar = arg0.GetProperty(oss.str(), &exception);
      double value = 0;
      if (indexVar.is_double()) {
        value = indexVar.AsDouble();
      }
      sum += value;
    }
  }
  val_ss << sum;
  return val_ss.str();
}

/// This function is passed the arg list from the JavaScript call to
/// @a reverseText.
/// It makes sure that there is one argument and that it is a string, returning
/// an error message if it is not.
/// On good input, it reverses the string and returns a message with the
/// original string and the reversed string.  The ScriptableObject that called
/// this function returns this string back to the browser as a JavaScript value.
std::string ReverseText(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    printf("Unexpected number of args\n");
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    printf("Arg %s is NOT a string\n", args[0].DebugString().c_str());
    return "Arg from Javascript is not a string!";
  }

  std::string str_arg = args[0].AsString();
  // std::string message = "Passed in: '" + str_arg + "'";
  // use reverse to reverse |str_arg| in place
  reverse(str_arg.begin(), str_arg.end());
  // std::sring message = " reversed: '" + str_arg + "'";
  // return message;
  return str_arg;
}
}  // namespace

/// This class exposes the scripting interface for this NaCl module.  The
/// HasMethod() method is called by the browser when executing a method call on
/// the @a helloWorldModule object (see the reverseText() function in
/// hello_world.html).  The name of the JavaScript function (e.g. "fortyTwo") is
/// passed in the @a method parameter as a string pp::Var.  If HasMethod()
/// returns @a true, then the browser will call the Call() method to actually
/// invoke the method.
class HelloWorldScriptableObject : public pp::deprecated::ScriptableObject {
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

bool HelloWorldScriptableObject::HasMethod(const pp::Var& method,
                                           pp::Var* /* exception */) {
  if (!method.is_string()) {
    return false;
  }
  std::string method_name = method.AsString();
  bool has_method = method_name == "postToNexe";
  return has_method;
}


Board::Board(int columns, int rows) : hexData_(NULL), columns_(columns),
             rows_(rows) {
  totalSize_ = columns_ * rows_;
  hexData_ = new HexType[totalSize_];
  hexPtr_ = new Hex*[totalSize_];
  for (unsigned int i=0; i < totalSize_; ++i) {
    hexData_[i] = CLEAR;
    hexPtr_[i]  = NULL;
  }
}

int Board::getDefenseValue(int c, int r) {
  unsigned int index = c * rows_ + r;
  assert(index < totalSize_);
  return hexPtr_[index]->getDefenseMultiplier();
}

int Board::getMoveCost(int c, int r) {
  unsigned int index = c * rows_ + r;
  assert(index < totalSize_);
  return hexPtr_[index]->getMoveCost();
}

Board::HexType Board::get(int c, int r) {
  unsigned int index = c * rows_ + r;
  assert(index < totalSize_);
  return hexData_[index];
}
void Board::set(int c, int r, Board::HexType h) {
  unsigned int index = c * rows_ + r;
  if (index >= totalSize_) {
    printf("c=%d r=%d columns_=%d rows_=%d totalSize_=%d\n",
           c, r, columns_, rows_, totalSize_);
  }
  assert(index < totalSize_);
  hexData_[index] = h;
  // enum HexType{CLEAR=0, FOREST, DESERT, HILL, MOUNTAIN, SEA, CITY, IMPASSABLE};
  switch(h) {
    case CLEAR:
      hexPtr_[index] = &clearHex_;
      break;
    case FOREST:
      hexPtr_[index] = &forestHex_;
      break;
    case DESERT:
      hexPtr_[index] = &desertHex_;
      break;
    case HILL:
      hexPtr_[index] = &hillHex_;
      break;
    case MOUNTAIN:
      hexPtr_[index] = &mountainHex_;
      break;
    case SEA:
      hexPtr_[index] = &seaHex_;
      break;
    case CITY:
      hexPtr_[index] = &cityHex_;
      break;
    case IMPASSABLE:
      hexPtr_[index] = &impassableHex_;
      break;
    default:
      printf("Unhandled hex type %d\n", h);
      // assert(0);
      break;
  }
}


bool find_debug = false;
// 
// Find legal moves recursively -- this allows moving into/through friendly
// units but NOT through enemy units...
// We can move INTO an enemy ZOC but would stop there.  
// We cannot move INTO enemy ZOC if we are moving from enemy ZOC
// 
void FindMoves(int c, int r, Unit* the_unit, int moveLeft,
               std::set<Coord>& coordSet) {
  std::vector< Coord> adjCoords;
  GetAdjacent(c, r, &adjCoords);

  if(find_debug) printf("Find Moves:: at %d:%d, m=%d\n", c, r, moveLeft);

  // For the hex we are CURRENTLY in, see if there are enemy units adjacent
  std::vector<Unit*> enemy_units_adjacent_to_cr;
  int num_enemy_adjacent_to_cr = UnitManager::GetUnitManager()->GetUnitAdjToXY(
      c, r, the_unit->Side(), &enemy_units_adjacent_to_cr);
  bool current_hex_adjacent_to_enemy = (num_enemy_adjacent_to_cr > 0);
  if(find_debug) printf(" current_hex_is_adjacent %d   %d:%d\n", current_hex_adjacent_to_enemy,
         c,r);

  for (std::vector<Coord>::iterator iter = adjCoords.begin();
       iter != adjCoords.end(); ++iter) {
    Coord coord = *iter;
    int coordMoveCost = theBoard->getMoveCost(coord.x_, coord.y_);
    std::vector<Unit*> units_in_hex;
    int num_units_in_hex = UnitManager::GetUnitManager()->GetUnitInXY(
        coord.x_, coord.y_, &units_in_hex);

    bool enemy_unit_in_hex = false;
    bool friendly_unit_in_hex = false;
    if (num_units_in_hex > 0) {
      for (std::vector<Unit*>::iterator ui = units_in_hex.begin();
           ui != units_in_hex.end(); ++ui) {
        Unit *u = *ui;
        if(u->Side() != the_unit->Side())
          enemy_unit_in_hex = true;
        else
          friendly_unit_in_hex = true;
      }
    }

    // For the hex we want to move TO, see if there are enemy units adjacent
    bool enemy_unit_adjacent = false;
    std::vector<Unit*> enemy_units_adjacent;
    int num_enemy_adjacent = UnitManager::GetUnitManager()->GetUnitAdjToXY(
        coord.x_, coord.y_, the_unit->Side(), &enemy_units_adjacent);
    if (num_enemy_adjacent>0) {
      enemy_unit_adjacent = true; 
    }

    int move_left_after_move = moveLeft - coordMoveCost;

    if(find_debug) printf("  From %d:%d moveLeft=%d Consider x=%d y=%d num_units=%d enemy_unit_in_hex %d enemy_unit_adjacent %d current_hex_adjacent_to_enemy %d move_left_after_move=%d\n", 
           c, r, moveLeft, coord.x_, coord.y_, num_units_in_hex, enemy_unit_in_hex, enemy_unit_adjacent, current_hex_adjacent_to_enemy, move_left_after_move);


    if (move_left_after_move >= 0 &&
        !enemy_unit_in_hex && !enemy_unit_adjacent
       ) {

      if (move_left_after_move==0 && friendly_unit_in_hex) {
        if(find_debug) printf("CANNOT end in friendly unit at %d:%d from %d:%d\n",
                coord.x_, coord.y_, c, r);
      } else {
        coordSet.insert(coord);
      }
      // FIXME -- have to track |moveLeft - coordMoveCost|
      // with each coordinate...
      if(find_debug) printf("Going to %d:%d from %d:%d\n",coord.x_, coord.y_, c, r);
      FindMoves(coord.x_, coord.y_, the_unit,
                moveLeft - coordMoveCost, coordSet);
    }

    // if a hex is empty but is ADJACENT to an enemy, then we
    // can enter...but not continue...but only if we are NOT already
    // in an adjacent hex
    if (moveLeft >= coordMoveCost
        && !enemy_unit_in_hex && enemy_unit_adjacent
        && !current_hex_adjacent_to_enemy) {

      if (move_left_after_move==0 && friendly_unit_in_hex) {
        if(find_debug) printf("CANNOT end in friendly unit at %d:%d from %d:%d\n",
                coord.x_, coord.y_, c, r);
      } else {
        coordSet.insert(coord);
      }
      if(find_debug) printf("STOPPING at %d:%d from %d:%d\n",coord.x_, coord.y_, c, r);
    }

    // if we are IN a ZOC and an adjacent hex is empty but has enemy ZOC
    // then we cannot move there
    if (moveLeft >= coordMoveCost
        && !enemy_unit_in_hex && enemy_unit_adjacent
        && current_hex_adjacent_to_enemy) {
      if(find_debug) printf("COULD NOT MOVE from %d:%d to %d:%d -- ZOC\n",
          c, r, coord.x_, coord.y_);
    }
    if (moveLeft >= coordMoveCost && enemy_unit_in_hex) {
      if(find_debug) printf("COULD NOT MOVE from %d:%d to %d:%d -- ENEMY OCCUPIED\n",
          c, r, coord.x_, coord.y_);
    }
    
  }
}

std::string ResolveAttack(const std::vector<pp::Var>& args) {
  if (args.size() != 1) {
    return "ResolveAttack: Unexpected number of args";
  }
  std::string arg0 = args[0].AsString();
  std::vector<std::string> unitIds;
  int defender_id = -1;
  std::vector<int> attacker_ids; 
  GetElementsFromString(arg0, std::string(" "), unitIds);
  for (unsigned int i = 0; i < unitIds.size(); ++i) {
    std::string word = unitIds[i];
    printf(" i=%d  word={%s}\n", i, word.c_str());
    // element 0 is RESOLVE_ATTACK, element 1 is attacked id
    if (i > 1) {
      attacker_ids.push_back(atoi(unitIds[i].c_str()));
    }
  }
  defender_id = atoi(unitIds[1].c_str());
  Unit *defender = UnitManager::GetUnitManager()->GetUnit(defender_id);
  if (!defender) {
    return std::string("Defender ") + unitIds[1] + " not found";
  }
  int x = defender->HexX();
  int y = defender->HexY();
  int unit_defense = defender->Attack();
  int defense_strength = unit_defense *
    theBoard->getDefenseValue(x, y);
  printf(" def_id=%d x=%d y=%d unit_def=%d defense=%d\n",
         defender_id, x, y, unit_defense, defense_strength);
  int attack_strength = 0;
  for (std::vector<int>::iterator attack_iter = attacker_ids.begin();
       attack_iter != attacker_ids.end(); ++attack_iter) {
    int attacker_id = *attack_iter;
    Unit *attacker = UnitManager::GetUnitManager()->GetUnit(attacker_id);
    if (!attacker) {
      printf(" attacker_id=%d not found!\n", attacker_id);
      return "Attacker not found";
    }
    attack_strength += attacker->Attack();
  }
  printf("Attack %d defense %d\n", attack_strength, defense_strength);
  std::string result = CombatResultsTable::GetResult(attack_strength,
      defense_strength);

  std::vector<Coord> retreat_hexes;
  if (result == "DR") {
    // find the spaces the defender could retreat into...
    std::vector<Coord> adjacent_hexes;
    GetAdjacent(x,y, &adjacent_hexes);

    std::vector<Unit*> unit_vector;
    for (std::vector<Coord>::iterator coord_iter = adjacent_hexes.begin();
         coord_iter != adjacent_hexes.end(); ++coord_iter) {
      Coord c = *coord_iter; 
      unit_vector.clear();
      int units_in_coord = UnitManager::GetUnitManager()->GetUnitInXY(
          c.x_, c.y_, &unit_vector);
      if (units_in_coord == 0) {
        // Return Unit* for all units adjacent to x:y
        int num_adjacent = UnitManager::GetUnitManager()->GetUnitAdjToXY(
            c.x_, c.y_, defender->Side(), &unit_vector);
        if (num_adjacent==0) {
          // then we found a space that contains NO units and is 
          // NOT adjacent to any enemies
          retreat_hexes.push_back(c);
        }
      }
    } // end for loop
  }
  else if (result == "AR") {
    // for each attacking unit, find spaces it could retreat into...
  }

  // START HERE
  // if this is a retreat add retreat hexes
  if (result=="DR" || result=="AR") {
    result += " , ";
    for (std::vector<Coord>::iterator coord_iter = retreat_hexes.begin();
         coord_iter != retreat_hexes.end(); ++coord_iter) {
      result += (*coord_iter).toString() + " , ";
    }
  }
  return result;
}

std::string GetAttacks(const std::vector<pp::Var>& args) {
  std::string validAttacks = "";
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  std::string arg0 = args[0].AsString();
  std::istringstream arg_ss(arg0);
  std::vector<std::string> words;

  copy(std::istream_iterator<std::string>(arg_ss),
       std::istream_iterator<std::string>(),
       std::back_inserter<std::vector<std::string> >(words));

  // note words[0] will be GET_MOVES
  int id = atoi(words[1].c_str());
  int x = atoi(words[2].c_str());
  int y = atoi(words[3].c_str());
  printf("Getting attacks for id=%d @ %d:%d\n", id, x, y);

  std::vector<Unit*> enemy_units_adjacent_to_cr;
  Unit *the_unit = UnitManager::GetUnitManager()->GetUnit(id);
  int num_enemy_adjacent_to_cr = UnitManager::GetUnitManager()->GetUnitAdjToXY(
      x, y, the_unit->Side(), &enemy_units_adjacent_to_cr);

  printf("Num enemies = %d\n", num_enemy_adjacent_to_cr);
/*
  for (std::vector<Unit*>::iterator vi = enemy_units_adjacent_to_cr.begin();
       vi != enemy_units_adjacent_to_cr.end(); ++vi) {
    validAttacks += (*vi)->LocationString() + ";";
  }
*/
  for (int i = 0; i < num_enemy_adjacent_to_cr; ++i) {
    Unit *u = enemy_units_adjacent_to_cr[i];
    validAttacks += u->LocationString();
    if (i < num_enemy_adjacent_to_cr-1)
      validAttacks += ";"; 
  }
  printf ("RETURNING %s\n", validAttacks.c_str());
  return validAttacks;
}

std::string GetMoves(const std::vector<pp::Var>& args) {
  std::string validMoves = "";

  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  std::string arg0 = args[0].AsString();
  std::istringstream arg_ss(arg0);
  std::vector<std::string> words;

  copy(std::istream_iterator<std::string>(arg_ss),
       std::istream_iterator<std::string>(),
       std::back_inserter<std::vector<std::string> >(words));

  // note words[0] will be GET_MOVES
  int id = atoi(words[1].c_str());
  int x = atoi(words[2].c_str());
  int y = atoi(words[3].c_str());

  std::vector<Coord> adjacent_hexes;
  GetAdjacent(x,y, &adjacent_hexes);
  std::ostringstream dbg_ss;
  printf("GetMoves id=%d x=%d y=%d\n", id, x, y);

  Unit *selected_unit = UnitManager::GetUnitManager()->GetUnit(id);
  if (!selected_unit) {
    return "ERROR:  Did not find unit\n";
  }
  std::copy(adjacent_hexes.begin(), adjacent_hexes.end(),
            std::ostream_iterator<Coord>(dbg_ss));
  printf("++++++  ADJACENT: %s\n", dbg_ss.str().c_str());

  std::ostringstream val_ss;
  std::set<Coord> coordSet;
  std::set<Coord> prunedCoordSet;
  coordSet.insert( Coord(x,y));
  FindMoves(x, y, selected_unit, selected_unit->Move(), coordSet); 

  // For now, PRUNE moves that contain a friendly unit ... since we
  // can move through them but not stop on them
  for (std::set<Coord>::iterator ci = coordSet.begin();
       ci != coordSet.end(); ++ci) {

    Coord a_coord = *ci;
    std::vector<Unit*> units_in_hex;
    int num_units_in_hex = UnitManager::GetUnitManager()->GetUnitInXY(
        a_coord.x_, a_coord.y_, &units_in_hex);
    if(num_units_in_hex==0) {
      if(find_debug) printf("Added %d:%d to pruned set\n", a_coord.x_, a_coord.y_);
      prunedCoordSet.insert(a_coord);
    } else {
      if(find_debug) printf("Did not add %d:%d to pruned set\n", a_coord.x_, a_coord.y_);
    }
  }

  std::copy(prunedCoordSet.begin(), prunedCoordSet.end(),
       std::ostream_iterator<Coord>(val_ss));

  validMoves = val_ss.str();  
  return validMoves;
}

std::string UpdateUnitLocation(const std::vector<pp::Var>& args) {
  std::string arg0 = args[0].AsString();
  std::vector<std::string> words;
  GetElementsFromString(arg0, std::string(" "), words);
  if (words.size() <= 3) {
    printf("Words vector should be > 3 {%s}\n", arg0.c_str());
    return "ERROR";
  }
  int id = atoi(words[1].c_str());
  int new_x = atoi(words[2].c_str());
  int new_y = atoi(words[3].c_str());
  UnitManager *um = UnitManager::GetUnitManager();
  Unit *u = um->GetUnit(id);
  u->SetHexX(new_x);
  u->SetHexY(new_y);
  return "SUCCESS";
}

std::string UpdateDestroyed(const std::vector<pp::Var>& args) {
  std::string arg0 = args[0].AsString();
  std::vector<std::string> words;
  GetElementsFromString(arg0, std::string(" "), words);
  if (words.size() <= 1) {
    printf("Words vector should be > 1 {%s}\n", arg0.c_str());
    return "ERROR";
  }
  printf("Word [%s] [%s]\n", words[0].c_str(), words[1].c_str());
  int id = atoi(words[1].c_str());
  UnitManager *um = UnitManager::GetUnitManager();
  um->RemoveUnit(id);
  return "SUCCESS"; 
}

std::string UpdateUnits(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be a string
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    return "Arg from Javascript is not a string!";
  }
  std::string arg0 = args[0].AsString();
  size_t green_index = arg0.find("GREEN");
  size_t red_index = arg0.find("RED");
  std::string green_substring, red_substring;
  printf("green_index=%d redindex=%d\n", green_index, red_index);
  if (green_index < red_index) {
    green_substring = arg0.substr(green_index, red_index - green_index);
    red_substring = arg0.substr(red_index);
  } else {
    red_substring = arg0.substr(red_index, green_index - red_index);
    green_substring = arg0.substr(green_index);
  }

  printf("red_substring=%s  green_substring=%s\n",
    red_substring.c_str(), green_substring.c_str());

  // now for red and green substrings, move past RED or GREEN so that they
  // each start with the first "["
  red_substring = red_substring.substr( red_substring.find_first_of("["));
  green_substring = green_substring.substr( green_substring.find_first_of("["));

  // Trim end of string
  RemoveTrailingSpaces(&green_substring);
  RemoveTrailingSpaces(&red_substring);

  printf("Red_substring='%s'  Green_substring='%s'\n",
    red_substring.c_str(), green_substring.c_str());

  std::vector<std::string> greenUnitWords;
  GetElementsFromString(green_substring, std::string("[]"), greenUnitWords);
  std::vector<std::string> redUnitWords;
  GetElementsFromString(red_substring, std::string("[]"), redUnitWords);

  // GetUnitM
  UnitManager *um = UnitManager::GetUnitManager();
  for (unsigned int I = 0; I < greenUnitWords.size(); ++I) {
    printf("Gr I=%d UnitWord=%s\n", I, greenUnitWords[I].c_str());
    std::vector<std::string> unitData;
    GetElementsFromString(greenUnitWords[I], std::string(","), unitData);
    for (unsigned int u = 0; u < unitData.size(); ++u) {
      printf(" Unit element[%s] ", unitData[u].c_str());
    } printf("\n");
    um->AddUnit(
       atoi(unitData[0].c_str()), // index
       Unit::createUnit(
           atoi(unitData[0].c_str()), // index
           atoi(unitData[2].c_str()), // x
           atoi(unitData[3].c_str()), // y
           atoi(unitData[4].c_str()), // attack
           atoi(unitData[5].c_str()), // move
           unitData[1],               // type string
           "GREEN")
      );
  }
  for (unsigned int I = 0; I < redUnitWords.size(); ++I) {
    printf("Red I=%d UnitWord=%s\n", I, redUnitWords[I].c_str());
    std::vector<std::string> unitData;
    GetElementsFromString(redUnitWords[I], std::string(","), unitData);
    for (unsigned int u = 0; u < unitData.size(); ++u) {
      printf(" Unit element[%s] ", unitData[u].c_str());
    } printf("\n");
    um->AddUnit(
       atoi(unitData[0].c_str()), // index
       Unit::createUnit(
           atoi(unitData[0].c_str()), // index
           atoi(unitData[2].c_str()), // x
           atoi(unitData[3].c_str()), // y
           atoi(unitData[4].c_str()), // attack
           atoi(unitData[5].c_str()), // move
           unitData[1],               // type string
           "RED")
      );
  }
  
  printf("UpdateUnits  arg0=%s\n", arg0.c_str());
  return "done";
}
std::string UpdateBoard(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be a string
  if (args.size() != 1) {
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    return "Arg from Javascript is not a string!";
  }

  pp::Var exception;  // Use initial "void" Var for exception
  std::string arg0 = args[0].AsString();
//  string arg2 = args[2].AsString();
//  string arg3 = args[3].AsString();

  printf("UpdateBoard: %s\n", arg0.c_str());

  std::istringstream arg_ss(arg0);
  std::vector<std::string> words;

  // use spaces to separate the elements of the string
  GetElementsFromString(arg0, std::string(" "), words);

  int columns = atoi( words[1].c_str() );
  int rows = atoi( words[2].c_str() );
  int index = 0;

  printf(" ----- COLUMNS %d ROWS %d\n", columns, rows);
  if (theBoard == NULL) {
    theBoard = new Board(columns, rows);
  }
  for (std::vector<std::string>::iterator iter = words.begin();
      iter != words.end(); ++iter) {
    if (index > 2) {
      int col = (index-3) / rows;
      int row = (index-3) % rows;
      // then we are past the column and row
      int value = atoi( words[index].c_str() );
      Board::HexType hex_type = static_cast<Board::HexType> (value);
      theBoard->set(col, row, hex_type);
    }
    index++;
  }
  printf("returning from UpdateBoard\n");
  return "Done";
}

pp::Var HelloWorldScriptableObject::Call(const pp::Var& method,
                                         const std::vector<pp::Var>& args,
                                         pp::Var* /* exception */) {
  if (!method.is_string()) {
    return pp::Var();
  }
  std::string method_name = method.AsString();

  if (args.empty() ) { 
    return pp::Var("NO ARG DATA");
  }

  if (method_name == "postToNexe") {
    pp::Var arg0 = args[0]; 
    std::string sArg0 = arg0.AsString();
    printf(" ----- CALL(%s)\n", sArg0.c_str());
    if (sArg0.find("POST_BOARD") != std::string::npos) {
      printf("Calling UpdateBoard\n");
      return pp::Var( UpdateBoard(args) );
    }
    if (sArg0.find("GET_MOVES") != std::string::npos) {
      printf("Calling GetMoves\n");
      return pp::Var( GetMoves(args) );
    }
    if (sArg0.find("GET_ATTACK") != std::string::npos) {
      printf("Calling GetAttacks\n");
      return pp::Var( GetAttacks(args) );
    }
    if (sArg0.find("POST_UNITS") != std::string::npos) {
      printf("Calling UpdateUnits\n");
      return pp::Var( UpdateUnits(args) );
    }
    if (sArg0.find("POST_DESTROYED") != std::string::npos) {
      printf("Calling UpdateDestroyed\n");
      return pp::Var( UpdateDestroyed(args) );
    }
    if (sArg0.find("POST_UNIT_LOCATION") != std::string::npos) {
      printf("Calling UpdateUnitLocation\n");
      return pp::Var( UpdateUnitLocation(args) );
    }
    if (sArg0.find("RESOLVE_ATTACK") != std::string::npos) {
      printf("Calling ResolveAttack\n");
      return pp::Var( ResolveAttack(args) );
    }
    printf("no match in postToNexe\n");
  }
  // 
  // FIXME -- methods below are OLD!!!!!
  //
  else if (method_name == kReverseTextMethodId) {
    return pp::Var(ReverseText(args));
  } else if (method_name == kProcessArrayMethodId) {
    return pp::Var(ComputeUsingArray(args));
  } else if (method_name == kProcessIntArrayMethodId) {
    return pp::Var(ComputeUsingIntArray(args));
  } else if (method_name == kProcessStringMethodId) {
    return pp::Var(ComputeUsingString(args));
  }
  return pp::Var();
}

/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurrence of the <embed> tag that has these
/// attributes:
/// <pre>
///     type="application/x-ppapi-nacl-srpc"
///     nexes="ARM: hello_world_arm.nexe
///            x86-32: hello_world_x86_32.nexe
///            x86-64: hello_world_x86_64.nexe"
/// </pre>
/// The Instance can return a ScriptableObject representing itself.  When the
/// browser encounters JavaScript that wants to access the Instance, it calls
/// the GetInstanceObject() method.  All the scripting work is done through
/// the returned ScriptableObject.
class HelloWorldInstance : public pp::Instance {
 public:
  explicit HelloWorldInstance(PP_Instance instance) : pp::Instance(instance) {}
  virtual ~HelloWorldInstance() {}

  /// @return a new pp::deprecated::ScriptableObject as a JavaScript @a Var
  /// @note The pp::Var takes over ownership of the HelloWorldScriptableObject
  ///       and is responsible for deallocating memory.
  virtual pp::Var GetInstanceObject() {
    HelloWorldScriptableObject* hw_object = new HelloWorldScriptableObject();
    return pp::Var(this, hw_object);
  }
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of you NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with
/// <code>type="application/x-ppapi-nacl-srpc"</code>.
class HelloWorldModule : public pp::Module {
 public:
  HelloWorldModule() : pp::Module() {}
  virtual ~HelloWorldModule() {}

  /// Create and return a HelloWorldInstance object.
  /// @param instance [in] a handle to a plug-in instance.
  /// @return a newly created HelloWorldInstance.
  /// @note The browser is responsible for calling @a delete when done.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new HelloWorldInstance(instance);
  }
};

namespace pp {
/// Factory function called by the browser when the module is first loaded.
/// The browser keeps a singleton of this module.  It calls the
/// CreateInstance() method on the object you return to make instances.  There
/// is one instance per <embed> tag on the page.  This is the main binding
/// point for your NaCl module with the browser.
/// @return new HelloWorldModule.
/// @note The browser is responsible for deleting returned @a Module.
Module* CreateModule() {
  return new HelloWorldModule();
}
}  // namespace pp

