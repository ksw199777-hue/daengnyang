class BadWords {
  static const List<String> words = [
    '시발', '씨발', 'ㅅㅂ', '개새끼', '새끼', '놈', '년', 
    '병신', 'ㅂㅅ', '지랄', '꺼져', '죽어', '미친', 'ㅁㅊ',
    '바보', '멍청', '찐따', '장애', '보지', '자지', '섹스',
    '씹', 'ㅆㅂ', '개소리', '닥쳐', '꺼지',
  ];

  static bool contains(String text) {
    final lower = text.toLowerCase();
    return words.any((word) => lower.contains(word));
  }
}