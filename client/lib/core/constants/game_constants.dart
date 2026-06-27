class GameConstants {
  GameConstants._();

  static const int totalCards = 52;
  static const int cardsPerPlayer = 13;
  static const int maxPlayers = 4;
  static const int frontHandSize = 3;
  static const int middleHandSize = 5;
  static const int backHandSize = 5;
  static const int arrangeTimeSeconds = 90;
  static const int startingCoins = 1000;

  static const List<String> suitOrder = ['D', 'C', 'H', 'S'];
  static const List<int> rankOrder = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

  static const Map<int, String> rankNames = {
    3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8', 9: '9',
    10: '10', 11: 'J', 12: 'Q', 13: 'K', 14: 'A', 15: '2',
  };

  static const Map<String, String> suitNames = {
    'D': 'Diamonds',
    'C': 'Clubs',
    'H': 'Hearts',
    'S': 'Spades',
  };

  static const Map<String, String> suitSymbols = {
    'D': '♦',
    'C': '♣',
    'H': '♥',
    'S': '♠',
  };
}
