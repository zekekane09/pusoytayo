enum HandType {
  highCard(0, 'High Card'),
  pair(1, 'Pair'),
  twoPair(2, 'Two Pair'),
  threeOfAKind(3, 'Three of a Kind'),
  straight(4, 'Straight'),
  flush(5, 'Flush'),
  fullHouse(6, 'Full House'),
  fourOfAKind(7, 'Four of a Kind'),
  straightFlush(8, 'Straight Flush'),
  royalFlush(9, 'Royal Flush');

  final int value;
  final String displayName;

  const HandType(this.value, this.displayName);
}

class HandResult {
  final HandType type;
  final List<int> rankValues;
  final int highSuitValue;

  const HandResult({
    required this.type,
    required this.rankValues,
    this.highSuitValue = 0,
  });

  int compareTo(HandResult other) {
    final typeCmp = type.value.compareTo(other.type.value);
    if (typeCmp != 0) return typeCmp;

    for (int i = 0; i < rankValues.length && i < other.rankValues.length; i++) {
      final cmp = rankValues[i].compareTo(other.rankValues[i]);
      if (cmp != 0) return cmp;
    }

    return highSuitValue.compareTo(other.highSuitValue);
  }

  @override
  String toString() => '${type.displayName} $rankValues';
}
