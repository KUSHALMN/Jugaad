// lib/features/user/screens/matching/widgets/typewriter_status_text.dart
// ═══════════════════════════════════════════════════════════════════
// Animated typewriter status text displaying rotating scan stages.
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';

class TypewriterStatusText extends StatefulWidget {
  final String serviceType;
  const TypewriterStatusText({super.key, required this.serviceType});

  @override
  State<TypewriterStatusText> createState() => _TypewriterStatusTextState();
}

class _TypewriterStatusTextState extends State<TypewriterStatusText> {
  late List<String> _statuses;
  int _currentIndex = 0;
  String _displayText = '';
  Timer? _cycleTimer;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _initStatuses();
    _startCycle();
  }

  @override
  void didUpdateWidget(covariant TypewriterStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceType != widget.serviceType) {
      _initStatuses();
    }
  }

  void _initStatuses() {
    final displayService = widget.serviceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');

    _statuses = [
      'Scanning Mysuru coordinates...',
      'Locating active ${displayService}s...',
      'Checking live availability near you...',
      'Optimizing nearest routes...',
    ];
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startCycle() {
    _typewriterEffect();
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _statuses.length;
        });
        _typewriterEffect();
      }
    });
  }

  void _typewriterEffect() {
    _typewriterTimer?.cancel();
    final fullText = _statuses[_currentIndex];
    int charIndex = 0;
    _displayText = '';
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < fullText.length) {
        setState(() {
          _displayText += fullText[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      child: Text(
        _displayText,
        style: UserAppTheme.body(
          size: 15,
          color: Colors.white,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
