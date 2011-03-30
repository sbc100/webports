
// Provide the hexgame namespace
hexgame = {};

hexgame.LEFT_OFFSET = 100;
hexgame.TOP_OFFSET = 50;
hexgame.HEX_SIZE = 50;
hexgame.HALF_HEX_SIZE = hexgame.HEX_SIZE / 2;
hexgame.Cos60 = 0.50;
hexgame.Sin60 = 0.866025403784439;
var X_DELTA = hexgame.HEX_SIZE * hexgame.Cos60;
var Y_DELTA = hexgame.HEX_SIZE * hexgame.Sin60;
var Y_HEX_SIZE = 2 * Y_DELTA;
var X_HEX_SIZE = 2 * X_DELTA + hexgame.HALF_HEX_SIZE;
var UNIT_Y_ODD_COLUMN_OFFSET = 46;
var UNIT_SIZE = hexgame.HEX_SIZE * 1.10; //height and width of unit (pixels)

var canvas;
var canvas2;
var canvasBk;
var ctx;
var ctx2;
var ctxBk;
var x = 75;
var y = 50;
var dx = 5;
var dy = 3;
var WIDTH = 900;
var HEIGHT = 800;
var dragok = false;

var maxGrid = 12; // how many 'columns' of hexes
var maxRows = 8;  // how many 'rows' of hexes
var redColor = 'rgb(255,182,193)';
var greenColor = 'rgb(0,170,0)';

var gSide = new Array();
var rSide = new Array();
var whoseTurn = 'G'; // turn in 'G' or 'R'
var theSide = gSide; //refers to gSide or rSide
var otherSide = rSide;
var destroyedUnits = new Array();
var turnNumber = 1;
var hexesToAttackResult;
var treeImage;
var desertImage;
var mountainImage;
var cityImage;
var selectedUnit = undefined;
var moveArray = undefined; //set of legal moves for selectedUnit
var theBoard;

function clearContext(theContext) {
  theContext.beginPath();
  theContext.clearRect(0, 0, canvas.width, canvas.height);
  theContext.closePath();
}

function ErrorMessage(message) {
  alert(message);
}

function getCenterX(column) {
  return (column - 1) * 73 + 96;
}

function getCenterY(column, row) {
  var yCoord = (row - 1) * 85 + 40;
  if (column % 2 == 0) {
    yCoord = yCoord + 45;
  }
  return yCoord;
}

function Unit(color, type, attack, move, x, y, width, height) {
  this.color_ = color;
  this.type_ = type;
  this.attack_ = attack;
  this.move_ = move;
  this.x_ = x;
  this.y_ = y;
  this.destroyed_ = false;
  this.doneMove_ = false;
  // set upperLeft, bottomRight to 0 until drawn
  this.upperLeftX_ = 0;
  this.upperLeftY_ = 0;
  this.bottomRightX_ = 0;
  this.bottomRightY_ = 0;
  if (width == undefined) {
    this.width_ = width;
  } else {
    this.width_ = UNIT_SIZE;
  }
  if (height == undefined) {
    this.height_ = height;
  } else {
    this.height_ = UNIT_SIZE;
  }
  this.height_ = height;
  this.attackedUnit_ = undefined;
  this.attackingUnits_ = new Array();
  if (Unit.prototype.count == undefined) {
    Unit.prototype.count = 0;
  }
  Unit.prototype.count++;
  this.id_ = Unit.prototype.count;
}

Unit.prototype.SetNewLocation = function(newX, newY) {
  var stringData = 'POST_UNIT_LOCATION ' + this.id_ + ' ' +
    newX + ' ' + newY;
  var result = naclModule.postToNexe(stringData);
  console.log(' result of POST_UNIT_LOCATION ' + result);
  this.x_ = newX;
  this.y_ = newY;
};
Unit.prototype.SetDestroyed = function() {
  // post a message to NEXE whenever this happens
  var stringData = 'POST_DESTROYED ' + this.id_;
  var result = naclModule.postToNexe(stringData);
  console.log(' result of POST_DESTROYED ' + result);
  this.destroyed_ = true;
  // move this unit into destroyedUnits
  destroyedUnits.push(this);
  removeUnitFromArray(gSide, this);
  removeUnitFromArray(rSide, this);
};
Unit.prototype.Column = function() {
  return this.x_;
};
Unit.prototype.Row = function() {
  return this.y_;
};
Unit.prototype.Attack = function() {
  return this.attack_;
};
Unit.prototype.Id = function() {
  return this.id_;
};

Unit.prototype.clearAttackingUnits = function() {
  this.attackingUnits_ = new Array();
};
Unit.prototype.getAttackingUnits = function() {
  return this.attackingUnits_;
};
Unit.prototype.addToAttackingUnits = function(u) {
  for (var i = 0; i < this.attackingUnits_.length; ++i) {
    if (u == this.attackingUnits_[i]) {
      return;
    }
  }
  this.attackingUnits_.push(u);
};

Unit.prototype.setAttackedUnit = function(u) {
  this.attackedUnit_ = u;
};
Unit.prototype.getAttackedUnit = function() {
  return this.attackedUnit_;
};
Unit.prototype.clearAttackedUnit = function() {
  this.attackedUnit_ = undefined;
};

Unit.prototype.doneMove = function() {
  return this.doneMove_;
};
Unit.prototype.setDoneMove = function(doneMove) {
  this.doneMove_ = doneMove;
};
Unit.prototype.toString = function() {
  var strData = '[' + this.id_ + ',' + this.type_ + ',' + this.x_ +
                ',' + this.y_ + ',' + this.attack_ + ',' + this.move_ + ']';
  return strData;
};
Unit.prototype.containsPoint = function(x, y) {
  return (x >= this.upperLeftX_ && x <= this.bottomRightX_ &&
          y >= this.upperLeftY_ && y <= this.bottomRightY_);
};

Unit.prototype.setHexX = function(x) {
  this.x_ = x;
};
Unit.prototype.setHexY = function(y) {
  this.y_ = y;
};
Unit.prototype.draw = function(ctx) {
  if (this.destroyed_) {
    console.log(this.toString() + ' is destroyed');
    return;
  }
  this.drawAt(ctx);
};

// low-level drawing, based on x and y (pixels, not column/row)
Unit.prototype.drawAtXY = function(ctx, x, y) {
  var width = UNIT_SIZE;
  var height = UNIT_SIZE;
  // save globalAlpha and font
  var alpha = ctx.globalAlpha;
  var font = ctx.font;

  // save off upper left, bottom right
  this.upperLeftX_ = x;
  this.upperLeftY_ = y;
  this.bottomRightX_ = x + width;
  this.bottomRightY_ = y + width;
  ctx.beginPath();
  ctx.font = '12pt Arial';
  ctx.globalAlpha = 0.75;
  ctx.fillStyle = this.color_;
  ctx.fillRect(x, y, width, height);
  if (this.type_ == 'INF') {
    ctx.strokeRect(x + 12, y + 10, width * 0.45, height / 3);
    ctx.moveTo(x + 12, y + 10);
    ctx.lineTo(x + 12 + width * 0.45, y + 10 + height / 3);
    ctx.moveTo(x + 12, y + 10 + height / 3);
    ctx.lineTo(x + 12 + width * 0.45, y + 10);
    ctx.stroke();
  } else if (this.type_ == 'ARM') {
    ctx.arc(x + 20, y + 1 + height / 3, height / 10,
            Math.PI * 0.5, Math.PI * 1.5, false);
    ctx.arc(x + 28, y + 1 + height / 3, height / 10,
            Math.PI * 1.5, Math.PI * 0.5, false);
    ctx.strokeRect(x + 12, y + 10, width * 0.45, height / 3);
    ctx.moveTo(x + 20, y + 25);
    ctx.lineTo(x + 28, y + 25);
    ctx.stroke();
  }
  ctx.strokeText(this.attack_ + ' - ' + this.move_, x + 10, y + 45);

  ctx.font = '6pt Courier';
  ctx.strokeText(this.id_, x + 44, y + 10);

  if (this.doneMove_) {
    ctx.strokeText('Moved', x + 4, y + 5);
  }
  ctx.closePath();
  // restore original settings
  ctx.font = font;
  ctx.globalAlpha = alpha;
};

Unit.prototype.drawAt = function(ctx) {
  var xCoord = hexgame.LEFT_OFFSET + X_HEX_SIZE * this.x_ + X_HEX_SIZE / 3;
  var yCoord = hexgame.TOP_OFFSET + Y_HEX_SIZE * this.y_ - Y_DELTA;

  if (this.x_ % 2 == 1) yCoord += Y_DELTA * 2;

  if (this.x_ % 2 == 0) {
    yCoord = yCoord + UNIT_Y_ODD_COLUMN_OFFSET;
  }
  this.drawAtXY(ctx, xCoord, yCoord);
};

// look for theUnit in theArray and use splice to remove it
// if found.  return true if found, false if not found
function removeUnitFromArray(theArray, theUnit) {
  for (var idx = 0; idx < theArray.length; ++idx) {
    if (theArray[idx] == theUnit) {
      theArray.splice(idx, 1);
      return true;
    }
  }
  return false;
}

function getHexX(column, row) {
  var x = hexgame.LEFT_OFFSET + X_HEX_SIZE * (column);
  return x;
}
function getHexY(column, row) {
  var y = hexgame.TOP_OFFSET + Y_HEX_SIZE * row;
  if (column % 2 == 1) y += Y_DELTA;
  return y;
}
function getHexX_mid(column, row) {
  return getHexX(column, row) + X_DELTA;
}
function getHexY_mid(column, row) {
  return getHexY(column, row) + Y_DELTA * 1.1;
}
function getHexYup(column, row) {
  return getHexY(column, row) - Y_DELTA / 3;
}

// Convert an xCoord to a column
function xToColumn(xCoord) {
  // TODO: handle the 'pointy parts' of a hex
  var column = Math.floor((xCoord - hexgame.LEFT_OFFSET) / X_HEX_SIZE);
  return column;
}

// Convert a column, yCoord to a row
function yToRow(column, yCoord) {
  // TODO: handle the 'pointy parts' of a hex
  var columnTop = yCoord - hexgame.TOP_OFFSET;
  if (column % 2 == 1) {
    columnTop -= Y_DELTA;
  }
  return Math.floor(columnTop / Y_HEX_SIZE);
}

// note: Uses ctx.fillColor to fill, unless dontFill is defined
function drawHex(ctx, column, row, dontFill) {
  var x = hexgame.LEFT_OFFSET + X_HEX_SIZE * column;
  var y = hexgame.TOP_OFFSET + Y_HEX_SIZE * row;
  if (column % 2 == 1) y += Y_DELTA;
  y += hexgame.HALF_HEX_SIZE;
  ctx.beginPath();
  ctx.moveTo(x, y);
  var lineThickness = ctx.lineThickness;
  if (dontFill != undefined) {
    ctx.lineThickness = dontFill;
  }
  x += X_DELTA;
  y += Y_DELTA;
  ctx.lineTo(x, y);
  x += hexgame.HEX_SIZE;
  ctx.lineTo(x, y);
  x += X_DELTA;
  y -= Y_DELTA;
  ctx.lineTo(x, y);
  x -= X_DELTA;
  y -= Y_DELTA;
  ctx.lineTo(x, y);
  x -= hexgame.HEX_SIZE;
  ctx.lineTo(x, y);
  x -= X_DELTA;
  y += Y_DELTA;
  ctx.lineTo(x, y);
  if (dontFill == undefined) {
    ctx.stroke();
    ctx.fill();
  } else {
    // rather than fill, draw lines across middle of hex
    x += X_DELTA;
    y -= Y_DELTA;
    ctx.moveTo(x, y);
    x += hexgame.HEX_SIZE;
    y += Y_DELTA * 2;
    ctx.lineTo(x, y);
    x -= hexgame.HEX_SIZE;
    ctx.moveTo(x, y);
    x += hexgame.HEX_SIZE;
    y -= Y_DELTA * 2;
    ctx.lineTo(x, y);
    ctx.stroke();
  }
  ctx.closePath();
  ctx.lineThickness = lineThickness;
}


function Board(columns, rows) {
  this.columns_ = columns;
  this.rows_ = rows;
  this.hexColumn_ = new Array();
  for (var i = 0; i < columns; ++i) {
    this.hexColumn_[i] = new Array();
    for (var j = 0; j < rows; ++j) {
      this.hexColumn_[i][j] = Board.HexType.CLEAR;
    }
  }
  this.turnState_ = 0;
}

/**
 * The values used for Board status to hex types.
 */
Board.HexType = {
  CLEAR: 0,
  FOREST: 1,
  DESERT: 2,
  HILL: 3,
  MOUNTAIN: 4,
  SEA: 5,
  CITY: 6,
  IMPASSABLE: 7
};

Board.TurnState = {
  MOVING: 0,
  ATTACKING: 1,
  RESOLVING: 2,
  REVIEWING: 3
};

Board.prototype.doneMoving = function() {
  this.turnState_ = Board.TurnState.ATTACKING;
};
Board.prototype.doneAttacking = function() {
  this.turnState_ = Board.TurnState.RESOLVING;
};
Board.prototype.doneResolving = function() {
  this.turnState_ = Board.TurnState.MOVING;
};
Board.prototype.getTurnState = function() {
  return this.turnState_;
};
Board.prototype.getTurnStateString = function() {
  switch (this.turnState_) {
    case Board.TurnState.MOVING:
      return 'Moving';
    case Board.TurnState.ATTACKING:
      return 'Attacking';
    case Board.TurnState.RESOLVING:
      return 'Resolving';
    case Board.TurnState.REVIEWING:
      return 'Reviewing';
    default:
      return '???';
  }
};

Board.prototype.setHex = function(column, row, hexType) {
  this.hexColumn_[column][row] = hexType;
};
Board.prototype.setCityName = function(column, row, name) {
  var key = '' + column + ',' + row;
  this[key] = name;
  console.log('key=' + key);
};
Board.prototype.getCityName = function(column, row, name) {
  var key = '' + column + ',' + row;
  console.log('getKEY' + key);
  return this[key];
};
Board.prototype.getHex = function(column, row) {
  return this.hexColumn_[column][row];
};
Board.prototype.postMsg = function() {
  if (!naclModule) {
    console.log('No NaCl module');
    return;
  }
  var stringData = 'POST_BOARD ' + this.columns_ +
                   ' ' + this.rows_ + ' ';
  for (i = 0; i < this.columns_; ++i) {
    for (j = 0; j < this.rows_; ++j) {
      var hexType = this.hexColumn_[i][j];
      stringData = stringData + hexType + ' ';
    }
  }
  console.log('naclModule=' + naclModule + ' stringData: ' + stringData);
  var result = naclModule.postToNexe(stringData);
  console.log('result = ' + result);
};

Board.prototype.initDraw = function(ctx) {
  this.turnState = Board.TurnState.MOVING;
  console.log('this.columns_: ' + this.columns_ + ' this.rows_:' + this.rows_);
  for (i = 0; i < this.columns_; ++i) {
    for (j = 0; j < this.rows_; ++j) {
      var hexType = this.hexColumn_[i][j];
      var fillColor = 'rgb(255,0,0)';
      if (hexType == Board.HexType.CLEAR) {
        fillColor = 'rgb(255,248,220)';
      } else if (hexType == Board.HexType.FOREST) {
        fillColor = 'rgb(4,100,4)';
      } else if (hexType == Board.HexType.DESERT) {
        fillColor = 'rgb(255,207,100)';
      } else if (hexType == Board.HexType.CITY) {
        fillColor = 'rgb(213,213,213)';
      } else if (hexType == Board.HexType.MOUNTAIN) {
        fillColor = 'rgb(125,65,17)';
      } else if (hexType == Board.HexType.SEA) {
        fillColor = 'rgb(0,0,206)';
      }
      ctx.strokeStyle = 'rgb(0,0,0)';
      ctx.fillStyle = fillColor;
      drawHex(ctx, i, j);

      if (hexType == Board.HexType.FOREST) {
        ctx.globalCompositeOperation = 'source-atop';
        ctx.drawImage(treeImage, getHexX_mid(i, j), getHexYup(i, j));
      } else if (hexType == Board.HexType.DESERT) {
        ctx.globalCompositeOperation = 'source-atop';
        ctx.drawImage(desertImage, getHexX_mid(i, j), getHexYup(i, j));
      } else if (hexType == Board.HexType.MOUNTAIN) {
        ctx.globalCompositeOperation = 'source-atop';
        ctx.drawImage(mountainImage, getHexX_mid(i, j), getHexYup(i, j));
      } else if (hexType == Board.HexType.CITY) {
        ctx.globalCompositeOperation = 'source-atop';
        ctx.drawImage(cityImage, getHexX_mid(i, j), getHexYup(i, j));
        var name = this.getCityName(i, j);
        ctx.beginPath();
        ctx.font = '7pt Arial';
        ctx.strokeText(name, getHexX_mid(i, j), getHexY_mid(i, j));
        ctx.closePath();
      }
      ctx.globalCompositeOperation = 'source-over';
    }
  }
  updateHtmlField('Phase', 'PHASE: ' + theBoard.getTurnStateString());
  updateHtmlField('Turn', 'TURN: ' + whoseTurn);
  updateHtmlField('TurnNumber', 'Turn: Number: ' + turnNumber);
};

function initSides() {
  gSide.push(new Unit(greenColor, 'INF', 6, 3, 1, 2));
  gSide.push(new Unit(greenColor, 'ARM', 8, 6, 0, 0));
  gSide.push(new Unit(greenColor, 'ARM', 8, 6, 0, 1));
  gSide.push(new Unit(greenColor, 'ARM', 8, 6, 0, 2));
  gSide.push(new Unit(greenColor, 'ARM', 8, 6, 0, 4));
  gSide.push(new Unit(greenColor, 'ARM', 6, 6, 0, 3));
  gSide.push(new Unit(greenColor, 'INF', 6, 3, 1, 4));

  rSide.push(new Unit(redColor, 'INF', 6, 4, 0, 6));
  rSide.push(new Unit(redColor, 'INF', 6, 4, 2, 1));
  rSide.push(new Unit(redColor, 'INF', 3, 3, 4, 3));
  rSide.push(new Unit(redColor, 'INF', 3, 3, 5, 2));
  rSide.push(new Unit(redColor, 'INF', 2, 3, 6, 1));
  rSide.push(new Unit(redColor, 'INF', 3, 3, 4, 5));
}

function postUnits() {
  if (!naclModule) {
    console.log('No NaCl module');
    return;
  }
  var stringData = 'POST_UNITS GREEN ';
  gSide.forEach(function(u) {stringData += u.toString();});
  stringData += ' RED ';
  rSide.forEach(function(u) {stringData += u.toString();});

  console.log('naclModule=' + naclModule + ' Unit stringData: ' + stringData);
  var result = naclModule.postToNexe(stringData);
  console.log('result = ' + result);
}

function drawGrid(ctx, column) {
  var x, y, x2, y2;
  var row = 1;
  ctx.beginPath();
  x = (column - 1) * 73 + 69;
  y = 6;
  ctx.moveTo(x, y);
  do {
    if (row % 2 == 1) {
      x2 = x - 22;
    } else {
      x2 = x;
    }
    y2 = y + 42;
    y = y2;
    ctx.lineTo(x2, y2);
    if (x2 == x) {
      //draw right side of hex...
      ctx.lineTo(x2 + 50, y2);
      ctx.lineTo(x2 + 73, y2 - 42);
       // draw line out to the right...
       ctx.lineTo(x2 + 73 + 51, y2 - 42);
       ctx.moveTo(x2 + 73, y2 - 42);
      ctx.lineTo(x2 + 50, y2 - 84);
      ctx.lineTo(x2, y2 - 84);
      ctx.moveTo(x2, y2);
    }
    row++;
  } while (row < maxRows * 2 + 1);
  ctx.moveTo(x2 + 50, y2);
  ctx.lineTo(x2 + 73, y2 + 42);
  ctx.lineTo(x2 + 73 + 51, y2 + 42);
  ctx.lineTo(x2 + 73 + 51 + 22, y2);
  ctx.stroke();
  ctx.closePath();
}

function drawGridRHS(ctx, column) {
  var x, y, x2, y2;
  var row = 1;
  ctx.beginPath();
  x = (column + 1) * 73 + 46;
  y = 48;
  ctx.moveTo(x, y);
  do {
    if (row % 2 == 1) {
      x2 = x + 22;
    } else {
      x2 = x;
    }
    y2 = y + 42;
    y = y2;
    ctx.lineTo(x2, y2);
    row++;
  } while (row < maxRows * 2);
  ctx.stroke();
  ctx.closePath();
}

function init() {
  canvas = document.getElementById('canvas');
  canvas2 = document.getElementById('canvas2');
  canvasBk = document.getElementById('canvasBk');
  ctx = canvas.getContext('2d');
  ctx2 = canvas2.getContext('2d');
  ctxBk = canvasBk.getContext('2d');
/***
      var bkImage = new Image();
      bkImage.src = "bfm_map.png";
      bkImage.onload = function() {
        ctxBk.drawImage(bkImage, 0, 0);
 }
***/
  theBoard = new Board(10, 8);
  theBoard.setHex(2, 6, Board.HexType.DESERT);
  theBoard.setHex(2, 7, Board.HexType.DESERT);
  theBoard.setHex(3, 6, Board.HexType.DESERT);
  theBoard.setHex(3, 7, Board.HexType.DESERT);
  theBoard.setHex(1, 0, Board.HexType.DESERT);
  theBoard.setHex(4, 3, Board.HexType.FOREST);
  theBoard.setHex(4, 5, Board.HexType.FOREST);
  theBoard.setHex(5, 2, Board.HexType.FOREST);
  theBoard.setHex(5, 3, Board.HexType.FOREST);
  theBoard.setHex(6, 3, Board.HexType.FOREST);
  theBoard.setHex(6, 4, Board.HexType.FOREST);
  theBoard.setHex(9, 6, Board.HexType.FOREST);
  theBoard.setHex(1, 4, Board.HexType.CITY);
  theBoard.setCityName(1, 4, 'Smallville');
  theBoard.setHex(7, 4, Board.HexType.CITY);
  theBoard.setCityName(7, 4, 'IndustrialPark');
  theBoard.setHex(1, 1, Board.HexType.MOUNTAIN);
  theBoard.setHex(6, 1, Board.HexType.MOUNTAIN);
  theBoard.setHex(6, 2, Board.HexType.MOUNTAIN);
  theBoard.setHex(9, 5, Board.HexType.MOUNTAIN);
  theBoard.setHex(2, 5, Board.HexType.SEA);
  theBoard.setHex(3, 5, Board.HexType.SEA);
  theBoard.setHex(9, 7, Board.HexType.SEA);

  cityImage = new Image();
  cityImage.src = 'city.png';
  desertImage = new Image();
  desertImage.src = 'desert.png';
  mountainImage = new Image();
  mountainImage.src = 'mountain.png';
  treeImage = new Image();
  treeImage.src = 'tree.png';
  treeImage.onload = function() {
    theBoard.postMsg();
    initSides();
    theBoard.initDraw(ctxBk);
    drawUnits();
  }
 // return setInterval(draw, 10);
}

// FIXME -- this is using global variable |ctx|
function drawUnits() {
  clearContext(ctx);
  ctx.fillStyle = '#FAF7F8';
  ctx.fillStyle = '#504444';

  gSide.forEach(function(u) {u.draw(ctx);});
  rSide.forEach(function(u) {u.draw(ctx);});
}

function myMove(e) {
  if (dragok) {
    x = e.pageX - canvas.offsetLeft;
    y = e.pageY - canvas.offsetTop;
  }
}

function myDown(e) {
  if (e.pageX < x + 15 + canvas.offsetLeft && e.pageX > x - 15 +
      canvas.offsetLeft && e.pageY < y + 15 + canvas.offsetTop &&
      e.pageY > y - 15 + canvas.offsetTop) {
    x = e.pageX - canvas.offsetLeft;
    y = e.pageY - canvas.offsetTop;
    dragok = true;
    canvas.onmousemove = myMove;
  }
}

function getMoves(id, x, y) {
  if (!naclModule) {
    console.log('No NaCl module');
    return;
  }
  var stringData = 'GET_MOVES ' + id + ' ' + x + ' ' + y;
  console.log('naclModule=' + naclModule + ' stringData: ' + stringData);
  var result = naclModule.postToNexe(stringData);
  result = result.replace(/^\s+/, '');
  result = result.replace(/\s+$/, '');
  console.log('Move result = [' + result + ']');
  moveArray = result.split(' ');
  var ss = ctx2.strokeStyle;
  var fs = ctx2.fillStyle;
  ctx2.strokeStyle = 'rgba(0,0,0, 1)';
  ctx2.fillStyle = 'rgba(30,30,30, 0.5)';
  for (var i = 0; i < moveArray.length; ++i) {
    console.log('Move ' + i + ' is ' + moveArray[i]);
    var coordArray = moveArray[i].split(',');
    if (coordArray[0] != x || coordArray[1] != y) {
      drawHex(ctx2, coordArray[0], coordArray[1]);
    }
  }
  ctx2.strokeStyle = ss;
  ctx2.fillStyle = fs;
}

function mouseDownHandler(e) {
  var turnState = theBoard.getTurnState();
  if (turnState == Board.TurnState.MOVING) {
    return moveHandler(e);
  } else if (turnState == Board.TurnState.ATTACKING) {
    console.log('ATTACKING handler');
    return attackHandler(e);
  } else if (turnState == Board.TurnState.RESOLVING) {
    console.log('RESOLVING handler');
    return resolveHandler(e);
  }
}

function getAttackerTargets(unit) {
    var id = unit.id_;
    var stringData = 'GET_ATTACK ' + id + ' ' + unit.x_ + ' ' + unit.y_;
    console.log('naclModule=' + naclModule + ' stringData: ' + stringData);
    hexesToAttackResult = naclModule.postToNexe(stringData);
    console.log('result = {' + hexesToAttackResult + '}');
    // highlight the unit
}

function resolveHandler(e) {
  var x = e.offsetX;
  var y = e.offsetY;
  var unit = findUnitClickedOn(x, y, otherSide);
  if (!unit)
    return;
  if (unit == undefined) {
    console.log('No unit clicked on');
  }
  console.log('clicked on ' + unit.toString());
  var attackingUnits = new Array();
  var stringData = 'RESOLVE_ATTACK ' + unit.Id();
  theSide.forEach(
    function(u) {
      var attackedUnit = u.getAttackedUnit();
      if (attackedUnit == unit) {
        attackingUnits.push(u);
        stringData += ' ' + u.Id();
      }
    }
  );
  if (attackingUnits.length == 0) {
    console.log('No attackers for unit ' + unit.toString());
    return;
  }
  // make sure NaCl has updated units info
  postUnits();

  console.log('Attacking units: ' + attackingUnits);
  var defense = unit.Attack();
  var row = unit.Row();
  var column = unit.Column();
  // send attackers, attacked unit to NEXE
  console.log('sending ' + stringData);
  var result = naclModule.postToNexe(stringData);
  console.log('result ' + result);
  var resultType = result.substring(0, 2);
  var commaIndex = result.indexOf(',');
  var retreatData = '';
  var retreatCoordList = new Array();
  if (commaIndex != -1) {
    retreatData = result.substring(commaIndex + 1);
    console.log('Retreat data: {' + retreatData + '}');
    retreatCoordList = retreatData.split(',');
  }
  if (resultType == 'EX') {
    unit.SetDestroyed();
    attackingUnits.forEach(
      function(u) {u.setAttackedUnit(null); u.SetDestroyed();}
    );
  } else if (resultType == 'AR') {
    attackingUnits.forEach(
      function(u) {u.setAttackedUnit(null);}
    );
  } else if (resultType == 'DR') {
    attackingUnits.forEach(
      function(u) {u.setAttackedUnit(null);}
    );
    if (retreatCoordList.length == 1) {
      console.log('Retreating unit!');
      var coordArray = retreatCoordList[0].split(':');
      console.log(' retreatCoordList ' + retreatCoordList);
      console.log(' coordArray ' + coordArray);
      var newX = coordArray[0];
      var newY = coordArray[1];
      unit.SetNewLocation(newX, newY);
    } else {
      console.log('Not sure where to retreat unit, length = ' +
                  retreatData.length);
    }
  } else if (resultType == 'AE') {
    attackingUnits.forEach(
      function(u) {u.setAttackedUnit(null); u.SetDestroyed();}
    );
  } else if (resultType == 'DE') {
    unit.SetDestroyed(); // mark defender as destroyed
    // clear the attacker units |attacking| data
    attackingUnits.forEach(function(u) {u.setAttackedUnit(null);});
    // ask if one of the attackers should advance?
    // START HERE
  } else {
    alert('Unknown result type ' + resultType);
  }

  drawUnits();
  drawAttackers(ctx2, theSide);

}

function drawAttackers(ctx, attackingSide) {
  // NEW DRAW ...
  clearContext(ctx);
  attackingSide.forEach(
    function(u) {
      u.setDoneMove(false);
      var thisAttacked = u.getAttackedUnit();
      // draw a line from attacking unit to attacked unit
      if (thisAttacked) {
        drawLine(u, thisAttacked, ctx);
      }
    }
  );
}

function attackHandler(e) {
  var x = e.offsetX;
  var y = e.offsetY;
  if (selectedUnit == undefined) {
    var unit = findUnitClickedOn(x, y, theSide);
    if (unit == undefined) {
      console.log('You did not select ANY unit');
      return;
    }
    selectedUnit = unit;
    console.log('Selected ' + unit.toString());
    getAttackerTargets(selectedUnit);
    highlightUnit(ctx2, unit);

  } else {
    // we already selected an attacking unit...now we are trying to see if
    // we clicked on a unit that can be attacked ... or if we clicked a
    // different unit of ours...
    console.log('Checking for attacked unit');
    var attackedUnit = findUnitClickedOn(x, y, otherSide);
    if (attackedUnit == undefined) {
      console.log('No enemy unit selected to attack');
      var newSelectedUnit = findUnitClickedOn(x, y, theSide);
      if (newSelectedUnit) {
        console.log('Selected NEW ' + newSelectedUnit.toString);
        highlightUnit(ctx2, newSelectedUnit);
        selectedUnit = newSelectedUnit;
        getAttackerTargets(selectedUnit);
        return;
      }
    } else if (attackedUnit.color_ == theSide[0].color_) {
      // then you clicked on a friendly unit
      return;
    } else {
      var coordArray = hexesToAttackResult.split(';');
      for (var i = 0; i < coordArray.length; ++i) {
        var coordPair = coordArray[i].split(',');
        console.log(' Legal is ' + coordPair[0] + ':' + coordPair[1]);
        if (attackedUnit.x_ == coordPair[0] &&
            attackedUnit.y_ == coordPair[1]) {
          console.log(' LEGAL ATTACK ');
          selectedUnit.setAttackedUnit(attackedUnit);

          drawAttackers(ctx2, theSide);

          // FIXME -- instead of drawing the line, we need to add this to a
          // list of from=>to attack pairs and then draw them all at once.
          // That way, we can remove an attack pair and redraw!
        } else {
          console.log(' Unit is NOT adjacent ');
        }
      }
    }
    if (attackedUnit) {
      console.log(selectedUnit.toString() + ' is attacking ' +
                  attackedUnit.toString());
    }
  }
}

function moveHandler(e) {
  console.log(' ENTERED MOUSE DOWN HANDLER ');
  var x = e.offsetX;
  var y = e.offsetY;

  console.log('clicked ' + x + ':' + y);
  var i;
  var unit;
  if (whoseTurn == 'G') {
    theSide = gSide;
  } else if (whoseTurn == 'R') {
    theSide = rSide;
  } else {
    ErrorMessage('Invalid turn: whoseTurn=' + whoseTurn);
    return;
  }

  // a unit was already selected
  if (selectedUnit != undefined) {
    console.log('Current unit selected is ' + selectedUnit.toString());
    var columnClicked = xToColumn(x);
    var rowClicked = yToRow(columnClicked, y);
    console.log('Clicked on ' + columnClicked + ':' + rowClicked);
    console.log('Move array ' + moveArray + ' length: ' + moveArray.length);

    // see if columnClicked:rowClicked is in the possible moves
    var currentColumn = selectedUnit.Column();
    var currentRow = selectedUnit.Row();

    var foundLegalMove = false;
    console.log('columnClicked=' + columnClicked + ' rowClicked=' + rowClicked);
    for (var i = 0; i < moveArray.length; ++i) {
      var coordArray = moveArray[i].split(',');
      console.log(' coordArray = ' + coordArray[0] + ':' + coordArray[1]);
      if (columnClicked == coordArray[0] && rowClicked == coordArray[1] &&
          (columnClicked != currentColumn || rowClicked != currentRow)) {
        console.log('Clicked on valid move [' + columnClicked + ':' +
                    rowClicked + ']');

        var doMove = true;
        if (doMove) {
          console.log('Moving...');
          selectedUnit.setHexX(columnClicked);
          selectedUnit.setHexY(rowClicked);
          selectedUnit.setDoneMove(true);
          selectedUnit = undefined;
          clearContext(ctx2);
          //redraw units...
          drawUnits();
          selectedUnit = undefined;
          foundLegalMove = true;
        }
      }
    }

    // FIXME -- what is the code below this block doing?
    if (!foundLegalMove) {
      selectedUnit = undefined;
      clearContext(ctx2);
      // drawUnits();
    }
    return;
  }

  // code below is for no unit selected ... see if we just clicked on one
  // check theSide
  var foundUnit = false;
  for (i = 0; i < theSide.length; i++) {
    var unit = theSide[i];
    if (unit.containsPoint(x, y)) {
      postUnits();
      theBoard.postMsg();
      console.log('clicked on ' + unit.id_ + ' ' + unit.x_ + ':' + unit.y_);
      if (unit.doneMove()) {
        console.log('That unit has already moved!');
      } else {
        clearContext(ctx2);
        // drawUnits();
        // get moves and highlight those
        getMoves(unit.id_, unit.x_, unit.y_);

        highlightUnit(ctx2, unit);
        foundUnit = true;
        selectedUnit = unit;
      }
    }
  } // end of for loop
  if (!foundUnit) {
    clearContext(ctx2);
  }
}


//
//
//
function drawLine(unit1, unit2, ctx) {
  console.log(' unit1: ' + unit1.toString() + ' unit2:' + unit2.toString());
  var x1 = (unit1.upperLeftX_ + unit1.bottomRightX_) / 2;
  var y1 = (unit1.upperLeftY_ + unit1.bottomRightY_) / 2;
  var x2 = (unit2.upperLeftX_ + unit2.bottomRightX_) / 2;
  var y2 = (unit2.upperLeftY_ + unit2.bottomRightY_) / 2;
  var ss = ctx.strokeStyle;
  var lw = ctx.lineWidth;

  ctx.strokeStyle = 'rgb(255,0,0)';
  ctx.beginPath();
  ctx.lineWidth = 5;
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);

/***
  // now do the arrow points
  var slope = (y1 - y2) / (x2 - x1);  // reverse y1 direction because
                                      // y decreases as we go 'up'
  var angle = Math.atan(slope);

  if (x2-x1 < 0)
    angle += Math.PI;
// START HERE
//
//  if (y1-y2 < 0)
//    angle +=
//
  var degrees = angle/Math.PI * 180;

  if (slope < 0 && degrees > 0) {
    degrees *= -1;
  }

  console.log('slope: ' + slope + ' ANGLE ' + angle + ' degrees: ' + degrees);
  // we want short lines going from x2:y2 back towards x1:y1
  // but off by +/- 30 degrees
  // we went from START -> FINISH...now we need to go from FINISH
  // back to arrow heads
  var angle2 = Math.PI + angle;
  if (angle2 > Math.PI * 2) {
    angle2 -= Math.PI * 2;
  }
  var degrees2 = angle2 / Math.PI * 180;
  var distance = Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  console.log('degrees: ' + degrees + ' degrees2:' + degrees2 +
              ' distance: ' + distance);
  var angle2a = angle2 + Math.PI/6;
  var angle2b = angle2 - Math.PI/6;
  console.log(' angle2a: ' + angle2a/Math.PI * 180 + ' angle2b: '
              + angle2b/Math.PI * 180);
  var head1x, head1y, head2x, head2y;

  console.log(' angle2a RAD ' + angle2a);
  if (angle2a >= Math.PI * 1.5 || angle2a < Math.PI * 0.5) {
    console.log('plus X');
    head1x = x2 + (distance/4) * Math.cos(angle2a);
  } else {
    console.log('minus X');
    head1x = x2 - (distance/4) * Math.cos(angle2a);
  }
  if (angle2a >= 0 && angle2a <= Math.PI) {
    head1y = y2 + (distance/4) * Math.sin(angle2a);
  } else {
    head1y = y2 - (distance/4) * Math.sin(angle2a);
  }

  head2x = x2 - (distance/4) * Math.cos(angle2b);
  head2y = y2 + (distance/4) * Math.sin(angle2b);
  console.log(' end ' + x2 + ':' + y2 + ' head1 ' + head1x + ':' + head1y
              + ' head2 ' + head2x + ':' + head2y);
  ctx.lineTo(head1x, head1y);
  ctx.moveTo(x2, y2);
  // ctx.lineTo(head2x, head2y);
*/

  ctx.stroke();
  ctx.closePath();

  ctx.strokeStyle = ss;
  ctx.lineWidth = lw;
}

//
// Highlight |unit| using context |ctx2|
//
function highlightUnit(ctx2, unit) {
        // now draw selected hex in different color
        var ss = ctx2.strokeStyle;
        var fs = ctx2.fillStyle;
        var alpha = ctx2.globalAlpha;

        ctx2.globalAlpha = 0.9;
        ctx2.strokeStyle = 'rgba(240,240,0, 0.6)';
        ctx2.fillStyle = 'rgba(200, 200, 0, 0.5)';
        // drawHex(ctx2, unit.x_, unit.y_, 1);
        drawHex(ctx2, unit.x_, unit.y_);

        ctx2.strokeStyle = ss;
        ctx2.fillStyle = fs;
        ctx2.globalAlpha = alpha;
}

//
// Given a coordinate |x,y| and a list of units |unitList|
// see if any of the units in |unitList| contains |x,y|
//
function findUnitClickedOn(x, y, unitList) {
  var foundUnit = false;
  for (i = 0; i < unitList.length; i++) {
    var unit = unitList[i];
    if (unit.containsPoint(x, y)) {
      return unit;
    }
  }
  return undefined;
}

function doneMovesHandler() {
  var turnState = theBoard.getTurnState();
  if (turnState != Board.TurnState.MOVING) {
    alert('You are not in the Move state, you are in the ' +
          theBoard.getTurnStateString() + ' state.');
    return;
  }
  var answer = confirm('Are you done moving all units?');
  if (answer) {
    console.log('Done moves...');
    theBoard.doneMoving();
    updateHtmlField('Phase', 'PHASE: ' + theBoard.getTurnStateString());
    // clear all the Move flags...
    if (theSide) {
      theSide.forEach(function(u) {u.setDoneMove(false);});
    }
    //redraw units...
    clearAllAttackingUnits();
    drawUnits();
    // Now we enter attacking phase
  } else {
    console.log('NOT Done moves...');
  }
}

function clearAllAttackingUnits() {
  theSide.forEach(function(u) {u.setAttackedUnit(null);});
  otherSide.forEach(function(u) {u.setAttackedUnit(null);});
}

function doneAttackHandler() {
  var turnState = theBoard.getTurnState();
  if (turnState != Board.TurnState.ATTACKING) {
    alert('You are not in the Attack state, you are in the ' +
          theBoard.getTurnStateString() + ' state.');
    return;
  }
  var answer = confirm('Are you done planning all attacks?');
  if (answer) {
    console.log('Done attacks...');
    theBoard.doneAttacking();
    updateHtmlField('Phase', 'PHASE: ' + theBoard.getTurnStateString());
    // ATTACKING
  } else {
    console.log('NOT Done moves...');
  }
}

function doneResolvingHandler() {
  var turnState = theBoard.getTurnState();
  console.log('In doneResolvingHandler');
  if (turnState != Board.TurnState.RESOLVING) {
    alert('You are not in the Resolving state, you are in the ' +
          theBoard.getTurnStateString() + ' state.');
    return;
  }
  clearAllAttackingUnits();
  drawUnits();
  // switch sides
  theBoard.doneResolving();
  if (theSide == gSide) {
    theSide = rSide;
    otherSide = gSide;
  } else {
    theSide = gSide;
    otherSide = rSide;
  }
  // switch turn
  if (whoseTurn == 'G') {
    whoseTurn = 'R';
  } else {
    // we are switching back to G, increment turn number
    turnNumber++;
    whoseTurn = 'G';
  }
  updateHtmlField('Phase', 'PHASE: ' + theBoard.getTurnStateString());
  updateHtmlField('Turn', 'TURN: ' + whoseTurn);
  updateHtmlField('TurnNumber', 'Turn: Number: ' + turnNumber);
}

init();
canvas.onmousedown = mouseDownHandler;
