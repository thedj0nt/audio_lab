String formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatDb(double volume) {
  if (volume <= 0.001) return '-inf dB';
  final db = (volume - 1.0) * 40.0;
  return '${db.toStringAsFixed(1)} dB';
}
