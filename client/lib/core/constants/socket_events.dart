class SocketEvents {
  SocketEvents._();

  // Lobby events
  static const String lobbyList = 'lobby:list';
  static const String lobbyRoomsList = 'lobby:rooms_list';
  static const String lobbyCreate = 'lobby:create';
  static const String lobbyRoomCreated = 'lobby:room_created';
  static const String lobbyJoin = 'lobby:join';
  static const String lobbyJoined = 'lobby:joined';
  static const String lobbyLeave = 'lobby:leave';
  static const String lobbyLeft = 'lobby:left';
  static const String lobbyQuickMatch = 'lobby:quick_match';
  static const String lobbyMatched = 'lobby:matched';
  static const String lobbyRoomUpdated = 'lobby:room_updated';
  static const String lobbyError = 'lobby:error';

  // Game events
  static const String gameReady = 'game:ready';
  static const String gameBettingPhase = 'game:betting_phase';
  static const String gamePlaceBet = 'game:place_bet';
  static const String gameBetPlaced = 'game:bet_placed';
  static const String gameStart = 'game:start';
  static const String gameDeal = 'game:deal';
  static const String gameArrangePhase = 'game:arrange_phase';
  static const String gameArrange = 'game:arrange';
  static const String gameArranged = 'game:arranged';
  static const String gameUnarrange = 'game:unarrange';
  static const String gameUnarranged = 'game:unarranged';
  static const String gameRevealAll = 'game:reveal_all';
  static const String gameCompare = 'game:compare';
  static const String gameScores = 'game:scores';
  static const String gameFinished = 'game:finished';
  static const String gameKicked = 'game:kicked';
  static const String gameTimer = 'game:timer';
  static const String gameError = 'game:error';
  static const String gameReconnect = 'game:reconnect';
  static const String gamePlayerLeft = 'game:player_left';
  static const String gamePlayerReconnected = 'game:player_reconnected';

  // Chat events
  static const String chatMessage = 'chat:message';
  static const String chatVoice = 'chat:voice';
  static const String chatEmoji = 'chat:emoji';

  // Friends
  static const String friendInvite = 'friend:invite';
  static const String friendInvited = 'friend:invited';
}
