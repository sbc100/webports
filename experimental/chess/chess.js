//
// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.
//
// NOTE:  Images are public domain .png files from
//        http://www.pdclipart.org/thumbnails.php?album=121
//

// Create a namespace object
var Chess = Chess || {}
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
// Piece class
//
Chess.Piece = function(color, pieceType) {
  this.color_ = color;
  this.pieceType_ = pieceType;
}
Chess.Piece.prototype.getColor = function () {
  return this.color_;
}
Chess.Piece.prototype.getPieceType = function () {
  return this.pieceType_;
}
Chess.Piece.prototype.toString = function() {
  var theString;
  var colorArray = ['BLACK', 'WHITE'];
  var pieceArray = ['Pawn', 'Rook', 'Knight', 'Bishop', 'Queen', 'King', 'None'];
  theString = colorArray[this.color_] + ' ' + pieceArray[this.pieceType_];
  return theString;
}
Chess.Piece.prototype.toChar = function() {
  // convert Pawn to p, Rook to r, Knight to h (horse), Bishop to b,
  //   Queen to q, and King to k
  // Black is just uppercase of this.
  var whitePieceArray = ['p', 'r', 'h', 'b', 'q', 'k'];
  var blackPieceArray = ['P', 'R', 'H', 'B', 'Q', 'K'];
  if (this.color_ == Chess.ColorType.BLACK) {
    return blackPieceArray[this.pieceType_];
  } else {
    return whitePieceArray[this.pieceType_];
  }
}

//
// BoardContents class
//
Chess.BoardContents = function(columns, rows) {
  this.columns_ = columns;
  this.rows_ = rows;
  this.pieceArray_ = new Array();
  for (var i=0; i < this.row_ * this.columns_; ++i) {
    this.pieceArray_[i] = null; // initially null references
  } 
}

Chess.BoardContents.prototype.getIndex = function(column, row) {
  return row * this.columns_ + column;
}

Chess.BoardContents.prototype.update = function(column, row, theUnit) {
  var index = this.getIndex(column, row);
  this.pieceArray_[index] = theUnit;
}

Chess.BoardContents.prototype.getPiece = function(column, row) {
  var index = this.getIndex(column, row);
  return this.pieceArray_[index];
}

Chess.BoardContents.prototype.toString = function() {
  var theString = "";
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
}

Chess.BoardContents.prototype.defaultInit = function() {
  // black starting locations
  this.pieceArray_[this.getIndex(0,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(4,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.KING);
  this.pieceArray_[this.getIndex(3,0)] =
    new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.QUEEN);
  for (var i=0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i,1)] =
      new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.PAWN);
  }

  // white starting locations
  this.pieceArray_[this.getIndex(0,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(4,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.KING);
  this.pieceArray_[this.getIndex(3,7)] =
    new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.QUEEN);
  for (var i=0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i,6)] =
      new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.PAWN);
  }
}

//
// Board class -- draws the board squares and chess notation around the side.
//
Chess.Board = function() {
  Chess.Board.pixelsPerSquare = 80;
  this.Init(); //defined below!
}

Chess.Board.pixelsPerSquare = 80;
Chess.Board.borderPixels = 130;
Chess.Board.gapPixels = 1; //gap between squares
Chess.Board.WHITE = 'rgb(255,240,240)';
Chess.Board.BLACK = 'rgb(139,137,137)';
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
}

//
// Given a row or column, convert to coordinate (pixel) value.
// 
Chess.Board.prototype.gridToCoord = function(grid) {
  if (grid < 0 || grid > Chess.boardSize) {
    return 0;
  }
  return Chess.Board.borderPixels +
    Chess.Board.pixelsPerSquare * grid;
}

// use gridToCoord and image size to get x coord
Chess.Board.prototype.getPieceX = function(grid, image) {
  return this.gridToCoord(grid) +
         (Chess.Board.pixelsPerSquare - image.width)/2;
}
// use gridToCoord and image size to get y coord
Chess.Board.prototype.getPieceY = function(grid, image) {
  return this.gridToCoord(grid) +
         (Chess.Board.pixelsPerSquare - image.height)/2;
}

Chess.Board.prototype.getGridClicked = function(coord) {
  if (coord < Chess.Board.borderPixels) {
    return -1;
  }
  if (coord > Chess.Board.borderPixels
      + Chess.boardSize * Chess.Board.pixelsPerSquare) {
    return -1;
  }
  grid = Math.floor(((coord - Chess.Board.borderPixels) /
                      Chess.Board.pixelsPerSquare));
  return grid;
}

Chess.Board.prototype.convertColumnToLetter = function(coord) {
  if (coord < 0 || coord >= Chess.boardSize) {
    return "?column?";
  }
  return Chess.Board.letterArray[coord];
}
Chess.Board.prototype.convertRowToChessRow = function(row) {
  if (row < 0 || row >= Chess.boardSize) {
    return "?row?";
  }
  return 8 - row;
}

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
                      Chess.Board.pixelsPerSquare - Chess.Board.gapPixels*2,
                      Chess.Board.pixelsPerSquare - Chess.Board.gapPixels*2);
    // console.log('Filling col ' + column + ' row ' + row + ' @ '
                // + topLeftX + ':' + topLeftY + '  ' + color);
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
    ctxBoard.font = "14pt Arial";
    topLeftX = column * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels
               + Chess.Board.pixelsPerSquare/3;
    topLeftY = Chess.Board.borderPixels - 20;
    ctxBoard.strokeText(Chess.Board.letterArray[column], topLeftX, topLeftY);
    // console.log(' text ' + Chess.Board.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
    topLeftY = Chess.boardSize * Chess.Board.pixelsPerSquare +
               Chess.Board.borderPixels + 40;
    ctxBoard.strokeText(Chess.Board.letterArray[column], topLeftX, topLeftY);
    // console.log(' text ' + Chess.Board.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
  }
  for (row = 0; row < Chess.boardSize; ++row) {
    var chess_row = 8 - row;
    topLeftX = Chess.Board.borderPixels - 20;
    topLeftY = row * Chess.Board.pixelsPerSquare + Chess.Board.borderPixels + Chess.Board.pixelsPerSquare/2;
    // console.log(topLeftX);
    // console.log(topLeftY);
    // console.log('text: ' + row +' @' + topLeftX + ':' + topLeftY);
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
    topLeftX = Chess.boardSize * Chess.Board.pixelsPerSquare +
               Chess.Board.borderPixels + 20;
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
  }

  ctxBoard.fillStyle = fillStyle;
  ctxBoard.strokeStyle = strokeStyle;
  ctxBoard.font = font;
}

Chess.Board.prototype.Init = function() {
 Chess.canvasScratch = document.getElementById("canvasScratch");
 Chess.canvasPieces = document.getElementById("canvasPieces");
 Chess.canvasBk = document.getElementById("canvasBk");

 Chess.ctxScratch = canvasScratch.getContext("2d");
 Chess.ctxPieces = canvasPieces.getContext("2d");
 Chess.ctxBk = canvasBk.getContext("2d");

 this.drawBoard(Chess.Board.borderPixels, Chess.Board.borderPixels, Chess.ctxBk);

 Chess.whitePawnImage = new Image();
 Chess.whitePawnImage.src = "chess_piece_2_white_pawn.png";
 Chess.whiteKnightImage = new Image();
 Chess.whiteKnightImage.src = "chess_piece_2_white_knight.png";
 Chess.whiteRookImage = new Image();
 Chess.whiteRookImage.src = "chess_piece_2_white_rook.png";
 Chess.whiteBishopImage = new Image();
 Chess.whiteBishopImage.src = "chess_piece_2_white_bishop.png";
 Chess.whiteKingImage = new Image();
 Chess.whiteKingImage.src = "chess_piece_2_white_king.png";
 Chess.whiteQueenImage = new Image();
 Chess.whiteQueenImage.src = "chess_piece_2_white_queen.png";
 
 Chess.blackPawnImage = new Image();
 Chess.blackPawnImage.src = "chess_piece_2_black_pawn.png";
 Chess.blackKnightImage = new Image();
 Chess.blackKnightImage.src = "chess_piece_2_black_knight.png";
 Chess.blackRookImage = new Image();
 Chess.blackRookImage.src = "chess_piece_2_black_rook.png";
 Chess.blackBishopImage = new Image();
 Chess.blackBishopImage.src = "chess_piece_2_black_bishop.png";
 Chess.blackKingImage = new Image();
 Chess.blackKingImage.src = "chess_piece_2_black_king.png";
 Chess.blackQueenImage = new Image();
 Chess.blackQueenImage.src = "chess_piece_2_black_queen.png";

 // Chess.blackQueenImage.onload = function() {
 //  this.drawPieces(Chess.ctxPieces);
 // };

 this.contents = new Chess.BoardContents(Chess.boardSize,
   Chess.boardSize); // typically 8x8 board
 this.contents.defaultInit();
}


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
}

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
}

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
    boardString += 'Column ' + column + ' Row ' + row;
    message += boardString;
  }
  if (x != -1 && y != -1) {
    alert(message);
  }
}

Chess.doneMoveHandler = function() {
  var thePiece = theBoard.contents.getPiece(1,1);
  console.log(' random piece: ' + thePiece.toString());
  var boardString = theBoard.contents.toString();
  console.log('Chess: ' + Chess + ' theBoard.contents:'+theBoard.contents +
              ' boardString: ' + boardString);
  alert(boardString);
}

theBoard = new Chess.Board();
// Chess.Init();
Chess.canvasScratch.onmousedown = Chess.mouseDownHandler;
setInterval( "theBoard.drawPieces(Chess.ctxPieces)", 1000);
