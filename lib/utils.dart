String fmtBytes(num b) {
  if (b < 1024) return '${b.toInt()} B';
  const units = ['KB', 'MB', 'GB'];
  double v = b / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

String fmtSpeed(double bps) => '${fmtBytes(bps)}/s';

String fmtDuration(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtEta(int sec) {
  if (sec < 60) return '$sec ث';
  if (sec < 3600) return '${sec ~/ 60} د';
  return '${sec ~/ 3600} س';
}
