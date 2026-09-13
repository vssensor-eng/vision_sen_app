import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SensorLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String unit;
  final int hours;
  final double height;

  const SensorLineChart({
    super.key,
    required this.points,
    required this.unit,
    required this.hours,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SensorChartPainter(points: points, unit: unit, hours: hours),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SensorChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final String unit;
  final int hours;

  _SensorChartPainter({
    required this.points,
    required this.unit,
    required this.hours,
  });

  double? _number(dynamic value) => double.tryParse('$value');

  String _yLabel(double value) {
    return value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _xLabel(int index) {
    if (points.isEmpty) return '';
    final bucket = num.tryParse('${points[index]['bucket']}');
    if (bucket == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(
      bucket.toInt() * 1000,
      isUtc: true,
    ).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return hours <= 24
        ? '${two(date.hour)}:${two(date.minute)}'
        : '${two(date.day)}.${two(date.month)}';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppTheme.muted, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();

    var dx = offset.dx;
    if (align == TextAlign.right) {
      dx -= painter.width;
    } else if (align == TextAlign.center) {
      dx -= painter.width / 2;
    }
    painter.paint(canvas, Offset(dx, offset.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .map((point) => _number(point['value']))
        .whereType<double>()
        .toList();
    if (values.length < 2) return;

    final minimums = points
        .map((point) => _number(point['min_value']) ?? _number(point['value']))
        .whereType<double>()
        .toList();
    final maximums = points
        .map((point) => _number(point['max_value']) ?? _number(point['value']))
        .whereType<double>()
        .toList();
    if (minimums.isEmpty || maximums.isEmpty) return;

    var minValue = minimums.reduce((a, b) => a < b ? a : b);
    var maxValue = maximums.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue).abs() < .0001) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final padding = (maxValue - minValue) * .08;
      minValue -= padding;
      maxValue += padding;
    }

    const left = 48.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 30.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final axis = Paint()
      ..color = AppTheme.muted.withOpacity(.45)
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = AppTheme.line
      ..strokeWidth = 1;

    canvas.drawLine(const Offset(left, top), Offset(left, top + height), axis);
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + width, top + height),
      axis,
    );

    for (var i = 0; i <= 4; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final value = maxValue - (maxValue - minValue) * i / 4;
      _drawText(
        canvas,
        '${_yLabel(value)}${unit.isEmpty ? '' : ' $unit'}',
        Offset(left - 5, y),
        align: TextAlign.right,
      );
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = left + width * i / (values.length - 1);
      final y = top + height -
          (values[i] - minValue) / (maxValue - minValue) * height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final line = Paint()
      ..color = AppTheme.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    final tickIndexes = <int>{
      0,
      (points.length - 1) ~/ 3,
      ((points.length - 1) * 2) ~/ 3,
      points.length - 1,
    }.toList()
      ..sort();

    for (final index in tickIndexes) {
      final x = left + width * index / (points.length - 1);
      canvas.drawLine(
        Offset(x, top + height),
        Offset(x, top + height + 4),
        axis,
      );
      _drawText(
        canvas,
        _xLabel(index),
        Offset(x, top + height + 16),
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SensorChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.unit != unit ||
        oldDelegate.hours != hours;
  }
}
