
function testSimple() {
  assertEquals("this should pass", 3, 3);
  // assertEquals("this should NOT pass", 3, 4);
}

function testPiece() {
  var aWhitePawn = new Chess.Piece(Chess.ColorType.WHITE, Chess.PieceType.PAWN);
  var aBlackQueen = new Chess.Piece(Chess.ColorType.BLACK, Chess.PieceType.QUEEN);
  assertEquals('white getColor', aWhitePawn.getColor(), Chess.ColorType.WHITE);
  assertEquals('black getColor', aBlackQueen.getColor(), Chess.ColorType.BLACK);
  assertEquals('black toString', aBlackQueen.toString(), 'BLACK Queen');
  assertEquals('white toString', aWhitePawn.toString(), 'WHITE Pawn');
  assertEquals('black toChar', aBlackQueen.toChar(), 'q');
  assertEquals('white toChar', aWhitePawn.toChar(), 'P');
}

function runSuite() {
  try {
    testSimple();
    testPiece();
    console.log('CHESS SUITE PASSED');
    alert('CHESS SUITE PASSED');
  } catch (exception) {
    var exception_string = 'TEST ERROR.  Comment=' + exception.comment +
                           ' jsUnitMessage: ' + exception.jsUnitMessage;
    console.log(exception_string);
    alert(exception_string); 
  }
}
