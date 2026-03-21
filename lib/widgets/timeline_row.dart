import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TimelineRow extends StatelessWidget {
  final int hour;
  final int minutes;
  final bool isSelected;
  final bool isCurrent;
  final int currentMinute;
  final bool isActiveWindow;
  final VoidCallback onTap;

  const TimelineRow({
    Key? key,
    required this.hour,
    required this.minutes,
    required this.isSelected,
    required this.isCurrent,
    required this.currentMinute,
    required this.isActiveWindow,
    required this.onTap,
  }) : super(key: key);

  String _formatHour(int h) {
    int h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    String ampm = h < 12 ? "AM" : "PM";
    return "${h12.toString().padLeft(2, ' ')} $ampm";
  }

  @override
  Widget build(BuildContext context) {
    bool hasData = minutes > 0;
    int pct = ((minutes / 60) * 100).round();

    return GestureDetector(
      onTap: isActiveWindow ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.mutedTeal.withOpacity(0.15)
              : isCurrent 
                  ? AppTheme.yellowAccent.withOpacity(0.1)
                  : hasData 
                      ? AppTheme.mutedTeal.withOpacity(0.05)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppTheme.mutedTeal.withOpacity(0.5)
                : isCurrent 
                    ? AppTheme.yellowAccent.withOpacity(0.4)
                    : Colors.transparent,
          ),
        ),
        child: Opacity(
          opacity: isActiveWindow ? 1.0 : 0.4,
          child: Row(
            children: [
              // 시간 라벨
              SizedBox(
                width: 55,
                child: Text(
                  _formatHour(hour),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.mutedTeal : isCurrent ? AppTheme.yellowAccent : AppTheme.textGray,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              
              // 게이지 바
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.timelineBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: minutes / 60,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.mutedTeal : (pct >= 80 ? AppTheme.mutedTeal : AppTheme.softIndigo),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Positioned(
                        left: 0,
                        right: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: currentMinute / 60,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 3,
                              height: 16,
                              color: AppTheme.yellowAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 퍼센트 및 분 텍스트
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      hasData ? '${minutes}분' : '—',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: hasData ? AppTheme.textWhite : AppTheme.textGray,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 28,
                      child: Text(
                        hasData ? '$pct%' : '',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.activeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 수면 라벨
              if (!isActiveWindow)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text('수면', style: TextStyle(color: AppTheme.textGray, fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
