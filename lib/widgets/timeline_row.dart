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
                      : isActiveWindow
                          ? AppTheme.textGray.withOpacity(0.03) // 활동 시간인데 미기록인 경우 아주 미세한 배경 추가
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
          child:          Row(
            children: [
              // 시간 라벨 (AM/PM 작게 처리)
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        height: 1.0,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? AppTheme.mutedTeal 
                            : isCurrent 
                                ? AppTheme.yellowAccent 
                                : (isActiveWindow ? AppTheme.textWhite.withOpacity(0.9) : AppTheme.textGray),
                      ),
                    ),
                    Text(
                      hour < 12 ? "AM" : "PM",
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.0,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.mutedTeal.withOpacity(0.8) : AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // 게이지 바
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActiveWindow ? AppTheme.timelineBg.withOpacity(0.5) : AppTheme.timelineBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (minutes / 60).clamp(0.0, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.mutedTeal : (pct >= 80 ? AppTheme.mutedTeal : AppTheme.softIndigo),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Positioned(
                        left: 0,
                        right: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (currentMinute / 60).clamp(0.0, 1.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 3,
                              height: 14,
                              color: AppTheme.yellowAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 퍼센트 및 분 텍스트
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      hasData ? '${minutes}분' : '—',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: hasData ? AppTheme.textWhite : AppTheme.textGray.withOpacity(isActiveWindow ? 0.6 : 0.3),
                        fontSize: 10,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasData ? '$pct%' : '',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: pct >= 80 ? AppTheme.activeGreen : AppTheme.softIndigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
