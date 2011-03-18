
chessBoard = {};

chessBoard.pixelsPerSquare = 80;
chessBoard.borderPixels = 130;
chessBoard.textOffset = 10;
chessBoard.gapPixels = 1; //gap between squares
chessBoard.WHITE = 'rgb(255,240,240)';
chessBoard.BLACK = 'rgb(139,137,137)';
chessBoard.topLeft = chessBoard.BLACK;
chessBoard.boardSize = 8;
chessBoard.letterArray = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
chessBoard.otherColor = function(color) {
  console.log('color=' + color);
  if (color == chessBoard.BLACK) {
    return chessBoard.WHITE;
  }
  else if (color == chessBoard.WHITE) {
    return chessBoard.BLACK;
  } else {
    console.log('ERROR IN otherColor');
  }
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
    console.log(' text ' + chessBoard.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
    topLeftY = chessBoard.boardSize * chessBoard.pixelsPerSquare +
               chessBoard.borderPixels + 40;
    ctxBoard.strokeText(chessBoard.letterArray[column], topLeftX, topLeftY);
    console.log(' text ' + chessBoard.letterArray[column] + ' at ' + topLeftX + ':' + topLeftY);
  }
  for (row = 0; row < chessBoard.boardSize; ++row) {
    var chess_row = 8 - row;
    topLeftX = chessBoard.borderPixels - 20;
    topLeftY = row * chessBoard.pixelsPerSquare + chessBoard.borderPixels + chessBoard.pixelsPerSquare/2;
    console.log(topLeftX);
    console.log(topLeftY);
    console.log('text: ' + row +' @' + topLeftX + ':' + topLeftY);
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
}

chessBoard.mouseDownHandler = function(e) {
  var x = e.offsetX;
  var y = e.offsetY;

  var column = chessBoard.getGridClicked(x);
  var row = chessBoard.getGridClicked(y);
  var message = 'You clicked on column ' + column + ' row ' + row +
                ' chess notation: ' + chessBoard.convertColumnToLetter(column) +
                chessBoard.convertRowToChessRow(row);
  if (x != -1 && y != -1) {
    alert(message);
  }
}

chessBoard.init();
chessBoard.canvasScratch.onmousedown = chessBoard.mouseDownHandler;
