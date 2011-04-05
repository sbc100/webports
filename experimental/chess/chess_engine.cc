
#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kExceptionMethodNotAString = "Method name is not a string";
const char* const kExceptionNoMethodName = "No method named ";

// Helper function to set the scripting exception.  Both |exception| and
// |except_string| can be NULL.  If |exception| is NULL, this function does
// nothing.
void SetExceptionString(pp::Var* exception, const std::string& except_string) {
  if (exception) {
    *exception = except_string;
  }
}
}  // namespace

namespace chess_engine {

/// method name for GetChoices, as seen by JavaScript code.
const char* const kGetChoices = "GetChoices";
const char* const kTalk = "talk";

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

struct Coord {
  int x_, y_;
  Coord(int x, int y) : x_(x), y_(y) {}
  Coord() : x_(-1), y_(-1) {}  // Set default values to be bogus.
};
enum Side {BLACK, WHITE};

std::string SideToString(Side s) {
  if (s == BLACK) 
    return "BLACK";
  return "WHITE";
}

class Board {
    char contents_[8][8];
    Side top_side_;
  public:
    Board(char boardcontents[][8], Side side_on_top) : top_side_(side_on_top) {
      memcpy(contents_, boardcontents, sizeof(contents_));
    }
    char PieceAt(int x, int y) {
      assert(x >= 0 && x < 8);
      assert(y >= 0 && y < 8);
      return contents_[x][y];
    }
    char PieceAt(const Coord& c) {
      assert(c.x_ >= 0 && c.x_ < 8);
      assert(c.y_ >= 0 && c.y_ < 8);
      return contents_[c.x_][c.y_];
    }

    bool AnyPieceAt(const Coord& c) {
      assert(c.x_ >= 0 && c.x_ < 8);
      assert(c.y_ >= 0 && c.y_ < 8);
      return (contents_[c.x_][c.y_] != ' ');
    }
    bool EnemyPieceAt(const Coord& c, char mypiece) {
      assert(c.x_ >= 0 && c.x_ < 8);
      assert(c.y_ >= 0 && c.y_ < 8);
      if (contents_[c.x_][c.y_] == ' ')
        return false;
      char boardpiece = contents_[c.x_][c.y_];
      bool mypiece_lower = (mypiece == tolower(mypiece));
      bool boardpiece_lower = (boardpiece == tolower(boardpiece));
      return (mypiece_lower != boardpiece_lower);
    }
    bool FriendlyPieceAt(const Coord& c, char mypiece) {
      assert(c.x_ >= 0 && c.x_ < 8);
      assert(c.y_ >= 0 && c.y_ < 8);
      if (contents_[c.x_][c.y_] == ' ')
        return false;
      char boardpiece = contents_[c.x_][c.y_];
      bool mypiece_lower = (mypiece == tolower(mypiece));
      bool boardpiece_lower = (boardpiece == tolower(boardpiece));
      bool friendly_piece_at = (mypiece_lower == boardpiece_lower);
      printf(" mypiece='%c' boardpiece='%c'\n", mypiece, boardpiece);
      printf(" At %d:%d, returning %d\n", c.x_, c.y_, friendly_piece_at);
      return friendly_piece_at;
    }

    Side GetTopSide() {return top_side_;}
};

Side GetSide(char piece) {
  char upper_char = toupper(piece);
  // White pieces are uppercase
  if (upper_char == piece) {
    return WHITE;
  }
  return BLACK;
}

bool IsPawn(char piece) {
  return (piece == 'p' || piece == 'P');
}
bool IsKnight(char piece) {
  return (piece == 'n' || piece == 'N');
}
bool IsBishop(char piece) {
  return (piece == 'b' || piece == 'B');
}
bool IsRook(char piece) {
  return (piece == 'r' || piece == 'R');
}
bool IsKing(char piece) {
  return (piece == 'k' || piece == 'K');
}
bool IsQueen(char piece) {
  return (piece == 'q' || piece == 'Q');
}

///
/// This function is passed a location on the board: |x|, |y|
/// which side the piece is on |myside|, meaning BLACK or WHITE,
/// and some move combination |delta_x| and |delta_y| to move.
/// Note:
///   1. The direction assumes you are facing the board from the |myside|
///      point of view.  Thus, if |delta_y| is 1 then the piece is moving
///      away from the side of te board where the pieces started.
///   2. It is *this* function's job to check for 'off the board' result.
///      Thus, if either |delta_x| or |delta_y| would go off the board, then
///      this function just returns false.
///
bool GetCoordFromXY(int x, int y, Side myside, Side side_on_top,
                    int delta_x, int delta_y, Coord *coord) {
  // if |myside| shows I'm on the 'bottom' of the board, then reverse |delta_y|
  if (side_on_top != myside) {
    delta_y = -delta_y;
  }
  int new_x = x + delta_x;
  int new_y = y + delta_y;
  if (new_x < 0 || new_x > 7) {
    return false;
  }
  if (new_y < 0 || new_y > 7) {
    return false;
  }
  coord->x_ = new_x;
  coord->y_ = new_y;
  return true;
}

///
/// If I'm the side on the 'top' of the board, then the pawn home (starting)
/// row is 1, otherwise it's 6.
///
int GetPawnHomeRow(Side side_on_top, Side myside) {
  if (side_on_top == myside)
    return 1;
  return 6;
}

void GetKingMoves(int x, int y, Side myside, Board *board,
                  Coord *last_move,
                  std::vector<Coord>* moves) {
  char mypiece = board->PieceAt(x, y);
  int dx, dy;
  Coord move_coord;
  for (dx = -1; dx <= 1; ++dx) {
    for (dy = -1; dy <= 1; ++dy) {
      if (dx != 0 || dy != 0) {
        printf("Considering %d %d from %x %d\n", dx, dy, x, y);
        // moving in at least one dimension
        bool is_valid = GetCoordFromXY(x, y, myside, board->GetTopSide(),
                                       dx, dy, &move_coord);
        // see if this move is_valid (on board) and not on friendly piece
        if (is_valid && !board->FriendlyPieceAt(move_coord, mypiece)) {
          moves->push_back(move_coord);
        }
        // TODO -- need to check if we are moving into check!
      }
    }
  }
}


void GetRookMoves(int x, int y, Side myside, Board *board,
                    Coord *last_move,
                    std::vector<Coord>* moves) {
  char mypiece = board->PieceAt(x, y);
  int dx, dy;
  int total_dx, total_dy;
  bool is_valid;
  Coord move_coord;

  for (int direction = 0; direction < 4; ++direction) {
    switch (direction) {
      case 0: // up 
        dx = 0;
        dy = 1;
        break;
      case 1: // down
        dx = 0;
        dy = -1;
        break;
      case 2: // left 
        dx = -1;
        dy = 0;
        break;
      case 3: // right
        dx = 1;
        dy = 0;
        break;
    }
    total_dx = dx;
    total_dy = dy;
    do {
      is_valid = GetCoordFromXY(x, y, myside, board->GetTopSide(),
                                total_dx, total_dy,
                                &move_coord);
      if (is_valid && board->FriendlyPieceAt(move_coord, mypiece)) {
        // then we are done in this direction
        is_valid = false;
        printf("Found friendly piece at %d:%d\n", move_coord.x_, move_coord.y_);
      } else if (is_valid && board->EnemyPieceAt(move_coord, mypiece)) {
        // then we can move here...but no more in this direction
        moves->push_back(move_coord);
        is_valid = false;
        printf("Found enemy piece at %d:%d\n", move_coord.x_, move_coord.y_);
      } else if (is_valid) {
        printf("Found empty coord at %d:%d\n", move_coord.x_, move_coord.y_);
        moves->push_back(move_coord);
      }
      total_dx += dx;
      total_dy += dy;
    }
    while (is_valid);
  }
}

void GetBishopMoves(int x, int y, Side myside, Board *board,
                    Coord *last_move,
                    std::vector<Coord>* moves) {
  char mypiece = board->PieceAt(x, y);
  int dx, dy;
  int total_dx, total_dy;
  bool is_valid;
  Coord move_coord;

  for (int direction = 0; direction < 4; ++direction) {
    switch (direction) {
      case 0: // up and left
        dx = -1;
        dy = 1;
        break;
      case 1: // up and right
        dx = 1;
        dy = 1;
        break;
      case 2: // down and left 
        dx = -1;
        dy = -1;
        break;
      case 3: // down and right
        dx = 1;
        dy = -1;
        break;
    }
    total_dx = dx;
    total_dy = dy;
    do {
      is_valid = GetCoordFromXY(x, y, myside, board->GetTopSide(),
                                total_dx, total_dy,
                                &move_coord);
  
      if (is_valid && board->FriendlyPieceAt(move_coord, mypiece)) {
        // then we are done in this direction
        is_valid = false;
        printf("Found friendly piece at %d:%d\n", move_coord.x_, move_coord.y_);
      } else if (is_valid && board->EnemyPieceAt(move_coord, mypiece)) {
        // then we can move here...but no more in this direction
        moves->push_back(move_coord);
        is_valid = false;
        printf("Found enemy piece at %d:%d\n", move_coord.x_, move_coord.y_);
      } else if (is_valid) {
        printf("Found empty coord at %d:%d\n", move_coord.x_, move_coord.y_);
        moves->push_back(move_coord);
      }
      total_dx += dx;
      total_dy += dy;
    }
    while (is_valid);
  }
}

void GetQueenMoves(int x, int y, Side myside, Board *board,
                   Coord *last_move,
                   std::vector<Coord>* moves) {
  // the queen has the combined moves of a bishop AND a rook
  GetRookMoves(x, y, myside, board, last_move, moves);
  GetBishopMoves(x, y, myside, board, last_move, moves);
}

void GetKnightMoves(int x, int y, Side myside, Board *board,
                    Coord *last_move,
                    std::vector<Coord>* moves) {
  Coord move_coord;
  bool is_valid;

  int x_moves[] = {-2, -1, 1, 2};
  int y_moves[] = {-2, -1, 1, 2};
  char mypiece = board->PieceAt(x, y);

  printf("GetKnightMoves x=%d y=%d mypiece=%c\n", x, y, mypiece);
  for (int x_index = 0; x_index < 4; ++x_index) {
    for (int y_index = 0; y_index < 4; ++y_index) {
      int dx = x_moves[x_index];
      int dy = y_moves[y_index];
      // valid moves must not have both dx and dx be |1| or |2|
      if (abs(dx) != abs(dy)) {
        is_valid = GetCoordFromXY(x, y, myside, board->GetTopSide(), dx, dy,
                                  &move_coord);
        // if we got a valid move back (based on dx/dy) make sure it is
        // not occupied by a friendly piece
        if (is_valid && !board->FriendlyPieceAt(move_coord, mypiece)) {
          moves->push_back(move_coord);
        }
      }
    }
  }
}

void GetPawnMoves(int x, int y, Side myside, Board *board,
                  Coord *last_move,
                  std::vector<Coord>* moves) {
  Coord two_ahead, one_ahead;
  bool is_valid_one_ahead;
  is_valid_one_ahead = GetCoordFromXY(x, y, myside, board->GetTopSide(), 0, 1,
                                      &one_ahead);
  char mypiece = board->PieceAt(x, y);

  if(is_valid_one_ahead) {
    // if moving one space ahead is valid, make sure that space is empty
    if(board->AnyPieceAt(one_ahead)) {
      printf("Piece at %d:%d, cannot move one\n", one_ahead.x_, one_ahead.y_);
      is_valid_one_ahead = false;
    }
  }

  // we can move one straight ahead if its empty
  if (is_valid_one_ahead) {
    moves->push_back(one_ahead);
  }

  if (y == GetPawnHomeRow(board->GetTopSide(), myside) && is_valid_one_ahead) {
    // then we can move two straight ahead if both are empty
    bool is_valid = GetCoordFromXY(x, y, myside, board->GetTopSide(), 0, 2,
                                   &two_ahead);

    // if moving two spaces ahead is valid, make sure that space is empty
    if(board->AnyPieceAt(two_ahead)) {
      printf("Piece at %d:%d, cannot move two\n", two_ahead.x_, two_ahead.y_);
      is_valid = false;
    }
    if (is_valid)
      moves->push_back(two_ahead);
  }

  // if an opponent is diagonal one space on either side we can move there too
  Coord diag_left;
  bool is_valid_left = GetCoordFromXY(x, y, myside, board->GetTopSide(), -1, 1,
                                      &diag_left);
  if (is_valid_left && board->EnemyPieceAt(diag_left, mypiece))
    moves->push_back(diag_left);

  Coord diag_right;
  bool is_valid_right = GetCoordFromXY(x, y, myside, board->GetTopSide(),  1, 1,
                                       &diag_right);
  if (is_valid_right && board->EnemyPieceAt(diag_right, mypiece))
    moves->push_back(diag_right);
}

/// This function is passed the arg list from the JavaScript call to
/// @a GetChoices.
/// It makes sure that there is one argument and that it is a string, returning
/// an error message if it is not.
/// On good input, finds the legal moves and returns the result.  The
/// ScriptableObject that called this function returns this string back to the
/// browser as a JavaScript value.
pp::Var Talk(const std::vector<pp::Var>& args) {
  static unsigned int talkCount = 0;
  std::string answer = "";
  static int answer_index = 0;
  const int num_answers = 10;
  const char* answer_array[num_answers] = {
    "move d7d5", "move:e7e5", "move: b8b6", "g8g6", "f8e7",
    "h7h5", "b7b5", "f7f5", "f5f4", "f4f1q"
  };

  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    printf("Unexpected number of args\n");
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    printf("Arg %s is NOT a string\n", args[0].DebugString().c_str());
    return "Arg from Javascript is not a string!";
  }
  std::string input = args[0].AsString();
  printf(" Talk ... input = %s\n", input.c_str());

  ++talkCount;
  if (talkCount % 4 == 0) {
    if (answer_index < num_answers) {
      answer = answer_array[answer_index++];
    } else {
      answer = "";
    }
  }
  printf(" Talk returning %s\n", answer.c_str());
  return pp::Var(answer);
}

/// This function is passed the arg list from the JavaScript call to
/// @a GetChoices.
/// It makes sure that there is one argument and that it is a string, returning
/// an error message if it is not.
/// On good input, finds the legal moves and returns the result.  The
/// ScriptableObject that called this function returns this string back to the
/// browser as a JavaScript value.
pp::Var GetChoices(const std::vector<pp::Var>& args) {
  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    printf("Unexpected number of args\n");
    return "Unexpected number of args";
  }
  if (!args[0].is_string()) {
    printf("Arg %s is NOT a string\n", args[0].DebugString().c_str());
    return "Arg from Javascript is not a string!";
  }
  std::string input = args[0].AsString();
  printf("Arg = {%s}\n", input.c_str());
  std::vector<std::string> input_lines;
  GetElementsFromString(input, "\n", &input_lines);
  if (input_lines.size() != 10) {
    return "Error, there should have been 10 lines of data";
  }

  char board_contents[8][8];
  for (int line = 0; line < 8; ++line) {
    std::string line_data = input_lines[line];
    if (line_data.length() != 8) {
      return std::string("Error, line '") + line_data + "' is not 8 characters";
    }
    for (int index = 0; index < 8; ++index) {
      // copy data to board_contents, indexing by [column][row]
      board_contents[index][line] = line_data[index];
    }
  }
  // "Top: Black" or "Top: White" should be in input_lines[8]
  std::string color_at_top = "Black";
  size_t colon_start = input_lines[8].find_first_of(":");
  Side top_side;
  if (colon_start == std::string::npos) {
    printf("Did not find : in %s\n", input_lines[8].c_str());
  } else {
    color_at_top = input_lines[8].substr(colon_start+2);
  }
  if (color_at_top == "Black") {
    top_side = BLACK;
  } else {
    top_side = WHITE;
  }
  // column:row should be in input_lines[9]
  colon_start = input_lines[9].find_first_of(":");
  if (colon_start == std::string::npos) {
    return std::string("Error, no column:row found in ") + input_lines[9];
  }
  std::string column_str, row_str;
  column_str = input_lines[9].substr(0, colon_start);
  row_str = input_lines[9].substr(colon_start+1);

  int column = atoi(column_str.c_str());
  int row = atoi(row_str.c_str());

  char selected_piece = board_contents[column][row];
  // key assumption -- Javascript only calls us with a valid selected piece.
  Board *board = new Board(board_contents, top_side);
  Side my_side = GetSide(selected_piece);
  printf("My side is = %s\n", SideToString(my_side).c_str()); 
  std::vector<Coord> moves;
  if (IsPawn(selected_piece)) {
    printf("PAWN\n");
    GetPawnMoves(column, row, my_side, board, NULL, &moves);
  } else if (IsKnight(selected_piece)) {
    printf("KNIGHT\n");
    GetKnightMoves(column, row, my_side, board, NULL, &moves);
  } else if (IsBishop(selected_piece)) {
    printf("BISHOP\n");
    GetBishopMoves(column, row, my_side, board, NULL, &moves);
  } else if (IsRook(selected_piece)) {
    printf("ROOK\n");
    GetRookMoves(column, row, my_side, board, NULL, &moves);
  } else if (IsKing(selected_piece)) {
    printf("KING\n");
    GetKingMoves(column, row, my_side, board, NULL, &moves);
  } else if (IsQueen(selected_piece)) {
    printf("QUEEN\n");
    GetQueenMoves(column, row, my_side, board, NULL, &moves);
  } else {
    printf("UNSUPPORTED PIECE %c\n", selected_piece);
  }

  std::string answer = "";
  for (std::vector<Coord>::iterator iter = moves.begin();
       iter != moves.end(); ++iter) {
    Coord c = *iter;
    printf("- Valid move %d:%d\n", c.x_, c.y_);
    answer += IntToString(c.x_) + ":" + IntToString(c.y_) + " ";
  }
  return pp::Var(answer);
}


class ChessEngineScriptableObject : public pp::deprecated::ScriptableObject {
 public:
  /// Determines whether a given method is implemented in this object.
  /// @param[in] method A JavaScript string containing the method name to check
  /// @param exception Unused
  /// @return @a true if @a method is one of the exposed method names.
  virtual bool HasMethod(const pp::Var& method, pp::Var* exception);

  /// Invoke the function associated with @a method.  The argument list passed
  /// via JavaScript is marshaled into a vector of pp::Vars.  None of the
  /// functions in this example take arguments, so this vector is always empty.
  /// @param[in] method A JavaScript string with the name of the method to call
  /// @param[in] args A list of the JavaScript parameters passed to this method
  /// @param exception unused
  /// @return the return value of the invoked method
  virtual pp::Var Call(const pp::Var& method,
                       const std::vector<pp::Var>& args,
                       pp::Var* exception);
};


bool ChessEngineScriptableObject::HasMethod(const pp::Var& method,
                                           pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return false;
  }
  std::string method_name = method.AsString();
  return method_name == kGetChoices || method_name == kTalk;
}

pp::Var ChessEngineScriptableObject::Call(const pp::Var& method,
                                         const std::vector<pp::Var>& args,
                                         pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return pp::Var();
  }
  std::string method_name = method.AsString();
  if (method_name == kGetChoices) {
    // note that the vector of pp::Var |args| is passed to GetChoices
    return GetChoices(args);
  } else if (method_name == kTalk) {
    return Talk(args);
  } else {
    SetExceptionString(exception,
                       std::string(kExceptionNoMethodName) + method_name);
  }
  return pp::Var();
}

/// The Instance can return a ScriptableObject representing itself.  When the
/// browser encounters JavaScript that wants to access the Instance, it calls
/// the GetInstanceObject() method.  All the scripting work is done through
/// the returned ScriptableObject.
class ChessEngineInstance : public pp::Instance {
 public:
  explicit ChessEngineInstance(PP_Instance instance) : pp::Instance(instance) {}
  virtual ~ChessEngineInstance() {}

  /// @return a new pp::deprecated::ScriptableObject as a JavaScript @a Var
  /// @note The pp::Var takes over ownership of the ChessEngineScriptableObject
  ///       and is responsible for deallocating memory.
  virtual pp::Var GetInstanceObject() {
    ChessEngineScriptableObject* hw_object = new ChessEngineScriptableObject();
    return pp::Var(this, hw_object);
  }
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of you NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with
/// <code>type="application/x-ppapi-nacl-srpc"</code>.
class ChessEngineModule : public pp::Module {
 public:
  ChessEngineModule() : pp::Module() {}
  virtual ~ChessEngineModule() {}

  /// Create and return a ChessEngineInstance object.
  /// @param[in] instance a handle to a plug-in instance.
  /// @return a newly created ChessEngineInstance.
  /// @note The browser is responsible for calling @a delete when done.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new ChessEngineInstance(instance);
  }
};
}  // namespace chess_engine


namespace pp {
/// Factory function called by the browser when the module is first loaded.
/// The browser keeps a singleton of this module.  It calls the
/// CreateInstance() method on the object you return to make instances.  There
/// is one instance per <embed> tag on the page.  This is the main binding
/// point for your NaCl module with the browser.
/// @return new ChessEngineModule.
/// @note The browser is responsible for deleting returned @a Module.
Module* CreateModule() {
  return new chess_engine::ChessEngineModule();
}
}  // namespace pp

