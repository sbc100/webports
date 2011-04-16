//
// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.
//
// NOTE:  Images are public domain .png files from
//        http://www.pdclipart.org/thumbnails.php?album=121
//

// Create a namespace object
var Chess = Chess || {};

Chess.Alert = function(message) {
  console.log('CHESS ALERT' + message);
  alert(message);
};

///
/// Variables for currently selected piece/coordinate, and lastMove
///
Chess.selectedPiece = null;
Chess.selectedCoord = null;
Chess.lastMove = '';  //string containing the algebraic last move (e.g. 'b2b4')
Chess.checkList = [];

/// If we need to undo a move, we need to know the from/to coords and original
/// pieces that were there.
Chess.boardString = '';
///
/// Variable and functions for state/GUI elements
/// Valid states are 'PlayerTurn', 'PlayerDone', 'AiTurn', 'WaitingOnAi'
///
Chess.state = 'PlayerTurn';
Chess.getState = function() {
  return Chess.state;
};
Chess.nextState = function() {
  if (Chess.state == 'PlayerTurn') {
    Chess.state = 'PlayerDone';
  } else if (Chess.state == 'PlayerDone') {
    Chess.state = 'AiTurn';
  } else if (Chess.state == 'AiTurn') {
    Chess.state = 'WaitingOnAi';
  } else if (Chess.state == 'WaitingOnAi') {
    Chess.state = 'PlayerTurn';
  }
  return Chess.state;
};
Chess.setState = function(s) {
  Chess.state = s;
};


Chess.boardSize = 8;

Chess.ColorType = {
  BLACK: 0,
  WHITE: 1
};

Chess.PieceType = {
  PAWN: 0,
  ROOK: 1,
  KNIGHT: 2,
  BISHOP: 3,
  QUEEN: 4,
  KING: 5,
  NONE: 6
};

Chess.Coordinate = function(c, r) {
  this.column_ = c;
  this.row_ = r;
};

Chess.Coordinate.prototype.getColumn = function() {
  return this.column_;
};

Chess.Coordinate.prototype.getRow = function() {
  return this.row_;
};

Chess.Coordinate.prototype.toString = function() {
  return " " + this.column_ + ":" + this.row_ + " ";
};

Chess.Notation = function(letter, number) {
  this.letter_ = letter;
  this.number = number;
};

Chess.notationStrToCoord = function(notationString) {
  var letter = notationString.charAt(0);
  var number = notationString.charAt(1);
  var column = -1;  // so that we know we have an error if we don't change it
  switch (letter) {
    case 'a': case 'A':
      column = 0;
      break;
    case 'b': case 'B':
      column = 1;
      break;
    case 'c': case 'C':
      column = 2;
      break;
    case 'd': case 'D':
      column = 3;
      break;
    case 'e': case 'E':
      column = 4;
      break;
    case 'f': case 'F':
      column = 5;
      break;
    case 'g': case 'G':
      column = 6;
      break;
    case 'h': case 'H':
      column = 7;
      break;
  }
  if (column < 0 || column > 7) {
    console.log('Error converting notation ' + notationString +
                ' to column');
    return null;
  }
  if (number != '1' && number != '2' && number != '3' && number != '4' &&
      number != '5' && number != '6' && number != '7' && number != '8') {
    console.log('Invalid number for 2nd digit ' + number);
    return null;
  }
  var row = 8 - parseInt(number);
  if (row < 0 || row > 7) {
    console.log('Error converting notation ' + notation + ' to row');
    return null;
  }
  return new Chess.Coordinate(column, row);
};

//
// Clear a context
//
function clearContext(theContext, theCanvas) {
  theContext.beginPath();
  theContext.clearRect(0, 0, theCanvas.width, theCanvas.height);
  theContext.closePath();
}

//
// Piece class
//
Chess.Piece = function(color, pieceType) {
  this.color_ = color;
  this.pieceType_ = pieceType;
};
Chess.Piece.prototype.getColor = function() {
  return this.color_;
};
Chess.Piece.prototype.getPieceType = function() {
  return this.pieceType_;
};
Chess.Piece.prototype.toString = function() {
  var theString;
  var colorArray = ['BLACK', 'WHITE'];
  var pieceArray = ['Pawn', 'Rook', 'Knight', 'Bishop', 'Queen', 'King',
                    'None'];
  theString = colorArray[this.color_] + ' ' + pieceArray[this.pieceType_];
  return theString;
};
Chess.Piece.prototype.toChar = function() {
  // convert Pawn to p, Rook to r, Knight to h (horse), Bishop to b,
  //   Queen to q, and King to k
  // Black is just uppercase of this.
  var blackPieceArray = ['p', 'r', 'n', 'b', 'q', 'k'];
  var whitePieceArray = ['P', 'R', 'N', 'B', 'Q', 'K'];
  if (this.color_ == Chess.ColorType.BLACK) {
    return blackPieceArray[this.pieceType_];
  } else {
    return whitePieceArray[this.pieceType_];
  }
};

Chess.Piece.pieceFactory = function(character) {
  switch (character) {
    case ' ':
      console.log('returning null in pieceFactory');
      return null;
    case 'p':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.PAWN);
    case 'P':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.PAWN);
    case 'r':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.ROOK);
    case 'R':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.ROOK);
    case 'n':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);
    case 'N':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KNIGHT);
    case 'b':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.BISHOP);
    case 'B':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.BISHOP);
    case 'q':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.QUEEN);
    case 'Q':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.QUEEN);
    case 'k':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KING);
    case 'K':
      return new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KING);
    default:
      Chess.Alert('Bad piece [' + character + '] in Chess.Piece.pieceFactory');
  }
};

//
// BoardContents class
//
Chess.BoardContents = function(columns, rows) {
  this.columns_ = columns;
  this.rows_ = rows;
  this.pieceArray_ = new Array();
  for (var i = 0; i < this.row_ * this.columns_; ++i) {
    this.pieceArray_[i] = null; // initially null references
  }
};

Chess.BoardContents.prototype.getIndex = function(column, row) {
  return row * this.columns_ + column;
};

Chess.BoardContents.prototype.update = function(column, row, theUnit) {
  var index = this.getIndex(column, row);
  this.pieceArray_[index] = theUnit;
};

Chess.BoardContents.prototype.getPiece = function(column, row) {
  var index = this.getIndex(column, row);
  return this.pieceArray_[index];
};

Chess.BoardContents.prototype.getPieceAtNotation = function(notation) {
  if (notation.length != 2) {
    console.log('Error in Chess.BoardContents.prototype.getPieceAtNotation [' +
                notation + ']');
    return '?';
  }
  var coord = Chess.notationStrToCoord(notation);
  return this.getPiece(coord.getColumn(), coord.getRow());
};

Chess.BoardContents.prototype.toString = function() {
  var theString = '';
  for (var row = 0; row < Chess.boardSize; ++row) {
    for (var column = 0; column < Chess.boardSize; ++column) {
      var thePiece = this.getPiece(column, row);
      if (thePiece)
        theString += thePiece.toChar();
      else
        theString += ' ';
    }
    theString += '\n';
  }
  theString += 'Top: Black\n'; //FIXME, use a variable for this
  return theString;
};

///
/// stringData can have up to 8 lines, each line can have up to 8 characters.
///
Chess.BoardContents.prototype.setContents = function(stringData) {
  var lines = stringData.split('\n');
  var lineIndex;
  for (lineIndex = 0; lineIndex < Math.min(lines.length, 8); ++lineIndex) {
    var line = lines[lineIndex];
    console.log('LINE ' + lineIndex + ' : ' + line);
    for (charIndex = 0; charIndex < Math.min(line.length, 8); ++charIndex) {
      this.pieceArray_[this.getIndex(charIndex, lineIndex)] =
        Chess.Piece.pieceFactory(line.charAt(charIndex));
    }
  }
  clearContext(Chess.ctxPieces, Chess.canvasPieces);
  theBoard.drawPieces(Chess.ctxPieces);
};

Chess.BoardContents.prototype.defaultInit = function() {
  // black starting locations
  this.pieceArray_[this.getIndex(0, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(4, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KING);
  this.pieceArray_[this.getIndex(3, 0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.QUEEN);
  for (var i = 0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i, 1)] =
      new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.PAWN);
  }

  // white starting locations
  this.pieceArray_[this.getIndex(0, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(4, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KING);
  this.pieceArray_[this.getIndex(3, 7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.QUEEN);
  for (var i = 0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i, 6)] =
      new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.PAWN);
  }
};

//
// Board class -- draws the board squares and chess notation around the side.
//
Chess.Board = function() {
  Chess.Board.pixelsPerSquare = 80;
  this.Init(); //defined below!
};

Chess.Board.pixelsPerSquare = 80;
Chess.Board.borderPixels = 130;
Chess.Board.gapPixels = 1; //gap between squares
Chess.Board.WHITE = 'rgb(255,240,240)';
Chess.Board.BLACK = 'rgb(139,137,137)';
Chess.Board.HIGHLIGHT = 'rgba(255,255,0,0.5)';
Chess.Board.LAST_MOVE_COLOR = 'rgba(0,0,255,0.5)';
Chess.Board.CHECK_COLOR = 'rgba(255,0,0,0.9)';
Chess.Board.topLeft = Chess.Board.WHITE;
Chess.Board.letterArray = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

Chess.Board.prototype.otherColor = function(color) {
  // console.log('color=' + color);
  if (color == Chess.Board.BLACK) {
    return Chess.Board.WHITE;
  }
  else if (color == Chess.Board.WHITE) {
    return Chess.Board.BLACK;
  } else {
    console.log('ERROR IN otherColor');
  }
};

//
// Given a row or column, convert to coordinate (pixel) value.
//
Chess.Board.prototype.gridToCoord = function(grid) {
  if (grid < 0 || grid > Chess.boardSize) {
    return 0;
  }
  return Chess.Board.borderPixels +
    Chess.Board.pixelsPerSquare * grid;
};

// use gridToCoord and image size to get x coord
Chess.Board.prototype.getPieceX = function(grid, image) {
  return this.gridToCoord(grid) +
         (Chess.Board.pixelsPerSquare - image.width) / 2;
};
// use gridToCoord and image size to get y coord
Chess.Board.prototype.getPieceY = function(grid, image) {
  return this.gridToCoord(grid) +
         (Chess.Board.pixelsPerSquare - image.height) / 2;
};

Chess.Board.prototype.getGridClicked = function(coord) {
  if (coord < Chess.Board.borderPixels) {
    return -1;
  }
  if (coord > Chess.Board.borderPixels +
      Chess.boardSize * Chess.Board.pixelsPerSquare) {
    return -1;
  }
  grid = Math.floor(((coord - Chess.Board.borderPixels) /
                      Chess.Board.pixelsPerSquare));
  return grid;
};

///
/// Converts a 0-based column (0 is leftmost, 7 is rightmost)
/// to a,b,...,h
///
Chess.Board.prototype.convertColumnToLetter = function(coord) {
  if (coord < 0 || coord >= Chess.boardSize) {
    return '?column?';
  }
  return Chess.Board.letterArray[coord];
};

///
/// Converts a 0-based internal row representation to chess row.
/// Input is 0-7 where 0 is top row, 7 is bottom row.
/// Output is 8-1 where 8 is top row, 1 is bottom row.
///
Chess.Board.prototype.convertRowToChessRow = function(row) {
  if (row < 0 || row >= Chess.boardSize) {
    return '?row?';
  }
  return 8 - row;
};

///
/// For now, this is VERY similar to markSquare...but it may not always be,
/// so I'm keeping it a separate function.
///
Chess.Board.prototype.markCheck = function(column, row, ctxHighlight) {
  // get top left corner of this square
  topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;
  topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;

  // set color
  ctxHighlight.fillStyle = Chess.Board.CHECK_COLOR;
  ctxHighlight.strokeStyle = Chess.Board.CHECK_COLOR;

  ctxHighlight.beginPath();
  ctxHighlight.strokeRect(topLeftX + Chess.Board.gapPixels,
                          topLeftY + Chess.Board.gapPixels,
                          Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2,
                          Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2);
  ctxHighlight.closePath();
  console.log('markCheck ' + column + ':' + row);
};

Chess.Board.prototype.markSquare = function(column, row, ctxHighlight) {
  // get top left corner of this square
  topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;
  topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;

  // set color
  ctxHighlight.fillStyle = Chess.Board.LAST_MOVE_COLOR;
  ctxHighlight.strokeStyle = Chess.Board.LAST_MOVE_COLOR;

  ctxHighlight.beginPath();
  ctxHighlight.strokeRect(topLeftX + Chess.Board.gapPixels,
                          topLeftY + Chess.Board.gapPixels,
                          Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2,
                          Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2);
  ctxHighlight.closePath();
};

Chess.Board.prototype.highlight = function(column, row, ctxHighlight) {

  // set borders
  leftBorder = Chess.Board.borderPixels;
  topBorder = Chess.Board.borderPixels;

  // get top left corner of this square
  topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;
  topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;

  // set color
  ctxHighlight.fillStyle = Chess.Board.HIGHLIGHT;

  ctxHighlight.beginPath();
  ctxHighlight.fillRect(topLeftX + Chess.Board.gapPixels,
                        topLeftY + Chess.Board.gapPixels,
                        Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2,
                        Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2);
  ctxHighlight.closePath();
};

Chess.Board.prototype.drawBoard = function(leftBorder, topBorder, ctxBoard) {
  var column, row, color;
  color = Chess.Board.topLeft;
  var topLeftX, topLeftY;

  var font = ctxBoard.font;
  var fillStyle = ctxBoard.fillStyle;
  var strokeStyle = ctxBoard.strokeStyle;
  ctxBoard.strokeStyle = Chess.Board.BLACK;

  column = 0;
  row = 0;
  for (var index = 0; index < Chess.boardSize * Chess.boardSize; ++index) {

    // get top left corner of square
    topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;
    topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels;
    // set color
    ctxBoard.fillStyle = color;
    ctxBoard.beginPath();
    ctxBoard.fillRect(topLeftX + Chess.Board.gapPixels,
                      topLeftY + Chess.Board.gapPixels,
                      Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2,
                      Chess.Board.pixelsPerSquare - Chess.Board.gapPixels * 2);
    ctxBoard.closePath();
    color = this.otherColor(color);
    ++column;
    if (column == 8) {
      ++row;
      column = 0;
      color = this.otherColor(color);
    }
  }

  // now draw labels
  ctxBoard.strokeStyle = Chess.Board.BLACK;
  for (column = 0; column < Chess.boardSize; ++column) {
    ctxBoard.font = '14pt Arial';
    topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels +
               Chess.Board.pixelsPerSquare / 3;
    topLeftY = Chess.Board.borderPixels - 20;
    ctxBoard.strokeText(Chess.Board.letterArray[column], topLeftX, topLeftY);
    topLeftY = Chess.boardSize * Chess.Board.pixelsPerSquare +
               Chess.Board.borderPixels + 40;
    ctxBoard.strokeText(Chess.Board.letterArray[column], topLeftX, topLeftY);
  }
  for (row = 0; row < Chess.boardSize; ++row) {
    var chess_row = 8 - row;
    topLeftX = Chess.Board.borderPixels - 20;
    topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels +
               Chess.Board.pixelsPerSquare / 2;
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
    topLeftX = Chess.boardSize * Chess.Board.pixelsPerSquare +
               Chess.Board.borderPixels + 20;
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
  }

  ctxBoard.fillStyle = fillStyle;
  ctxBoard.strokeStyle = strokeStyle;
  ctxBoard.font = font;
};

Chess.Board.prototype.Init = function() {
 Chess.canvasScratch = document.getElementById('canvasScratch');
 Chess.canvasPieces = document.getElementById('canvasPieces');
 Chess.canvasBk = document.getElementById('canvasBk');

 if (Chess.canvasScratch == undefined) {
   console.log('Canvas canvasScratch is not defined');
   return;
 }
 Chess.ctxScratch = canvasScratch.getContext('2d');
 Chess.ctxPieces = canvasPieces.getContext('2d');
 Chess.ctxBk = canvasBk.getContext('2d');

 this.drawBoard(Chess.Board.borderPixels, Chess.Board.borderPixels,
                Chess.ctxBk);

 Chess.whitePawnImage = new Image();
 Chess.whitePawnImage.src = 'chess_piece_2_white_pawn.png';
 Chess.whiteKnightImage = new Image();
 Chess.whiteKnightImage.src = 'chess_piece_2_white_knight.png';
 Chess.whiteRookImage = new Image();
 Chess.whiteRookImage.src = 'chess_piece_2_white_rook.png';
 Chess.whiteBishopImage = new Image();
 Chess.whiteBishopImage.src = 'chess_piece_2_white_bishop.png';
 Chess.whiteKingImage = new Image();
 Chess.whiteKingImage.src = 'chess_piece_2_white_king.png';
 Chess.whiteQueenImage = new Image();
 Chess.whiteQueenImage.src = 'chess_piece_2_white_queen.png';

 Chess.blackPawnImage = new Image();
 Chess.blackPawnImage.src = 'chess_piece_2_black_pawn.png';
 Chess.blackKnightImage = new Image();
 Chess.blackKnightImage.src = 'chess_piece_2_black_knight.png';
 Chess.blackRookImage = new Image();
 Chess.blackRookImage.src = 'chess_piece_2_black_rook.png';
 Chess.blackBishopImage = new Image();
 Chess.blackBishopImage.src = 'chess_piece_2_black_bishop.png';
 Chess.blackKingImage = new Image();
 Chess.blackKingImage.src = 'chess_piece_2_black_king.png';
 Chess.blackQueenImage = new Image();
 Chess.blackQueenImage.src = 'chess_piece_2_black_queen.png';

 this.contents = new Chess.BoardContents(Chess.boardSize,
   Chess.boardSize); // typically 8x8 board
 this.contents.defaultInit();
};


Chess.Board.prototype.drawPiece = function(ctx, column, row, pieceType,
                                           colorType) {
  var theImage;
  switch (pieceType) {
    case Chess.PieceType.PAWN:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whitePawnImage;
      } else {
        theImage = Chess.blackPawnImage;
      }
      break;
    case Chess.PieceType.ROOK:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whiteRookImage;
      } else {
        theImage = Chess.blackRookImage;
      }
      break;
    case Chess.PieceType.KNIGHT:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whiteKnightImage;
      } else {
        theImage = Chess.blackKnightImage;
      }
      break;
    case Chess.PieceType.BISHOP:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whiteBishopImage;
      } else {
        theImage = Chess.blackBishopImage;
      }
      break;
    case Chess.PieceType.QUEEN:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whiteQueenImage;
      } else {
        theImage = Chess.blackQueenImage;
      }
      break;
    case Chess.PieceType.KING:
      if (colorType == Chess.ColorType.WHITE) {
        theImage = Chess.whiteKingImage;
      } else {
        theImage = Chess.blackKingImage;
      }
      break;
  }
  ctx.drawImage(theImage, this.getPieceX(column, theImage),
                this.getPieceY(row, theImage));
};

Chess.Board.prototype.drawPieces = function(ctx) {
  // console.log('Chess.Board.drawPieces...');
  var column, row;
  for (column = 0; column < Chess.boardSize; ++column) {
    for (row = 0; row < Chess.boardSize; ++row) {
      var thePiece = this.contents.getPiece(column, row);
      if (thePiece) {
        this.drawPiece(ctx, column, row, thePiece.getPieceType(),
                             thePiece.getColor());
      }
    }
  }
  // highlight Chess.lastMove
  if (Chess.lastMove != '') {
    var toNotation = Chess.lastMove.substr(2,2);
    var toCoord = Chess.notationStrToCoord(toNotation);
    // highlight |toCoord| LAST_MOVE
    theBoard.markSquare(toCoord.getColumn(), toCoord.getRow(), ctx);
    if (Chess.checkList.length > 0) {
      Chess.checkList.forEach(function(el) {
          theBoard.markCheck(el.getColumn(), el.getRow(), ctx);
        }
      );
    }
  }
};

var theBoard = null; // FIXME -- global (un-namespaced) variable

///
///
///
Chess.mouseDownHandler = function(e) {
  var x = e.offsetX;
  var y = e.offsetY;
  var column = theBoard.getGridClicked(x);
  var row = theBoard.getGridClicked(y);
  var message = 'You clicked on column ' + column + ' row ' + row +
                ' chess notation: ' + theBoard.convertColumnToLetter(column) +
                theBoard.convertRowToChessRow(row) + '\n';

  // make sure we are in a state where player can select
  if (Chess.state != 'PlayerTurn') {
    console.log('State ' + Chess.state + ' does NOT allow mouse selections!');
    return;
  }

  if (Chess.selectedPiece) {
    var valid_move = (column != -1) && (row != -1);
    if (!valid_move) {
      Chess.selectedPiece = null;  // unselect the piece & we are done
      return;
    } else if (Chess.selectedCoord.getColumn() == column &&
               Chess.selectedCoord.getRow() == row) {
      // then we clicked on the selected piece
      Chess.selectedPiece = null;  // unselect the piece & we are done
    } else {
      // save the old state in case we need to Undo
      Chess.boardString = theBoard.contents.toString();

      // do the move
      var toNotation = theBoard.convertColumnToLetter(column) +
                       theBoard.convertRowToChessRow(row);
      var fromNotation = theBoard.convertColumnToLetter(
                           Chess.selectedCoord.getColumn()) +
                         theBoard.convertRowToChessRow(
                           Chess.selectedCoord.getRow());

      console.log('FROM:' + fromNotation + ' TO:' + toNotation);
      // FIXME -- add to toNotation on pawn promotion...
      var result = Chess.doMove(fromNotation, toNotation);
      if (result) {

        // Clear last selected piece/coord; advance state;
        // Save 'lastMove' so we can send it to AI
        Chess.lastMove = fromNotation + toNotation;
        Chess.updateLastMove(Chess.lastMove);
        Chess.state = Chess.nextState();
        Chess.selectedPiece = null;
        Chess.selectedCoord = null;

        // clear out pieces that were in check
        Chess.checkList = [];

        // FIXME -- valid move -- redraw pieces
        clearContext(Chess.ctxScratch, Chess.canvasScratch);
        clearContext(Chess.ctxPieces, Chess.canvasPieces);
        theBoard.drawPieces(Chess.ctxPieces);
      } else {
        // error calling doMove -- unselected selected piece
        console.log('Error calling doMove, de-selecting...');
        Chess.selectedPiece = null;
        Chess.selectedCoord = null;
        // FIXME -- valid move -- redraw pieces
        clearContext(Chess.ctxScratch, Chess.canvasScratch);
        clearContext(Chess.ctxPieces, Chess.canvasPieces);
        theBoard.drawPieces(Chess.ctxPieces);
      }
      return;
    }
  }

  var thePiece = theBoard.contents.getPiece(column, row);
  if (thePiece) {
    Chess.selectedPiece = thePiece;
    Chess.selectedCoord = new Chess.Coordinate(column, row);
    message += 'That space contains ' + thePiece.toString() + ' \n';
    var boardString = theBoard.contents.toString();
    boardString += column + ':' + row;
    message += boardString;
  } else {
    Chess.selectedPiece = null;
    Chess.selectedCoord = null;
  }
  if (x != -1 && y != -1) {
    console.log(message);
    console.log('naclHelperModule = ' + naclHelperModule);
    var moveList = naclHelperModule.GetChoices(boardString);
    // moveList = moveList.replace(/^\s*/gi, '');  // trim leading spaces
    // moveList = moveList.replace(/\s*$/gi, '');  // trim trailing spaces
    console.log('NEXE moveList={' + moveList + '}');
    var movesAndChecks = moveList.split('|');
    var moveOnlyString = movesAndChecks[0];
    moveOnlyString = moveOnlyString.replace(/^\s*/gi, '');  // trim leading spaces
    moveOnlyString = moveOnlyString.replace(/\s*$/gi, '');  // trim trailing spaces

 if(0) {
    var checkOnlyString = movesAndChecks[1];
    console.log('CheckOnlyString = ' + checkOnlyString); 
    checkOnlyString = checkOnlyString.replace(/^\s*/gi, '');  // trim leading spaces
    checkOnlyString = checkOnlyString.replace(/\s*$/gi, '');  // trim trailing spaces
    var checks = checkOnlyString.split(' ');
    console.log('CHECKS=' + checks);
    checks.forEach(function(el) {
        var coords = el.split(':');
        console.log('Check x=' + coords[0] + ' y=' + coords[1]);
        theBoard.markCheck(coords[0], coords[1], Chess.ctxScratch);
      }
    );
 }
    var moves = moveOnlyString.split(' ');
    console.log('LIST of moves=' + moves);
    clearContext(Chess.ctxScratch, Chess.canvasScratch);
    moves.forEach(function(el) {
        var coords = el.split(':');
        console.log('x=' + coords[0] + ' y=' + coords[1]);
        // highlight a valid move
        theBoard.highlight(coords[0], coords[1], Chess.ctxScratch);
      }
    );
  }
};

Chess.updateBoardHandler = function() {
  // Need to send a command 'show board'
  // Need to remove spaces, then replace '.' with ' '

  var cmdReply = naclModule.talk('show board');
  console.log('cmdReply=\n' + cmdReply);

  var boardString = '';
  var lineArray = cmdReply.split('\n');
  for (var index = 0; index < lineArray.length; ++index) {
    console.log('Index:' + index + ' Line:' + lineArray[index]);

    // if the line is not empty and is not the header-line that contains
    // 'white', then lets put in |boardString| which is just the contents
    if (lineArray[index].length > 0 &&
        lineArray[index].indexOf('white') == -1) {
      boardString += lineArray[index] + '\n';
    }
  }
  // Chess.Alert('Board is [' + boardString + ']');
  var newBoard = boardString.replace(/ /g, '');
  newBoard = newBoard.replace(/\./g, ' ');
  console.log('newBoard=' + newBoard);
  theBoard.contents.setContents(newBoard);
};

///
/// Try to move a piece from |fromNotation| to |toNotation|.
/// If not successful, use Chess.Alert to notify user.
/// |fromNotation| should be an algebraic location (e.g. 'a4')
/// |toNotation| can be an algebraic location (e.g. 'b2') but
/// can include an option piece if it's for pawn promotion
/// such as 'b7Q'.
///
Chess.doMove = function(fromNotation, toNotation) {
  var fromCoord = Chess.notationStrToCoord(fromNotation);
  if (!fromCoord) {
    Chess.Alert('Error: fromNotation [' + fromNotation + '] is not valid');
    return false;
  }

  var pieceInFrom = theBoard.contents.getPieceAtNotation(fromNotation);
  var pieceInFromString = ' NONE ';
  if (pieceInFrom) {
    pieceInFromString = pieceInFrom.toString();
  } else {
    // this is an error, because there should be a piece in the 'from' location
    Chess.Alert('There is no piece at ' + fromNotation);
    return false;
  }

  var promotionPiece = '';
  var newPieceInTo = null;  // new piece in To location for promotion
  if (toNotation.length == 3) {
    promotionPiece = toNotation.substr(2, 1);  // grab the promotionPiece
    toNotation = toNotation.substr(0, 2); // shorten to the 2 characters
  }
  var toCoord = Chess.notationStrToCoord(toNotation);
  console.log('toCoord=' + toCoord);
  if (toCoord == null) {
    Chess.Alert('Error: toNotation[' + toNotation + '] is not valid');
    return false;
  }
  var pieceInTo = theBoard.contents.getPieceAtNotation(toNotation);
  var pieceInToString = ' NONE ';
  if (pieceInTo) {
    pieceInToString = pieceInTo.toString();
  }
  console.log('Piece at that location is ' + pieceInFromString +
              ' piece in the new location is ' + pieceInToString);

  // check details of promotionPiece...
  if (promotionPiece != '') {
    newPieceInTo = Chess.Piece.pieceFactory(promotionPiece);
    if (newPieceInTo == null) {
      Chess.Alert('Invalid promotion piece ' + promotionPiece);
      return false;
    }
    var row = toCoord.getRow();
    if (row != 7 && row != 0) {
      Chess.Alert('Error:' + toNotation + ' is not a valid promotion location');
      return false;
    }
    if (newPieceInTo.getColor() != pieceInFrom.getColor()) {
      Chess.Alert('Piece ' + pieceInFrom.toString() +
                  ' cannot get promoted to ' + newPieceInTo.toString() +
                  ' which is of a different color');
      return false;
    }
  }

  // actually change the board
  if (newPieceInTo) {
    theBoard.contents.update(toCoord.getColumn(), toCoord.getRow(),
                             newPieceInTo);
  } else {
    theBoard.contents.update(toCoord.getColumn(), toCoord.getRow(),
                             pieceInFrom);
  }
  theBoard.contents.update(fromCoord.getColumn(), fromCoord.getRow(), null);


  // CHECK FOR CASTLING MOVE
  var isCastleMove = false;
  var rookCastleOldCoord = null;
  var rookCastleNewCoord = null;
  if ((pieceInFrom.getPieceType() == Chess.PieceType.KING) &&
      (Math.abs(fromCoord.getColumn() - toCoord.getColumn()) == 2)) {
    isCastleMove = true;
    if (toCoord.getColumn() < fromCoord.getColumn()) {
      // the king is castling to the left
      rookCastleOldCoord = new Chess.Coordinate(0, fromCoord.getRow());
      rookCastleNewCoord = new Chess.Coordinate(toCoord.getColumn() + 1, fromCoord.getRow());
    } else {
      // the king is castling to the right
      rookCastleOldCoord = new Chess.Coordinate(7, fromCoord.getRow());
      rookCastleNewCoord = new Chess.Coordinate(toCoord.getColumn() - 1, fromCoord.getRow());
    }
  }
  // if this was a castle move, move the rook too!
  if (isCastleMove) {
    var theRook = theBoard.contents.getPiece(
        rookCastleOldCoord.getColumn(),
        rookCastleOldCoord.getRow());
    theBoard.contents.update(rookCastleNewCoord.getColumn(),
                             rookCastleNewCoord.getRow(), theRook);
    theBoard.contents.update(rookCastleOldCoord.getColumn(),
                             rookCastleOldCoord.getRow(), null);
    console.log('DOING CASTLE MOVE: theRook = ' + theRook.toString() +
                ' new:' + rookCastleNewCoord.toString() + ' old:' +
                rookCastleOldCoord.toString());
  }


  // clear the piece layer so we redraw it
  clearContext(Chess.ctxPieces, Chess.canvasPieces);
  theBoard.drawPieces(Chess.ctxPieces);
  return true;
};

Chess.cmdHandler = function() {
  var cmdField = document.getElementById('userCmd');
  console.log('Command is ' + cmdField.value + ' len=' + cmdField.value.length);
  if (cmdField.value.length > 0) {
    var cmdReply = naclModule.talk(cmdField.value);
    console.log('cmdReply = ' + cmdReply);
    Chess.Alert('Cmd:' + cmdField.value + ' Reply {' + cmdReply + '}');
    return;
  }
};

theBoard = new Chess.Board();

//
// if answer starts with 'move:' 'move ' or 'move' remove that
//
Chess.filterAnswer = function(str) {
  var index = 0;
  var newString = str;
  var prefixList = ['move:', 'Move:', 'move', 'Move'];
  var foundPrefix = false;

  // Remove a word from prefixList from the beginning of |str|
  while (index < prefixList.length && !foundPrefix) {
    var prefix = prefixList[index];
    var prefix_location = str.indexOf(prefix);
    if (prefix_location != -1) {
      foundPrefix = true;
      // start after |prefix|
      newString = str.substr(prefix_location + prefix.length);
    }
    ++index;
  }
  // trim any leading/trailing whitespace
  newString = newString.replace(/^\s+/, '');
  newString = newString.replace(/\s+$/, '');

  console.log('FILTER [' + str + '] => [' + newString + ']');
  return newString;
};

///
/// Handle AI reply to the user move
///
Chess.handleReply = function(answer) {
  // if answer contains 'move' then handle the board update for AI move

  console.log('ANSWER: [' + answer + ']');
  if (answer.indexOf('Illegal move') != -1) {
    // take back person's move
    Chess.Alert('Your last move was NOT legal: ' + answer);

    // restore the old move...
    console.log('oldFromPiece: ' + Chess.oldFromPiece + '  oldToPiece: ' +
                Chess.oldToPiece);
    theBoard.contents.setContents(Chess.boardString);

    // clear the piece layer so we redraw it
    clearContext(Chess.ctxPieces, Chess.canvasPieces);
    theBoard.drawPieces(Chess.ctxPieces);

    // set state back to PlayerTurn...
    Chess.setState('PlayerTurn');

  } else if (answer.indexOf('win') != -1) {
    Chess.updateBoardHandler(); //update the board with the final configuration
    Chess.Alert('Game Over: ' + answer);
  } else if (answer.indexOf('move') != -1) {
    answer = Chess.filterAnswer(answer);
    // do the move
    Chess.lastMove = answer;
    Chess.updateLastMove(answer);
    var fromNotation = answer.substr(0, 2);
    var toNotation = answer.substr(2);
    var result = Chess.doMove(fromNotation, toNotation);
    if (!result) {
      Chess.Alert('Error doing moving from [' + fromNotation + '] to [' +
                  toNotation + '] based on [' + answer + ']');
    }
    theBoard.drawPieces(Chess.ctxPieces);
    Chess.nextState();
  }
};

Chess.updateLastMove = function(lastMove) {
  var lastMoveField = document.getElementById('LastMove');
  if (!lastMoveField) {
    console.log('Error getting element with id LastMove');
    return;
  }
  lastMoveField.innerHTML = lastMove;
  var historyField = document.getElementById('History');
  if (!historyField) {
    console.log('Error getting element with id History');
    return;
  }
  var historySoFar = historyField.innerHTML;
  historyField.innerHTML = historySoFar + '<br>' + lastMove;
};

Chess.mainLoop = function() {
  theBoard.drawPieces(Chess.ctxPieces);
  var state = Chess.getState();
  if (state == 'PlayerDone') {
    // do we need to do something...or just go to next state?
    // for now, advance to next state and return...mainLoop is done
    Chess.checkList = [];
    Chess.nextState();
    return;
  } else if (state == 'AiTurn') {
    // send |Chess.lastMove| to the AI
    var answer = naclModule.talk(Chess.lastMove);
    console.log('Sent ' + Chess.lastMove + ' got ' + answer);

    // now go to the waiting state
    Chess.nextState();
    if (answer != '') {
      Chess.handleReply(answer);
    }

    // now check for check
    console.log('In check?');
    var boardString = theBoard.contents.toString();
    var checkString = naclHelperModule.GetCheck(boardString);
    console.log('CHECK STRING: ' + checkString);
    Chess.checkList = [];
    if (checkString != '') {
      // alert(checkString);
      // trim checkString
      checkString = checkString.replace(/^\s+/, '');
      checkString = checkString.replace(/\s+$/, '');
      var checkStrList = checkString.split(' ');
      checkStrList.forEach(function(el) {
          var coords = el.split(':');
          Chess.checkList.push(new Chess.Coordinate(coords[0], coords[1]));
          console.log('Check x=' + coords[0] + ' y=' + coords[1]);
        }
      );
    }

  } else if (state == 'WaitingOnAi') {
    // console.log('Waiting...');
    var answer = naclModule.talk('');
    // console.log('GOT ' + answer);
    if (answer != '') {
      Chess.handleReply(answer);
    }
  }
  var stateField = document.getElementById('State');
  stateField.innerHTML = state;
  var selectedPieceField = document.getElementById('SelectedPiece');
  if (Chess.selectedPiece) {
    selectedPieceField.innerHTML = Chess.selectedPiece.toString();
  } else {
    selectedPieceField.innerHTML = '';
  }
};

if (Chess.canvasScratch != undefined) {
  Chess.canvasScratch.onmousedown = Chess.mouseDownHandler;
  setInterval('Chess.mainLoop()', 1000);
}

