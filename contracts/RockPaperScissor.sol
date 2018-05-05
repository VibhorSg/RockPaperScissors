pragma solidity ^ 0.4.21;

contract RockPaperScissor {
  address public owner;
  bool public isRunning;

  struct PlayerData {
    uint move;
    bool hasPlayed;
  }

  enum GameStage {
    Initial,
    Palying,
    Draw,
    Stop
  }

  struct GameData {
    /*
     * winner address can be use for multiple purpose. In that case player1 and
     * player2 addresses not needed Not going to that level of optimisation in
     * this version
     */
    address player1;
    address player2;
    address winner;
    bytes32 player1SecretCode;
    bytes32 player2SecretCode;
    uint amount;
    GameStage stage;
    mapping(address => PlayerData) playerData;
  }

  mapping(bytes32 => GameData) public gameList;

  event LogChallangeCreated(bytes32 indexed gameId, bytes32 secretCode,
                            uint indexed amount);
  event LogChallangeAccepted(bytes32 indexed gameId, bytes32 secretCode);
  event LogPlayerMove(bytes32 indexed gameId, address indexed player,
                      uint move);
  event LogResult(bytes32 indexed gameId, string result, address winner);
  event LogPaused(address indexed owner);
  event LogResumed(address indexed owner);

  constructor(bool _running) public {
    isRunning = _running;
    owner = msg.sender;
  }

  /*
   *Modifier: onlyIfRunning
   *Allow owner to controll all games with single flag.
   */
  modifier onlyIfRunning {
    require(isRunning);
    _;
  }

  /*
   *Function: pause: This function is use to halt all games operation.
   */
  function pause() public onlyIfRunning returns(bool) {
    require(msg.sender == owner);
    emit LogPaused(owner);
    isRunning = false;
  }

  /*
   *Function: resume: This function is use to resume all games operations.
   */
  function resume() public returns(bool) {
    require(msg.sender == owner);
    emit LogResumed(owner);
    isRunning = true;
  }

  function createChallange(bytes32 _secretCode) public onlyIfRunning payable
  returns(bool) {
    require(_secretCode[0] != 0);
    bytes32 gameId = keccak256(msg.sender, block.number);
    gameList[gameId] =
        GameData(msg.sender, address(0x00), address(0x00), _secretCode,
                 _secretCode, msg.value, GameStage.Initial);
    gameList[gameId].playerData[msg.sender] = PlayerData(0, false);
    emit LogChallangeCreated(gameId, _secretCode, msg.value);
    return true;
  }

  function acceptChallenge(bytes32 _gameId,
                           bytes32 _secretCode) public onlyIfRunning payable
  returns(bool) {
    require(_secretCode[0] != 0);
    GameData storage gameData = gameList[_gameId];
    require(gameData.stage == GameStage.Initial);
    if (isPlayervalid(_gameId, msg.sender)) {
      // Player already exist so it is old game
      gameData.playerData[msg.sender].move = 0;
      gameData.playerData[msg.sender].hasPlayed = false;
    } else {
      // Its new game.
      require(msg.value == gameData.amount);
      gameData.player2 = msg.sender;
      gameData.playerData[msg.sender] = PlayerData(0, false);
    }
    gameData.stage = GameStage.Palying;
    gameData.player2SecretCode = _secretCode;
    emit LogChallangeAccepted(_gameId, _secretCode);
    return true;
  }

  function isStageValid(bytes32 _gameId) private view returns(bool) {
    GameData storage gameData = gameList[_gameId];
    return ((gameData.stage == GameStage.Draw) ||
            (gameData.stage == GameStage.Stop));
  }

  function isPlayervalid(bytes32 _gameId, address player) private view returns(
      bool) {
    GameData storage gameData = gameList[_gameId];
    return (gameData.player1 != address(0x00) &&
            gameData.player2 != address(0x00) &&
            ((player == gameData.player1) || (player == gameData.player2)));
  }

  function resetGame(bytes32 _gameId, bytes32 _secretCode) public onlyIfRunning
  returns(bool) {
    GameData storage gameData = gameList[_gameId];
    require(isStageValid(_gameId));
    require(isPlayervalid(_gameId, msg.sender));
    if (msg.sender == gameData.player1)
      gameData.player1SecretCode = _secretCode;
    else
      gameData.player2SecretCode = _secretCode;

    gameData.playerData[msg.sender].move = 0;
    gameData.playerData[msg.sender].hasPlayed = false;

    gameData.stage = GameStage.Initial;

    emit LogChallangeCreated(_gameId, _secretCode, gameData.amount);

    return true;
  }

  function isSecretCodeMatched(bytes32 _gameId, address player,
                               bytes32 _secretCode) private view
  returns(bool) {
    GameData storage gameData = gameList[_gameId];
    if (player == gameData.player1)
      return (gameData.player1SecretCode == _secretCode);
    else if (player == gameData.player2)
      return (gameData.player2SecretCode == _secretCode);
    else
      return false;
  }

  function hasBothPlayerPlayed(bytes32 _gameId) private view returns(bool) {
    GameData storage gameData = gameList[_gameId];
    return ((gameData.playerData[gameData.player1].hasPlayed) &&
            (gameData.playerData[gameData.player2].hasPlayed));
  }

  function checkWinner(bytes32 _gameId) private returns(bool) {
    GameData storage gameData = gameList[_gameId];
    PlayerData storage player1Data = gameData.playerData[gameData.player1];
    PlayerData storage player2Data = gameData.playerData[gameData.player2];

    if (player1Data.move == player2Data.move)
      return false; // It is draw.

    if ((player1Data.move % 2 == 0) && (player2Data.move % 2 == 0)) {
      // Both even then bigger is the winner
      if (player1Data.move > player2Data.move) {
        gameData.winner = gameData.player1;
      } else {
        gameData.winner = gameData.player2;
      }
    } else {
      // If odd and even the smaller is the winner
      if (player1Data.move > player2Data.move) {
        gameData.winner = gameData.player2;
      } else {
        gameData.winner = gameData.player1;
      }
    }
    return true;
  }

  function revealMove(bytes32 _gameId, string _password,
                      uint _move) public onlyIfRunning
  returns(bool) {
    require(
        isSecretCodeMatched(_gameId, msg.sender, keccak256(_password, _move)));
    GameData storage gameData = gameList[_gameId];
    PlayerData storage playerData = gameData.playerData[msg.sender];
    playerData.move = _move;
    playerData.hasPlayed = true;
    if (hasBothPlayerPlayed(_gameId)) {
      if (checkWinner(_gameId)) {
        gameData.stage = GameStage.Stop;
        emit LogResult(_gameId, "winner", gameData.winner);
      } else {
        gameData.stage = GameStage.Draw;
        emit LogResult(_gameId, "draw", address(0x00));
      }
    } else {
      // Inform other player about move
      emit LogPlayerMove(_gameId, msg.sender, _move);
    }
    return true;
  }

  function widrawAmount(bytes32 _gameId) public onlyIfRunning returns(bool) {
    GameData storage gameData = gameList[_gameId];
    require(gameData.stage ==
            GameStage.Stop); // Money can only be widraw if match completed
    require(gameData.winner == msg.sender);
    msg.sender.transfer(gameData.amount);
  }

  function getPlayerData(bytes32 _gameId, address _player) public view returns(
      uint move_, bool hasPlayed_) {
    move_ = gameList[_gameId].playerData[_player].move;
    hasPlayed_ = gameList[_gameId].playerData[_player].hasPlayed;
  }
}
