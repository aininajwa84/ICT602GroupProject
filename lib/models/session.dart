class Session {
  final String matric;
  final DateTime start;
  final DateTime end;

  Session({required this.matric, required this.start, required this.end});

  Duration get duration => end.difference(start);
}
