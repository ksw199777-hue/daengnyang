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
    // 존나 계열 ('졸라'는 아래 정규식으로 처리)
    '존나', '존내', 'ㅈㄴ',
    // 꺼져 계열 ('꺼지' 제거 — '꺼지다' 동사 오탐)
    '꺼져', 'ㄲㅈ',
    // 뒤져 계열 ('뒤지' 제거 — '뒤지다' 동사 오탐)
    '뒤져', 'ㄷㅈ',
    // 씹 계열
    '씹',
    // 썅 계열
    '썅',
    // 창녀·쌍 계열 ('년' 단독 제거, '개년' 추가)
    '창녀', '창년', '쌍년', '쌍놈', '개년',
    // 성관계
    '섹스',
    // 기타 욕설
    '개소리', '닥쳐', '죽어',
    // 혐오·비하 ('장애' 제거 — 장애인/장애물 등 중립 표현 오탐)
    '찐따', '바보', '멍청',
    // 단음절
    '놈',
    // '년' 제거 — 작년/내년/연도 표기(2024년→년) 오탐
    // '보지'/'자지' 제거 — 아래 정규식으로 동사 활용형 구분 처리
  ];

  static String _normalize(String text) {
    return text.replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-z]'), '');
  }

  static String _extractChosung(String text) {
    const chosung = [
      'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
      'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
    ];
    final buffer = StringBuffer();
    for (final cp in text.runes) {
      if (cp >= 0xAC00 && cp <= 0xD7A3) {
        buffer.write(chosung[(cp - 0xAC00) ~/ 588]);
      } else if (cp >= 0x3131 && cp <= 0x314E) {
        buffer.writeCharCode(cp);
      }
    }
    return buffer.toString();
  }

  static bool contains(String text) {
    final lower = text.toLowerCase();
    final normalized = _normalize(lower);

    // 1차: 정규화된 텍스트에서 직접 매칭
    if (words.any((w) => normalized.contains(w))) return true;

    // '보지'/'자지': V+지 부정형(않/못/마/말/도)이 뒤따르는 경우 동사 활용형으로 간주해 제외
    // 예) "보지않다"·"자지못했어"·"보지도않고" → 통과 / "보지를"·"자지" → 탐지
    if (RegExp(r'보지(?!(않|못|마|말|도))').hasMatch(normalized)) return true;
    if (RegExp(r'자지(?!(않|못|마|말|도))').hasMatch(normalized)) return true;

    // '졸라': 졸라매다·졸라붙다 등 정상 동사 제외
    if (RegExp(r'졸라(?!(매|붙))').hasMatch(normalized)) return true;

    // 2차: 공백 단위 토큰별 초성 검사
    // 전체 텍스트를 한 번에 처리하면 "ㅎㅎ 상반기"처럼 웃음 표현(ㅎㅎ/ㅋㅋ)이
    // 뒤 단어의 초성(ㅅㅂ)과 연결돼 오탐이 발생하므로 공백으로 분리 후 토큰별 검사
    for (final token in lower.split(RegExp(r'\s+'))) {
      final normToken = _normalize(token);
      if (normToken.isEmpty) continue;
      if (RegExp(r'[ㄱ-ㅎ]').hasMatch(normToken)) {
        final chosung = _extractChosung(normToken);
        if (words.any((w) => chosung.contains(w))) return true;
      }
    }

    return false;
  }
}
