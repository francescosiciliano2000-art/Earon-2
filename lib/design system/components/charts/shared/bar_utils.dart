String month3(String full) => full.substring(0, 3);

String fmtDateLabel(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${m[d.month - 1]} ${d.day}';
}

String fmtDateFull(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

String browserLabel(String key) => switch (key) {
      'chrome' => 'Chrome',
      'safari' => 'Safari',
      'firefox' => 'Firefox',
      'edge' => 'Edge',
      _ => 'Other',
    };
