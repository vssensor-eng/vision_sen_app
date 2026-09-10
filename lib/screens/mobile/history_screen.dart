import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class HistoryScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> sensor;
  const HistoryScreen({super.key, required this.session, required this.sensor});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int hours = 24;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> points = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.session.api.history(int.parse('${widget.sensor['id']}'), hours: hours);
      final raw = data['points'];
      points = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _rangeLabel(int value) {
    switch (value) {
      case 1: return '1 Sa';
      case 6: return '6 Sa';
      case 24: return '24 Sa';
      case 168: return '7 Gün';
      case 720: return '30 Gün';
      case 2160: return '90 Gün';
      default: return '$value Sa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.sensor['metric']?.toString() ?? '';
    final catalog = widget.session.metricCatalog;
    final label = widget.sensor['name']?.toString() ?? metricLabel(metric, catalog);
    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(title: label, subtitle: 'Sensör geçmişi', actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in const [1, 6, 24, 168, 720, 2160])
                  ChoiceChip(
                    selected: hours == option,
                    label: Text(_rangeLabel(option)),
                    onSelected: (_) { setState(() => hours = option); _load(); },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              child: SizedBox(
                height: 260,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(child: Text(error!, style: const TextStyle(color: Color(0xFFFF7A7A))))
                        : points.isEmpty
                            ? const Center(child: Text('Bu aralıkta veri yok.', style: TextStyle(color: AppTheme.muted)))
                            : CustomPaint(painter: _LineChartPainter(points: points), child: const SizedBox.expand()),
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Son değer', style: TextStyle(color: AppTheme.muted)),
                  Text(formatValue(widget.sensor['latest_value'], metricUnit(metric, catalog)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => double.tryParse('${p['value']}')).whereType<double>().toList();
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < .0001 ? 1.0 : maxV - minV;
    final grid = Paint()..color = AppTheme.line..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / span) * (size.height - 16) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()..color = AppTheme.cyan..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.points != points;
}
