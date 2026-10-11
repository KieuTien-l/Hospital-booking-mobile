import 'package:flutter/material.dart';

enum FaqCategory {
  account('Tài khoản'),
  booking('Đặt khám'),
  payment('Thanh toán');

  const FaqCategory(this.label);
  final String label;
}

class UsageGuideUiModel {
  const UsageGuideUiModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
  });
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> steps;
}

class FaqUiModel {
  const FaqUiModel({
    required this.id,
    required this.question,
    required this.category,
    required this.answer,
  });
  final String id;
  final String question;
  final FaqCategory category;
  final String answer;
}
