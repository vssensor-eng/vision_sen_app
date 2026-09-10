import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class LocationEditorScreen extends StatefulWidget {
  final AppSession session; final Map<String,dynamic>? location; final String type; final int? parentId;
  const LocationEditorScreen({super.key,required this.session,this.location,required this.type,this.parentId});
  @override State<LocationEditorScreen> createState()=>_LocationEditorScreenState();
}
class _LocationEditorScreenState extends State<LocationEditorScreen>{
  late final TextEditingController name,description,address;int? parentId;
  @override void initState(){super.initState();final l=widget.location;name=TextEditingController(text:l?['name']?.toString()??'':'');description=TextEditingController(text:l?['description']?.toString()??'':'');address=TextEditingController(text:l?['address']?.toString()??'':'');parentId=l==null?widget.parentId:int.tryParse('${l['parent_id']}');}
  @override void dispose(){name.dispose();description.dispose();address.dispose();super.dispose();}
  String get type=>widget.location?['type']?.toString()??widget.type:widget.type;
  Future<void> save()async{if(name.text.trim().isEmpty){showSessionMessage(context,'Ad alanını doldurun.');return;}if(type!='building'&&parentId==null){showSessionMessage(context,'Üst konumu seçin.');return;}final ok=await widget.session.saveLocation(id:widget.location==null?null:int.tryParse('${widget.location!['id']}'),name:name.text.trim(),type:type,parentId:parentId,description:description.text.trim(),address:address.text.trim());if(!mounted)return;if(ok)Navigator.pop(context);else showSessionMessage(context,widget.session.error??'Konum kaydedilemedi.');}
  @override Widget build(BuildContext context){final parentType=type=='room'?'building':'room';final parents=widget.session.locations.where((l)=>l['type']==parentType).toList();final title=widget.location==null?(type=='building'?'Bina Ekle':type=='room'?'Oda Ekle':'Dolap Ekle'):'Konumu Düzenle';return Scaffold(body:AppBackground(child:ListView(padding:const EdgeInsets.fromLTRB(18,6,18,30),children:[MobileTopBar(title:title,subtitle:type=='building'?'Bina bilgileri':type=='room'?'Binaya bağlı oda':'Odaya bağlı dolap',actions:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),Panel(child:Column(children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Ad',prefixIcon:Icon(Icons.label_outline))),if(type!='building')...[const SizedBox(height:12),DropdownButtonFormField<int>(value:parentId,decoration:InputDecoration(labelText:type=='room'?'Bina':'Oda',prefixIcon:const Icon(Icons.account_tree_outlined)),items:parents.map((l)=>DropdownMenuItem<int>(value:int.tryParse('${l['id']}'),child:Text(locationPath(widget.session.locations,l['id'])))).where((x)=>x.value!=null).toList(),onChanged:widget.location==null?(v)=>setState(()=>parentId=v):null)],const SizedBox(height:12),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Açıklama')),if(type=='building')...[const SizedBox(height:12),TextField(controller:address,decoration:const InputDecoration(labelText:'Adres (opsiyonel)',prefixIcon:Icon(Icons.location_on_outlined)))],const SizedBox(height:18),PrimaryButton(text:widget.session.busy?'KAYDEDİLİYOR...':'KAYDET',icon:Icons.save_outlined,onPressed:widget.session.busy?null:save)]))])));}
}
