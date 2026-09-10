import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MobileTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const MobileTopBar({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const MetricTile({super.key, required this.icon, required this.label, required this.value, this.color = AppTheme.cyan});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.panel.withOpacity(.95),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
}

String metricLabel(String metric) {
  switch (metric) {
    case 'temperature': return 'Sıcaklık';
    case 'humidity': return 'Nem';
    case 'dew_point': return 'Çiğ Noktası';
    case 'pressure': return 'Basınç';
    case 'co2': return 'CO₂';
    case 'rainfall': return 'Yağış';
    case 'wind_speed': return 'Rüzgâr Hızı';
    case 'wind_direction': return 'Rüzgâr Yönü';
    case 'solar_radiation': return 'Güneş Radyasyonu';
    default: return metric.replaceAll('_', ' ');
  }
}

String metricUnit(String metric) {
  switch (metric) {
    case 'temperature':
    case 'dew_point': return '°C';
    case 'humidity': return '%';
    case 'pressure': return 'hPa';
    case 'co2': return 'ppm';
    case 'rainfall': return 'mm';
    case 'wind_speed': return 'm/s';
    case 'wind_direction': return '°';
    case 'solar_radiation': return 'W/m²';
    default: return '';
  }
}

String formatValue(dynamic raw, [String unit = '']) {
  if (raw == null || raw == '') return '—';
  final n = num.tryParse(raw.toString());
  final value = n == null ? raw.toString() : (n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(1));
  return unit.isEmpty ? value : '$value $unit';
}

bool isOnline(Map<String, dynamic> device, {int offlineMinutes = 3}) {
  final raw = device['last_seen'];
  if (raw is! String || raw.isEmpty) return false;
  final normalized = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return false;
  return DateTime.now().toUtc().difference(dt.toUtc()).inMinutes <= offlineMinutes;
}

String ago(dynamic raw) {
  if (raw is! String || raw.isEmpty) return 'Henüz veri yok';
  final normalized = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return raw;
  final d = DateTime.now().toUtc().difference(dt.toUtc());
  if (d.inSeconds < 60) return '${d.inSeconds.clamp(0, 59)} sn önce';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  return '${d.inDays} gün önce';
}
