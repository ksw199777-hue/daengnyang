import 'package:flutter/material.dart';
import 'package:daengnyang/core/colors.dart';

Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  TimeOfDay? initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _WheelTimePickerSheet(
      initialTime: initialTime ?? TimeOfDay.now(),
    ),
  );
}

class _WheelTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  const _WheelTimePickerSheet({required this.initialTime});

  @override
  State<_WheelTimePickerSheet> createState() => _WheelTimePickerSheetState();
}

class _WheelTimePickerSheetState extends State<_WheelTimePickerSheet> {
  late int _periodIndex; // 0=오전, 1=오후
  late int _hourIndex;   // 0–11 → 표시: 1–12
  late int _minuteIndex; // 0–59

  late final FixedExtentScrollController _periodCtrl;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  static const double _itemH = 52.0;
  static const int _visibleItems = 5;
  static const double _wheelH = _itemH * _visibleItems;

  @override
  void initState() {
    super.initState();
    _periodIndex = widget.initialTime.period == DayPeriod.am ? 0 : 1;
    final hop = widget.initialTime.hourOfPeriod; // 0–11, 0은 12시
    _hourIndex = hop == 0 ? 11 : hop - 1;
    _minuteIndex = widget.initialTime.minute;

    _periodCtrl = FixedExtentScrollController(initialItem: _periodIndex);
    _hourCtrl   = FixedExtentScrollController(initialItem: _hourIndex);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _periodCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  // 음수 방향 스크롤 시 모듈로 안전 처리
  int _mod(int i, int n) => ((i % n) + n) % n;

  TimeOfDay get _result {
    final h12 = _hourIndex + 1; // 1–12
    final int h24;
    if (_periodIndex == 0) {       // 오전
      h24 = h12 == 12 ? 0 : h12;
    } else {                       // 오후
      h24 = h12 == 12 ? 12 : h12 + 12;
    }
    return TimeOfDay(hour: h24, minute: _minuteIndex);
  }

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required int count,
    required List<Widget> children,
    required ValueChanged<int> onChanged,
    bool loop = true,
  }) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: _itemH,
        useMagnifier: true,
        magnification: 1.25,
        diameterRatio: 1.6,
        squeeze: 1.0,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onChanged(loop ? _mod(i, count) : i),
        childDelegate: loop
            ? ListWheelChildLoopingListDelegate(children: children)
            : ListWheelChildListDelegate(children: children),
      ),
    );
  }

  static TextStyle get _itemStyle => const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  @override
  Widget build(BuildContext context) {
    const bandTop = (_wheelH - _itemH) / 2;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '시간 선택',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            // 컬럼 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: const [
                  Expanded(child: Center(child: Text('오전/오후', style: TextStyle(fontSize: 12, color: AppColors.textMid)))),
                  Expanded(child: Center(child: Text('시', style: TextStyle(fontSize: 12, color: AppColors.textMid)))),
                  Expanded(child: Center(child: Text('분', style: TextStyle(fontSize: 12, color: AppColors.textMid)))),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // 휠 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: _wheelH,
                child: Stack(
                  children: [
                    // 선택 강조 밴드
                    Positioned(
                      left: 0,
                      right: 0,
                      top: bandTop,
                      height: _itemH,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // 3개 휠
                    Row(
                      children: [
                        // 오전 / 오후
                        _wheel(
                          ctrl: _periodCtrl,
                          count: 2,
                          onChanged: (i) => setState(() => _periodIndex = i),
                          loop: false,
                          children: [
                            Center(child: Text('오전', style: _itemStyle)),
                            Center(child: Text('오후', style: _itemStyle)),
                          ],
                        ),
                        // 시 (1–12)
                        _wheel(
                          ctrl: _hourCtrl,
                          count: 12,
                          onChanged: (i) => setState(() => _hourIndex = i),
                          children: List.generate(
                            12,
                            (i) => Center(child: Text('${i + 1}', style: _itemStyle)),
                          ),
                        ),
                        // 분 (00–59)
                        _wheel(
                          ctrl: _minuteCtrl,
                          count: 60,
                          onChanged: (i) => setState(() => _minuteIndex = i),
                          children: List.generate(
                            60,
                            (i) => Center(
                              child: Text(i.toString().padLeft(2, '0'), style: _itemStyle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
