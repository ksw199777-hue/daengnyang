class BadWords {
  static const List<String> words = [
    // 시발 계열
    '시발', '씨발', '씨팔', '시팔', 'ㅅㅂ', 'ㅆㅂ',
    // 새끼 계열
    '새끼', 'ㅅㄲ', '개새끼',
    // 병신 계열
    '병신', 'ㅂㅅ',
    // 지랄 계열
    '지랄', 'ㅈㄹ',
    // 미친 계열
    '미친', 'ㅁㅊ',
    // 존나 계열
    '존나', '존내', '졸라', 'ㅈㄴ',
    // 꺼져 계열
    '꺼져', '꺼지', 'ㄲㅈ',
    // 뒤져 계열
    '뒤져', '뒤지', 'ㄷㅈ',
    // 씹 계열
    '씹',
    // 썅 계열
    '썅',
    // 창녀·쌍 계열
    '창녀', '창년', '쌍년', '쌍놈',
    // 성기 관련
    '보지', '자지',
    // 성관계
    '섹스',
    // 기타 욕설
    '개소리', '닥쳐', '죽어',
    // 혐오·비하
    '찐따', '장애', '바보', '멍청',
    // 단음절 (포함 검사)
    '놈', '년',
  ];

  /// 특수문자·숫자·공백을 제거하고 한글·영문만 남김
  static String _normalize(String text) {
    return text.replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-z]'), '');
  }

  /// 한글 음절 → 초성 추출, 독립 자음은 그대로 유지
  /// 예: '시발' → 'ㅅㅂ', 'ㅅ발' → 'ㅅㅂ'
  static String _extractChosung(String text) {
    const chosung = [
      'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
      'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
    ];
    final buffer = StringBuffer();
    for (final cp in text.runes) {
      if (cp >= 0xAC00 && cp <= 0xD7A3) {
        // 완성형 음절 → 초성 인덱스 = (코드포인트 - 0xAC00) ÷ (중성21 × 종성28)
        buffer.write(chosung[(cp - 0xAC00) ~/ 588]);
      } else if (cp >= 0x3131 && cp <= 0x314E) {
        // 독립 자음 → 그대로 보존
        buffer.writeCharCode(cp);
      }
    }
    return buffer.toString();
  }

  static bool contains(String text) {
    final normalized = _normalize(text.toLowerCase());

    // 1차: 정규화된 텍스트에서 직접 매칭
    if (words.any((w) => normalized.contains(w))) return true;

    // 2차: 독립 자음이 포함된 경우에만 초성 추출 검사
    //      (밥상→ㅂㅅ처럼 순수 음절만 있을 때 생기는 오탐 방지)
    if (RegExp(r'[ㄱ-ㅎ]').hasMatch(normalized)) {
      final chosung = _extractChosung(normalized);
      if (words.any((w) => chosung.contains(w))) return true;
    }

    return false;
  }
}
