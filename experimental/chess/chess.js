//
// NOTE:  Images are public domain .png files from
//        http://www.pdclipart.org/thumbnails.php?album=121
//
// COPYRIGHT: Google NativeClient Team, 2011
//

chessBoard = {};

chessBoard.ColorType = {
  BLACK: 0,
  WHITE: 1
};

chessBoard.PieceType = {
  PAWN: 0,
  ROOK: 1,
  KNIGHT: 2,
  BISHOP: 3,
  QUEEN: 4,
  KING: 5,
  NONE: 6
};

chessBoard.Piece = function(color, pieceType) {
  this.color_ = color;
  this.pieceType_ = pieceType;
}
chessBoard.Piece.prototype.getColor = function () {
  return this.color_;
}
chessBoard.Piece.prototype.getPieceType = function () {
  return this.pieceType_;
}
chessBoard.Piece.prototype.toString = function() {
  var theString;
  var colorArray = ['BLACK', 'WHITE'];
  var pieceArray = ['Pawn', 'Rook', 'Knight', 'Bishop', 'Queen', 'King', 'None'];
  theString = colorArray[this.color_] + ' ' + pieceArray[this.pieceType_];
  return theString;
}
chessBoard.Piece.prototype.toChar = function() {
  // convert Pawn to p, Rook to r, Knight to h (horse), Bishop to b,
  //   Queen to q, and King to k
  // Black is just uppercase of this.
  var whitePieceArray = ['p', 'r', 'h', 'b', 'q', 'k'];
  var blackPieceArray = ['P', 'R', 'H', 'B', 'Q', 'K'];
  if (this.color_ == chessBoard.ColorType.BLACK) {
    return blackPieceArray[this.pieceType_];
  } else {
    return whitePieceArray[this.pieceType_];
  }
}

chessBoard.BoardContents = function(columns, rows) {
  this.columns_ = columns;
  this.rows_ = rows;
  this.pieceArray_ = new Array();
  for (var i=0; i < this.row_ * this.columns_; ++i) {
    this.pieceArray_[i] = null; // initially null references
  } 
}

chessBoard.BoardContents.prototype.getIndex = function(column, row) {
  return row * this.columns_ + column;
}

chessBoard.BoardContents.prototype.update = function(column, row, theUnit) {
  var index = this.getIndex(column, row);
  this.pieceArray_[index] = theUnit;
}

chessBoard.BoardContents.prototype.getPiece = function(column, row) {
  var index = this.getIndex(column, row);
  return this.pieceArray_[index];
}

chessBoard.BoardContents.prototype.toString = function() {
  var theString = "";
  for (var row = 0; row < chessBoard.boardSize; ++row) {
    for (var column = 0; column < chessBoard.boardSize; ++column) {
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

chessBoard.BoardContents.prototype.defaultInit = function() {
  // black starting locations
  this.pieceArray_[this.getIndex(0,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(3,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.KING);
  this.pieceArray_[this.getIndex(4,0)] =
    new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.QUEEN);
  for (var i=0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i,1)] =
      new chessBoard.Piece(chessBoard.ColorType.BLACK, chessBoard.PieceType.PAWN);
  }

  // white starting locations
  this.pieceArray_[this.getIndex(0,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.ROOK);
  this.pieceArray_[this.getIndex(7,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.ROOK);

  this.pieceArray_[this.getIndex(1,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.KNIGHT);
  this.pieceArray_[this.getIndex(6,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.KNIGHT);

  this.pieceArray_[this.getIndex(2,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.BISHOP);
  this.pieceArray_[this.getIndex(5,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.BISHOP);

  this.pieceArray_[this.getIndex(3,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.KING);
  this.pieceArray_[this.getIndex(4,7)] =
    new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.QUEEN);
  for (var i=0; i < 8; ++i) {
    this.pieceArray_[this.getIndex(i,6)] =
      new chessBoard.Piece(chessBoard.ColorType.WHITE, chessBoard.PieceType.PAWN);
  }
}


chessBoard.pixelsPerSquare = 80;
chessBoard.borderPixels = 130;
chessBoard.textOffset = 10;
chessBoard.gapPixels = 1; //gap between squares
chessBoard.WHITE = 'rgb(255,240,240)';
chessBoard.BLACK = 'rgb(139,137,137)';
chessBoard.topLeft = chessBoard.WHITE;
chessBoard.boardSize = 8;
chessBoard.letterArray = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
chessBoard.otherColor = function(color) {
  // console.log('color=' + color);
  if (color == chessBoard.BLACK) {
    return chessBoard.WHITE;
  }
  else if (color == chessBoard.WHITE) {
    return chessBoard.BLACK;
  } else {
    console.log('ERROR IN otherColor');
  }
}

//
// Given a row or column, convert to coordinate (pixel) value.
// 
chessBoard.gridToCoord = function(grid) {
  if (grid < 0 || grid > chessBoard.boardSize) {
    return 0;
  }
  return chessBoard.borderPixels +
    chessBoard.pixelsPerSquare * grid;
}

// use gridToCoord and image size to get x coord
chessBoard.getPieceX = function(grid, image) {
  return chessBoard.gridToCoord(grid) +
         (chessBoard.pixelsPerSquare - image.width)/2;
}
// use gridToCoord and image size to get y coord
chessBoard.getPieceY = function(grid, image) {
  return chessBoard.gridToCoord(grid) +
         (chessBoard.pixelsPerSquare - image.height)/2;
}

chessBoard.getGridClicked = function(coord) {
  if (coord < chessBoard.borderPixels) {
    return -1;
  }
  if (coord > chessBoard.borderPixels
      + chessBoard.boardSize * chessBoard.pixelsPerSquare) {
    return -1;
  }
  grid = Math.floor(((coord - chessBoard.borderPixels) /
                      chessBoard.pixelsPerSquare));
  return grid;
}
chessBoard.convertColumnToLetter = function(coord) {
  if (coord < 0 || coord >= chessBoard.boardSize) {
    return "?column?";
  }
  return chessBoard.letterArray[coord];
}
chessBoard.convertRowToChessRow = function(row) {
  if (row < 0 || row >= chessBoard.boardSize) {
    return "?row?";
  }
  return 8 - row;
}

chessBoard.getRowClicked = function(ycoord) {
}
chessBoard.drawBoard = function(pixelsPerSquare, leftBorder, topBorder, ctxBoard) {
  var column, row, color;
  color = chessBoard.topLeft;
  var topLeftX, topLeftY;

  var font = ctxBoard.font;  
  var fillStyle = ctxBoard.fillStyle;
  var strokeStyle = ctxBoard.strokeStyle;
  ctxBoard.strokeStyle = chessBoard.BLACK;

  column = 0;
  row = 0;
  for (var index = 0; index < chessBoard.boardSize * chessBoard.boardSize; ++index) {

    // get top left corner of square
    topLeftX = column * chessBoard.pixelsPerSquare + chessBoard.borderPixels;
    topLeftY = row * chessBoard.pixelsPerSquare + chessBoard.borderPixels;
    // set color
    ctxBoard.fillStyle = color;
    ctxBoard.beginPath();
    ctxBoard.fillRect(topLeftX + chessBoard.gapPixels,
                      topLeftY + chessBoard.gapPixels,
                      chessBoard.pixelsPerSquare - chessBoard.gapPixels*2,
                      chessBoard.pixelsPerSquare - chessBoard.gapPixels*2);
    // console.log('Filling col ' + column + ' row ' + row + ' @ '
                // + topLeftX + ':' + topLeftY + '  ' + color);
    ctxBoard.closePath(); 
    color = chessBoard.otherColor(color);
    ++column;
    if (column == 8) {
      ++row;
      column = 0;
      color = chessBoard.otherColor(color);
    }
  }

  // now draw labels
  ctxBoard.strokeStyle = chessBoard.BLACK;
  for (column = 0; column < chessBoard.boardSize; ++column) {
    ctxBoard.font = "14pt Arial";
    topLeftX = column * chessBoard.pixelsPerSquare + chessBoard.borderPixels
               + chessBoard.pixelsPerSquare/3;
    topLeftY = chessBoard.borderPixels - 20;
    ctxBoard.strokeText(chessBoard.letterArray[column], topLeftX, topLeftY);
    // console.log(' text ' + chessBoard.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
    topLeftY = chessBoard.boardSize * chessBoard.pixelsPerSquare +
               chessBoard.borderPixels + 40;
    ctxBoard.strokeText(chessBoard.letterArray[column], topLeftX, topLeftY);
    // console.log(' text ' + chessBoard.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
  }
  for (row = 0; row < chessBoard.boardSize; ++row) {
    var chess_row = 8 - row;
    topLeftX = chessBoard.borderPixels - 20;
    topLeftY = row * chessBoard.pixelsPerSquare + chessBoard.borderPixels + chessBoard.pixelsPerSquare/2;
    // console.log(topLeftX);
    // console.log(topLeftY);
    // console.log('text: ' + row +' @' + topLeftX + ':' + topLeftY);
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
    topLeftX = chessBoard.boardSize * chessBoard.pixelsPerSquare +
               chessBoard.borderPixels + 20;
    ctxBoard.strokeText(chess_row + '', topLeftX, topLeftY);
  }

  ctxBoard.fillStyle = fillStyle;
  ctxBoard.strokeStyle = strokeStyle;
  ctxBoard.font = font;
}

chessBoard.init = function() {
 chessBoard.canvasScratch = document.getElementById("canvasScratch");
 chessBoard.canvasPieces = document.getElementById("canvasPieces");
 chessBoard.canvasBk = document.getElementById("canvasBk");

 chessBoard.ctxScratch = canvasScratch.getContext("2d");
 chessBoard.ctxPieces = canvasPieces.getContext("2d");
 chessBoard.ctxBk = canvasBk.getContext("2d");

 chessBoard.drawBoard(chessBoard.pixelsPerSquare, chessBoard.borderPixels,
                      chessBoard.borderPixels, chessBoard.ctxBk);

 chessBoard.whitePawnImage = new Image();
 chessBoard.whitePawnImage.src = "chess_piece_2_white_pawn.png";
 chessBoard.whiteKnightImage = new Image();
 chessBoard.whiteKnightImage.src = "chess_piece_2_white_knight.png";
 chessBoard.whiteRookImage = new Image();
 chessBoard.whiteRookImage.src = "chess_piece_2_white_rook.png";
 chessBoard.whiteBishopImage = new Image();
 chessBoard.whiteBishopImage.src = "chess_piece_2_white_bishop.png";
 chessBoard.whiteKingImage = new Image();
 chessBoard.whiteKingImage.src = "chess_piece_2_white_king.png";
 chessBoard.whiteQueenImage = new Image();
 chessBoard.whiteQueenImage.src = "chess_piece_2_white_queen.png";
 
 chessBoard.blackPawnImage = new Image();
 chessBoard.blackPawnImage.src = "chess_piece_2_black_pawn.png";
 chessBoard.blackKnightImage = new Image();
 chessBoard.blackKnightImage.src = "chess_piece_2_black_knight.png";
 chessBoard.blackRookImage = new Image();
 chessBoard.blackRookImage.src = "chess_piece_2_black_rook.png";
 chessBoard.blackBishopImage = new Image();
 chessBoard.blackBishopImage.src = "chess_piece_2_black_bishop.png";
 chessBoard.blackKingImage = new Image();
 chessBoard.blackKingImage.src = "chess_piece_2_black_king.png";
 chessBoard.blackQueenImage = new Image();
 chessBoard.blackQueenImage.src = "chess_piece_2_black_queen.png";

 chessBoard.blackQueenImage.onload = function() {
   chessBoard.drawPieces(chessBoard.ctxPieces);
 };

 chessBoard.contents = new chessBoard.BoardContents(chessBoard.boardSize,
   chessBoard.boardSize); // typically 8x8 board
 chessBoard.contents.defaultInit();
  
}


chessBoard.drawPiece = function(ctx, column, row, pieceType, colorType) {
  var theImage;
  switch (pieceType) {
    case chessBoard.PieceType.PAWN:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whitePawnImage;
      } else {
        theImage = chessBoard.blackPawnImage;
      } 
      break;
    case chessBoard.PieceType.ROOK:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whiteRookImage;
      } else {
        theImage = chessBoard.blackRookImage;
      }
      break;
    case chessBoard.PieceType.KNIGHT:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whiteKnightImage;
      } else {
        theImage = chessBoard.blackKnightImage;
      }
      break;
    case chessBoard.PieceType.BISHOP:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whiteBishopImage;
      } else {
        theImage = chessBoard.blackBishopImage;
      }
      break;
    case chessBoard.PieceType.QUEEN:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whiteQueenImage;
      } else {
        theImage = chessBoard.blackQueenImage;
      }
      break;
    case chessBoard.PieceType.KING:
      if (colorType == chessBoard.ColorType.WHITE) {
        theImage = chessBoard.whiteKingImage;
      } else {
        theImage = chessBoard.blackKingImage;
      }
      break;
  }
  ctx.drawImage(theImage, chessBoard.getPieceX(column, theImage),
                chessBoard.getPieceY(row, theImage));
}

chessBoard.drawPieces = function(ctx) {
  console.log('drawPieces...'); 
  var column, row;
  for (column = 0; column < chessBoard.boardSize; ++column) {
    for (row = 0; row < chessBoard.boardSize; ++row) {
      var thePiece = chessBoard.contents.getPiece(column, row);
      if (thePiece) {
        chessBoard.drawPiece(ctx, column, row, thePiece.getPieceType(),
                             thePiece.getColor());
      }
    }
  }
}

chessBoard.mouseDownHandler = function(e) {
  var x = e.offsetX;
  var y = e.offsetY;
  var column = chessBoard.getGridClicked(x);
  var row = chessBoard.getGridClicked(y);
  var thePiece = chessBoard.contents.getPiece(column, row);
  var message = 'You clicked on column ' + column + ' row ' + row +
                ' chess notation: ' + chessBoard.convertColumnToLetter(column) +
                chessBoard.convertRowToChessRow(row) + '\n';
  if (thePiece) {
    message += ' That space contains ' + thePiece.toString() + ' \n';
    var boardString = chessBoard.contents.toString();
    boardString += 'Column ' + column + ' Row ' + row;
    message += boardString;
  }
  if (x != -1 && y != -1) {
    alert(message);
  }
}

chessBoard.doneMoveHandler = function() {
  var thePiece = chessBoard.contents.getPiece(1,1);
  console.log(' random piece: ' + thePiece.toString());
  var boardString = chessBoard.contents.toString();
  console.log('chessBoard: ' + chessBoard + ' chessBoard.contents:'+chessBoard.contents +
              ' boardString: ' + boardString);
  alert(boardString);
}


chessBoard.init();
chessBoard.canvasScratch.onmousedown = chessBoard.mouseDownHandler;
setInterval( "chessBoard.drawPieces(chessBoard.ctxPieces)", 1000);
