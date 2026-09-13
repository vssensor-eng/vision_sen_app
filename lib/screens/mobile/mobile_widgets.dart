import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MobileTopBar extends StatelessWidget {
  final String title; final String? subtitle; final List<Widget> actions;
  const MobileTopBar({super.key, required this.title, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18,14,12,10), child: Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),if(subtitle!=null)...[const SizedBox(height:2),Text(subtitle!,style:const TextStyle(color:AppTheme.muted,fontSize:12))]])),...actions]));
}

class MetricTile extends StatelessWidget {
  final IconData icon; final String label,value; final Color color;
  const MetricTile({super.key, required this.icon, required this.label, required this.value, this.color=AppTheme.cyan});
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.95),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.line)),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:color)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppTheme.muted,fontSize:11)),const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]))]));
}

Map<String,dynamic> _metricInfo(String metric,[Map<String,dynamic>? catalog]) { final raw=catalog?[metric]; return raw is Map?Map<String,dynamic>.from(raw):const {}; }
String metricLabel(String metric,[Map<String,dynamic>? catalog]) { final v=_metricInfo(metric,catalog)['label']; if(v is String&&v.trim().isNotEmpty)return v; const labels={'temperature':'Sıcaklık','humidity':'Bağıl Nem','dew_point':'Çiğ Noktası','co2':'CO₂','voc':'VOC','voc_ppb':'VOC','voc_ug_m3':'VOC','pm1_0':'PM1.0','pm2_5':'PM2.5','pm10':'PM10','pressure':'Atmosfer Basıncı','light':'Işık Şiddeti','noise':'Gürültü','air_speed':'Hava Hızı','aqi':'Hava Kalitesi AQI','smoke':'Duman','fire':'Yangın','battery':'Batarya Seviyesi','signal_strength':'Sinyal Gücü'}; return labels[metric]??metric.replaceAll('_',' '); }
String metricUnit(String metric,[Map<String,dynamic>? catalog]) { final v=_metricInfo(metric,catalog)['unit']; if(v is String)return v; const units={'temperature':'°C','dew_point':'°C','humidity':'%RH','co2':'ppm','voc':'ppb/µg/m³','voc_ppb':'ppb','voc_ug_m3':'µg/m³','pm1_0':'µg/m³','pm2_5':'µg/m³','pm10':'µg/m³','pressure':'hPa','light':'lux','noise':'dB','air_speed':'m/s','battery':'%','signal_strength':'dBm'}; return units[metric]??''; }
IconData metricIcon(String metric) { switch(metric){case'temperature':return Icons.thermostat;case'humidity':return Icons.water_drop_outlined;case'dew_point':return Icons.water_outlined;case'co2':return Icons.cloud_outlined;case'pressure':return Icons.speed;case'light':return Icons.light_mode_outlined;case'noise':return Icons.graphic_eq;case'air_speed':return Icons.air;case'battery':return Icons.battery_5_bar;case'signal_strength':return Icons.network_wifi;case'smoke':return Icons.cloud_queue;case'fire':return Icons.local_fire_department_outlined;case'pm1_0':case'pm2_5':case'pm10':case'aqi':return Icons.blur_on;default:return Icons.sensors;} }
Color metricColor(String metric){switch(metric){case'temperature':case'fire':return const Color(0xFFFF7A6B);case'humidity':case'dew_point':return AppTheme.cyan;case'battery':return AppTheme.green;case'smoke':case'co2':case'aqi':return const Color(0xFFFFB85C);default:return AppTheme.cyan;}}
String formatValue(dynamic raw,[String unit='']) { if(raw==null||raw=='')return '—'; final n=num.tryParse(raw.toString()); final value=n==null?raw.toString():(n%1==0?n.toStringAsFixed(0):n.toStringAsFixed(1)); return unit.isEmpty?value:'$value $unit'; }
bool truthy(dynamic v)=>v==true||v==1||v=='1';
DateTime? parseServerTime(dynamic raw){if(raw is! String||raw.isEmpty)return null;final n=raw.contains('T')?raw:'${raw.replaceFirst(' ','T')}Z';return DateTime.tryParse(n)?.toLocal();}
bool isOnline(Map<String,dynamic> device,{int offlineMinutes=3}) { final dt=parseServerTime(device['last_seen']); if(dt==null)return false; return DateTime.now().difference(dt).inMinutes<=offlineMinutes; }
String ago(dynamic raw){final dt=parseServerTime(raw);if(dt==null)return 'Henüz veri yok';final d=DateTime.now().difference(dt);if(d.inSeconds<60)return '${d.inSeconds.clamp(0,59)} sn önce';if(d.inMinutes<60)return '${d.inMinutes} dk önce';if(d.inHours<24)return '${d.inHours} sa önce';return '${d.inDays} gün önce';}
String locationPath(List<Map<String,dynamic>> locations,dynamic id){final map={for(final l in locations)'${l['id']}':l};final parts=<String>[];var cur=map['$id'];for(var i=0;cur!=null&&i<4;i++){parts.insert(0,cur['name']?.toString()??'');cur=map['${cur['parent_id']}'];}return parts.where((e)=>e.isNotEmpty).join(' / ');}
Future<bool> confirmDelete(BuildContext context,String title,String message) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('VAZGEÇ')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('SİL'))]))??false;
void showSessionMessage(BuildContext context,String message,{bool error=false})=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
