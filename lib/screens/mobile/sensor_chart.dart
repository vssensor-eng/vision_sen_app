import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SensorLineChart extends StatelessWidget {
  final List<Map<String,dynamic>> points; final String unit; final int hours; final double height;
  const SensorLineChart({super.key,required this.points,required this.unit,required this.hours,this.height=280});
  @override
  Widget build(BuildContext context)=>SizedBox(height:height,child:CustomPaint(painter:_SensorChartPainter(points:points,unit:unit,hours:hours),child:const SizedBox.expand()));
}

class _SensorChartPainter extends CustomPainter {
  final List<Map<String,dynamic>> points; final String unit; final int hours;
  _SensorChartPainter({required this.points,required this.unit,required this.hours});
  double? _n(dynamic v)=>double.tryParse('$v');
  String _y(double v)=>v.abs()>=100? v.toStringAsFixed(0):v.toStringAsFixed(1);
  String _x(int index){
    if(points.isEmpty)return ''; final b=num.tryParse('${points[index]['bucket']}'); if(b==null)return '';
    final d=DateTime.fromMillisecondsSinceEpoch(b.toInt()*1000,isUtc:true).toLocal();
    String two(int n)=>n.toString().padLeft(2,'0');
    return hours<=24?'${two(d.hour)}:${two(d.minute)}':'${two(d.day)}.${two(d.month)}';
  }
  void _text(Canvas c,String text,Offset o,{TextAlign align=TextAlign.left}){final p=TextPainter(text:TextSpan(text:text,style:const TextStyle(color:AppTheme.muted,fontSize:9)),textDirection:TextDirection.ltr,textAlign:align)..layout();p.paint(c,Offset(o.dx-(align==TextAlign.right?p.width:align==TextAlign.center?p.width/2:0),o.dy-p.height/2));}
  @override
  void paint(Canvas canvas,Size size){
    final vals=points.map((p)=>_n(p['value'])).whereType<double>().toList(); if(vals.length<2)return;
    final rawMin=points.map((p)=>_n(p['min_value'])??_n(p['value'])).whereType<double>().reduce((a,b)=>a<b?a:b);
    final rawMax=points.map((p)=>_n(p['max_value'])??_n(p['value'])).whereType<double>().reduce((a,b)=>a>b?a:b);
    var minV=rawMin,maxV=rawMax;if((maxV-minV).abs()<.0001){minV-=1;maxV+=1;}else{final pad=(maxV-minV)*.08;minV-=pad;maxV+=pad;}
    const left=48.0,right=10.0,top=10.0,bottom=30.0;final w=size.width-left-right,h=size.height-top-bottom;
    final axis=Paint()..color=AppTheme.muted.withOpacity(.45)..strokeWidth=1;final grid=Paint()..color=AppTheme.line..strokeWidth=1;
    canvas.drawLine(const Offset(left,top),Offset(left,top+h),axis);canvas.drawLine(Offset(left,top+h),Offset(left+w,top+h),axis);
    for(var i=0;i<=4;i++){final y=top+h*i/4;canvas.drawLine(Offset(left,y),Offset(left+w,y),grid);final v=maxV-(maxV-minV)*i/4;_text(canvas,'${_y(v)}${unit.isEmpty?'':' $unit'}',Offset(left-5,y),align:TextAlign.right);}
    final path=Path();for(var i=0;i<vals.length;i++){final x=left+w*i/(vals.length-1);final y=top+h-(vals[i]-minV)/(maxV-minV)*h;if(i==0)path.moveTo(x,y);else path.lineTo(x,y);}final line=Paint()..color=AppTheme.cyan..style=PaintingStyle.stroke..strokeWidth=2.4..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;canvas.drawPath(path,line);
    final ticks=<int>{0,(points.length-1)~/3,((points.length-1)*2)~/3,points.length-1}.toList()..sort();for(final i in ticks){final x=left+w*i/(points.length-1);canvas.drawLine(Offset(x,top+h),Offset(x,top+h+4),axis);_text(canvas,_x(i),Offset(x,top+h+16),align:TextAlign.center);}
  }
  @override bool shouldRepaint(covariant _SensorChartPainter old)=>old.points!=points||old.unit!=unit||old.hours!=hours;
}
