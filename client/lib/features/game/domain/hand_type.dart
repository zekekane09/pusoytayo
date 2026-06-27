enum HandType {
  highCard(0, 'High Card'),
  pair(1, 'Pair'),
  threeOfAKind(2, 'Three of a Kind'),
  straight(3, 'Straight'),
  flush(4, 'Flush'),
  fullHouse(5, 'Full House'),
  fourOfAKind(6, 'Four of a Kind'),
  straightFlush(7, 'Straight Flush'),
  royalFlush(8, 'Royal Flush');

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
