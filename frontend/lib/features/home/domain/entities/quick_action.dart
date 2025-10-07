import 'package:flutter/material.dart';

class QuickActionCard {
  const QuickActionCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    this.icon,
  });

  factory QuickActionCard.fromJson(Map<String, dynamic> json) {
    return QuickActionCard(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      background: Color(json['background_color'] as int),
      foreground: Color(json['foreground_color'] as int),
      icon: _iconFromJson(json['icon']),
    );
  }

  static IconData? _iconFromJson(Object? raw) {
    final value = (raw as String?)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    switch (value) {
      case 'diary':
        return Icons.edit_note_outlined;
      case 'habit':
        return Icons.event_available_outlined;
      case 'task':
        return Icons.fact_check_outlined;
      case 'voice':
        return Icons.mic_none_outlined;
      default:
        return null;
    }
  }

  final String id;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final IconData? icon;
}
