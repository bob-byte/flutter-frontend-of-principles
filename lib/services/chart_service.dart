class ChartPoint {
  ChartPoint(this.x, this.y);
  final double x;
  final double y;
}

class ChartService {
  List<ChartPoint> buildProgressSeries(List<int> values) {
    return values.asMap().entries.map((e) => ChartPoint(e.key.toDouble(), e.value.toDouble())).toList();
  }
}
