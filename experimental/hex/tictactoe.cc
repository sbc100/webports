

class Board;

class Move {
  private:
    int row_, column_;
    char letter_;
    Board *board_;
  public:
    Move(int r, int c, char a_letter) : row_(r), column_(c), letter_(a_letter),
      board(NULL) {}
    void UpdateBoard(Board *b) {board_ = b;}
    int Row() const {return row_;}
    int Column() const {return column_;}
    char Letter() const {return letter_;}
};

class Board {
  private:
    char pieces_[3][3];
  public:
    Board();
     
};

Board::Board() {
  for(int r=0; r<3; ++r) {
    for(int c=0; c<3; ++c) {
      pieces_[r][c] = ' ';
    }
  }
}


