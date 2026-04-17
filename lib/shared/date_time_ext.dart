extension RelativeTime on DateTime? {
  String toCompact() {
    final date = this;
    if (date == null) {
      return 'Unknown';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
