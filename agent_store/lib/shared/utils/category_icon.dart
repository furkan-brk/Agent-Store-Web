import 'package:flutter/material.dart';

IconData categoryIcon(String category) => switch (category.toLowerCase()) {
  'backend'                    => Icons.code_rounded,
  'frontend'                   => Icons.palette_rounded,
  'data' || 'analytics'        => Icons.bar_chart_rounded,
  'security'                   => Icons.shield_rounded,
  'creative'                   => Icons.auto_awesome_rounded,
  'business' || 'marketing'    => Icons.business_center_rounded,
  'research'                   => Icons.science_rounded,
  'planning' || 'pm'           => Icons.map_rounded,
  'infrastructure' || 'devops' => Icons.dns_rounded,
  _                            => Icons.auto_awesome_rounded,
};
