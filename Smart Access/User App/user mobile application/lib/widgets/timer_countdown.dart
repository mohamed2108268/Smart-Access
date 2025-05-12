import 'package:flutter/material.dart';
import 'dart:async';

class TimerCountdown extends StatefulWidget {
  final int seconds;
  final VoidCallback onFinished;

  const TimerCountdown({
    super.key,
    required this.seconds,
    required this.onFinished,
  });

  @override
  State<TimerCountdown> createState() => _TimerCountdownState();
}

class _TimerCountdownState extends State<TimerCountdown> {
  late int _currentSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.seconds;
    _startTimer();
  }

  @override
  void didUpdateWidget(TimerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds != oldWidget.seconds) {
      _timer?.cancel();
      _currentSeconds = widget.seconds;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else {
          _timer?.cancel();
          widget.onFinished();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentSeconds / widget.seconds;
    final colorValue = _getTimerColor(progress);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer,
              color: colorValue,
            ),
            const SizedBox(width: 8),
            Text(
              'Time Remaining: $_currentSeconds seconds',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorValue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(colorValue),
        ),
      ],
    );
  }

  Color _getTimerColor(double progress) {
    if (progress > 0.6) {
      return Colors.green;
    } else if (progress > 0.3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
