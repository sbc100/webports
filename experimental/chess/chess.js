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
  var blackPieceArray = ['p', 'r', 'h', 'b', 'q', 'k'];
  var whitePieceArray = ['P', 'R', 'H', 'B', 'Q', 'K'];
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
    case 'h':
      return new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);
    case 'H':
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
      alert('Bad piece [' + character + '] in Chess.Piece.pieceFactory');
  }
}

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

Chess.Board.prototype.convertColumnToLetter = function(coord) {
  if (coord < 0 || coord >= Chess.boardSize) {
    return '?column?';
  }
  return Chess.Board.letterArray[coord];
};

Chess.Board.prototype.convertRowToChessRow = function(row) {
  if (row < 0 || row >= Chess.boardSize) {
    return '?row?';
  }
  return 8 - row;
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


Chess.Board.prototype.drawPiece = function(ctx, column, row, pieceType, colorType) {
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
  console.log('drawPieces...');
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
};

var theBoard = null; // FIXME -- global (un-namespaced) variable

Chess.mouseDownHandler = function(e) {
  var x = e.offsetX;
  var y = e.offsetY;
  var column = theBoard.getGridClicked(x);
  var row = theBoard.getGridClicked(y);
  var thePiece = theBoard.contents.getPiece(column, row);
  var message = 'You clicked on column ' + column + ' row ' + row +
                ' chess notation: ' + theBoard.convertColumnToLetter(column) +
                theBoard.convertRowToChessRow(row) + '\n';
  if (thePiece) {
    message += 'That space contains ' + thePiece.toString() + ' \n';
    var boardString = theBoard.contents.toString();
    boardString += column + ':' + row;
    message += boardString;
  }
  if (x != -1 && y != -1) {
    console.log(message);
    console.log('naclModule = ' + naclModule);
    var moveList = naclModule.GetChoices(boardString);
    moveList = moveList.replace(/^\s*/gi, '');  // trim leading spaces
    moveList = moveList.replace(/\s*$/gi, '');  // trim trailing spaces
    console.log('NEXE moveList=' + moveList);
    var moves = moveList.split(' ');
    console.log('moves=' + moves);
    clearContext(Chess.ctxScratch, Chess.canvasScratch);
    moves.forEach(function(el) {
        coords = el.split(':');
        console.log('x=' + coords[0] + ' y=' + coords[1]);
        // highlight a valid move
        theBoard.highlight(coords[0], coords[1], Chess.ctxScratch);
      }
    );
  }
};

Chess.doneMoveHandler = function() {
  var thePiece = theBoard.contents.getPiece(1, 1);
  console.log(' random piece: ' + thePiece.toString());
  var boardString = theBoard.contents.toString();
  console.log('Chess: ' + Chess + ' theBoard.contents:' + theBoard.contents +
              ' boardString: ' + boardString);
  alert(boardString);
};

Chess.updateBoardHandler = function() {
  var textField = document.getElementById('chessText');
  alert('Text is ' + textField.value);
  theBoard.contents.setContents(textField.value);
};

Chess.updateTextHandler = function() {
  var textField = document.getElementById('chessText');
  var boardString = theBoard.contents.toString();
  textField.value = boardString;
};

theBoard = new Chess.Board();
if (Chess.canvasScratch != undefined) {
  Chess.canvasScratch.onmousedown = Chess.mouseDownHandler;
  setInterval('theBoard.drawPieces(Chess.ctxPieces)', 1000);
}
