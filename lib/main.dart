import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

const reviewUrl = 'https://maps.app.goo.gl/wKGTJt8RZ7QqJqSu6';
final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await notifications.initialize(init);
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  runApp(const SVTApp());
}

class Booking {
  final String id, guest, phone, vehicleType, vehicleNumber, driver, tripDetails, billingMode;
  final DateTime startDate, endDate;
  final double startingKm, closingKm, toll, parking, total;
  final bool preBooking;

  const Booking({
    required this.id, required this.guest, required this.phone,
    required this.vehicleType, required this.vehicleNumber, required this.driver,
    required this.tripDetails, required this.startDate, required this.endDate,
    required this.startingKm, required this.closingKm, required this.toll,
    required this.parking, required this.billingMode, required this.total,
    required this.preBooking,
  });

  double get totalKm => (closingKm - startingKm).clamp(0, double.infinity);
  int get days => endDate.difference(startDate).inDays + 1;

  Map<String,dynamic> toJson() => {
    'id':id,'guest':guest,'phone':phone,'vehicleType':vehicleType,
    'vehicleNumber':vehicleNumber,'driver':driver,'tripDetails':tripDetails,
    'startDate':startDate.toIso8601String(),'endDate':endDate.toIso8601String(),
    'startingKm':startingKm,'closingKm':closingKm,'toll':toll,'parking':parking,
    'billingMode':billingMode,'total':total,'preBooking':preBooking,
  };

  factory Booking.fromJson(Map<String,dynamic> j) => Booking(
    id:j['id'], guest:j['guest']??'', phone:j['phone']??'',
    vehicleType:j['vehicleType']??'Sedan', vehicleNumber:j['vehicleNumber']??'',
    driver:j['driver']??'', tripDetails:j['tripDetails']??'',
    startDate:DateTime.parse(j['startDate']), endDate:DateTime.parse(j['endDate']),
    startingKm:(j['startingKm'] as num?)?.toDouble()??0,
    closingKm:(j['closingKm'] as num?)?.toDouble()??0,
    toll:(j['toll'] as num?)?.toDouble()??0,
    parking:(j['parking'] as num?)?.toDouble()??0,
    billingMode:j['billingMode']??'KM Based',
    total:(j['total'] as num?)?.toDouble()??0,
    preBooking:j['preBooking']??false,
  );
}

class SVTApp extends StatelessWidget {
  const SVTApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'SVT Tours and Transport', debugShowCheckedModeBanner:false,
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.green),useMaterial3:true),
    home:const BillingPage(),
  );
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override State<BillingPage> createState()=>_BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final keyForm=GlobalKey<FormState>();
  final guest=TextEditingController(), phone=TextEditingController(),
      vehicleNo=TextEditingController(), driver=TextEditingController(),
      details=TextEditingController(), startKm=TextEditingController(),
      closeKm=TextEditingController(), toll=TextEditingController(),
      parking=TextEditingController();

  String vehicle='Sedan', mode='KM Based';
  DateTime startDate=DateTime.now(), endDate=DateTime.now();
  bool preBooking=false, loading=true;
  double total=0,totalKm=0,sedanRate=20,suvRate=22,sedanDay=3500,suvDay=4500,
      includedKm=100,extraKmRate=20;
  int days=1;
  List<Booking> bookings=[];

  double get kmRate=>vehicle=='Sedan'?sedanRate:suvRate;
  double get dayRate=>vehicle=='Sedan'?sedanDay:suvDay;

  @override void initState(){super.initState();load();}
  @override void dispose(){
    for(final c in [guest,phone,vehicleNo,driver,details,startKm,closeKm,toll,parking]) c.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString('bookings');
    if(raw!=null){
      final list=jsonDecode(raw) as List;
      bookings=list.map((e)=>Booking.fromJson(Map<String,dynamic>.from(e))).toList();
    }
    sedanRate=p.getDouble('sedanRate')??20; suvRate=p.getDouble('suvRate')??22;
    sedanDay=p.getDouble('sedanDay')??3500; suvDay=p.getDouble('suvDay')??4500;
    includedKm=p.getDouble('includedKm')??100; extraKmRate=p.getDouble('extraKmRate')??20;
    setState(()=>loading=false); calc();
  }

  Future<void> save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('bookings',jsonEncode(bookings.map((e)=>e.toJson()).toList()));
    await p.setDouble('sedanRate',sedanRate); await p.setDouble('suvRate',suvRate);
    await p.setDouble('sedanDay',sedanDay); await p.setDouble('suvDay',suvDay);
    await p.setDouble('includedKm',includedKm); await p.setDouble('extraKmRate',extraKmRate);
  }

  void calc(){
    final s=double.tryParse(startKm.text)??0,c=double.tryParse(closeKm.text)??0;
    final t=double.tryParse(toll.text)??0,p=double.tryParse(parking.text)??0;
    totalKm=(c-s).clamp(0,double.infinity); days=endDate.difference(startDate).inDays+1;
    if(mode=='KM Based') total=totalKm*kmRate+t+p;
    else {
      final extra=totalKm>includedKm?totalKm-includedKm:0;
      total=dayRate*days+extra*extraKmRate+t+p;
    }
    setState((){});
  }

  String fmt(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> pickStart() async {
    final d=await showDatePicker(context:context,initialDate:startDate,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null){setState((){startDate=d;if(endDate.isBefore(d))endDate=d;});calc();}
  }
  Future<void> pickEnd() async {
    final d=await showDatePicker(context:context,initialDate:endDate,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null){if(d.isBefore(startDate)){msg('Closing date cannot be before starting date.');return;}setState(()=>endDate=d);calc();}
  }
  void msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));

  Future<void> saveBooking() async {
    if(!keyForm.currentState!.validate())return; calc();
    final b=Booking(
      id:DateTime.now().microsecondsSinceEpoch.toString(),guest:guest.text.trim(),
      phone:phone.text.trim(),vehicleType:vehicle,vehicleNumber:vehicleNo.text.trim(),
      driver:driver.text.trim(),tripDetails:details.text.trim(),startDate:startDate,
      endDate:endDate,startingKm:double.tryParse(startKm.text)??0,
      closingKm:double.tryParse(closeKm.text)??0,toll:double.tryParse(toll.text)??0,
      parking:double.tryParse(parking.text)??0,billingMode:mode,total:total,preBooking:preBooking,
    );
    bookings=[b,...bookings]; await save();
    if(preBooking) await reminder(b);
    msg('Booking saved successfully.');
  }

  Future<void> reminder(Booking b) async {
    final r=DateTime(b.startDate.year,b.startDate.month,b.startDate.day,9).subtract(const Duration(days:1));
    if(r.isBefore(DateTime.now()))return;
    await notifications.zonedSchedule(
      b.id.hashCode,'SVT Vehicle Booking Reminder',
      '${b.guest} • Vehicle required ${fmt(b.startDate)}',
      tz.TZDateTime.from(r,tz.local),
      const NotificationDetails(
        android:AndroidNotificationDetails('svt_booking','SVT Booking Reminders',
          channelDescription:'Upcoming vehicle booking reminders',
          importance:Importance.high,priority:Priority.high),
      ),
      androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
      payload:b.id,
    );
  }

  String bill(Booking b)=>'''
*SVT TOURS AND TRANSPORT*

Guest: ${b.guest}
Phone: ${b.phone}
Vehicle: ${b.vehicleType}
Vehicle No: ${b.vehicleNumber}
${b.driver.isEmpty?'':'Driver: ${b.driver}\n'}Starting Date: ${fmt(b.startDate)}
Closing Date: ${fmt(b.endDate)}
Duration: ${b.days} Days
Starting KM: ${b.startingKm.toStringAsFixed(1)}
Closing KM: ${b.closingKm.toStringAsFixed(1)}
Total KM: ${b.totalKm.toStringAsFixed(1)}
${b.tripDetails.isEmpty?'':'Details of Trip: ${b.tripDetails}\n'}
${b.toll>0?'Toll: ₹${b.toll.toStringAsFixed(2)}\n':''}${b.parking>0?'Parking: ₹${b.parking.toStringAsFixed(2)}\n':''}
*Total Amount: ₹${b.total.toStringAsFixed(2)}*

Thank you for choosing SVT Tours and Transport.
We appreciate your valuable support.

⭐ Google Review:
$reviewUrl
''';

  Future<Uint8List> pdfBytes(Booking b) async {
    final doc=pw.Document();
    doc.addPage(pw.Page(
      pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(32),
      build:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
        pw.Center(child:pw.Text('SVT TOURS AND TRANSPORT',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold))),
        pw.SizedBox(height:20),
        pw.Text('Guest: ${b.guest}'),pw.Text('Phone: ${b.phone}'),
        pw.Text('Vehicle: ${b.vehicleType}'),pw.Text('Vehicle No: ${b.vehicleNumber}'),
        if(b.driver.isNotEmpty)pw.Text('Driver: ${b.driver}'),
        pw.SizedBox(height:10),pw.Text('Starting Date: ${fmt(b.startDate)}'),
        pw.Text('Closing Date: ${fmt(b.endDate)}'),pw.Text('Duration: ${b.days} Days'),
        pw.SizedBox(height:10),pw.Text('Starting KM: ${b.startingKm.toStringAsFixed(1)}'),
        pw.Text('Closing KM: ${b.closingKm.toStringAsFixed(1)}'),
        pw.Text('Total KM: ${b.totalKm.toStringAsFixed(1)}'),
        if(b.tripDetails.isNotEmpty)pw.Padding(padding:const pw.EdgeInsets.only(top:10),child:pw.Text('Details of Trip: ${b.tripDetails}')),
        pw.SizedBox(height:14),if(b.toll>0)pw.Text('Toll: ₹${b.toll.toStringAsFixed(2)}'),
        if(b.parking>0)pw.Text('Parking: ₹${b.parking.toStringAsFixed(2)}'),pw.Divider(),
        pw.Align(alignment:pw.Alignment.centerRight,child:pw.Text('TOTAL: ₹${b.total.toStringAsFixed(2)}',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold))),
        pw.Spacer(),pw.Center(child:pw.Text('Thank you for choosing SVT Tours and Transport.')),
        pw.SizedBox(height:5),pw.Center(child:pw.Text('Google Review: $reviewUrl',style:const pw.TextStyle(fontSize:8))),
      ]),
    ));
    return doc.save();
  }

  Future<void> sharePdf(Booking b) async {
    await Printing.sharePdf(bytes:await pdfBytes(b),filename:'SVT_${b.guest}_${fmt(b.startDate).replaceAll('/','-')}.pdf');
  }

  Future<void> whatsapp(Booking b) async {
    final n=b.phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(n.length<10)return;
    await launchUrl(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(bill(b))}'),mode:LaunchMode.externalApplication);
  }

  Future<void> review() async=>launchUrl(Uri.parse(reviewUrl),mode:LaunchMode.externalApplication);

  Future<void> settings() async {
    final a=TextEditingController(text:'$sedanRate'),b=TextEditingController(text:'$suvRate'),
      c=TextEditingController(text:'$sedanDay'),d=TextEditingController(text:'$suvDay'),
      e=TextEditingController(text:'$includedKm'),f=TextEditingController(text:'$extraKmRate');
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:const Text('Internal Pricing Settings'),
      content:SingleChildScrollView(child:Column(children:[
        TextField(controller:a,decoration:const InputDecoration(labelText:'Sedan KM Rate')),
        TextField(controller:b,decoration:const InputDecoration(labelText:'SUV KM Rate')),
        TextField(controller:c,decoration:const InputDecoration(labelText:'Sedan Full Day Amount')),
        TextField(controller:d,decoration:const InputDecoration(labelText:'SUV Full Day Amount')),
        TextField(controller:e,decoration:const InputDecoration(labelText:'Included KM')),
        TextField(controller:f,decoration:const InputDecoration(labelText:'Extra KM Rate')),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:(){sedanRate=double.tryParse(a.text)??sedanRate;suvRate=double.tryParse(b.text)??suvRate;sedanDay=double.tryParse(c.text)??sedanDay;suvDay=double.tryParse(d.text)??suvDay;includedKm=double.tryParse(e.text)??includedKm;extraKmRate=double.tryParse(f.text)??extraKmRate;Navigator.pop(context,true);},child:const Text('Save')),
      ],
    ));
    for(final x in [a,b,c,d,e,f])x.dispose();
    if(ok==true){await save();calc();}
  }

  Future<void> history() async {
    DateTime? from,to; List<Booking> list=List.of(bookings);
    await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(context,setD){
      void filter(){list=bookings.where((b){
        final x=DateTime(b.startDate.year,b.startDate.month,b.startDate.day);
        return (from==null||!x.isBefore(DateTime(from!.year,from!.month,from!.day)))&&(to==null||!x.isAfter(DateTime(to!.year,to!.month,to!.day)));
      }).toList();setD((){});}
      return AlertDialog(title:const Text('Booking / Guest History'),content:SizedBox(width:double.maxFinite,height:450,child:Column(children:[
        Row(children:[
          Expanded(child:OutlinedButton(onPressed:()async{final x=await showDatePicker(context:context,initialDate:from??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(x!=null){from=x;filter();}},child:Text(from==null?'From':fmt(from!)))),
          const SizedBox(width:8),
          Expanded(child:OutlinedButton(onPressed:()async{final x=await showDatePicker(context:context,initialDate:to??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(x!=null){to=x;filter();}},child:Text(to==null?'To':fmt(to!)))),
        ]),
        TextButton(onPressed:(){from=null;to=null;filter();},child:const Text('Clear filter')),
        const Divider(),Expanded(child:list.isEmpty?const Center(child:Text('No bookings found.')):ListView.builder(
          itemCount:list.length,itemBuilder:(_,i){final b=list[i];return ListTile(
            title:Text(b.guest),subtitle:Text('${fmt(b.startDate)} • ${b.vehicleType} • ${b.totalKm.toStringAsFixed(1)} KM'),
            trailing:Text('₹${b.total.toStringAsFixed(0)}',style:const TextStyle(fontWeight:FontWeight.bold)),
            onTap:()=>showModalBottomSheet(context:context,builder:(_)=>SafeArea(child:Wrap(children:[
              ListTile(leading:const Icon(Icons.picture_as_pdf),title:const Text('PDF / Share'),onTap:(){Navigator.pop(context);sharePdf(b);}),
              ListTile(leading:const Icon(Icons.chat),title:const Text('WhatsApp Text Bill'),onTap:(){Navigator.pop(context);whatsapp(b);}),
            ]))),
          );},
        )),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]);
    }));
  }

  void clearForm(){for(final c in [guest,phone,vehicleNo,driver,details,startKm,closeKm,toll,parking])c.clear();setState((){startDate=DateTime.now();endDate=startDate;vehicle='Sedan';mode='KM Based';preBooking=false;total=0;totalKm=0;days=1;});}

  InputDecoration dec(String s)=>InputDecoration(labelText:s,border:const OutlineInputBorder());

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar:AppBar(title:const Text('SVT Tours and Transport'),actions:[
        IconButton(onPressed:settings,icon:const Icon(Icons.settings)),
        IconButton(onPressed:history,icon:const Icon(Icons.history)),
      ]),
      body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Form(key:keyForm,child:Column(children:[
        const Icon(Icons.directions_car,size:64),
        const Text('Car Rental & Taxi Billing',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        const SizedBox(height:16),
        SwitchListTile(title:const Text('Pre-Booking'),subtitle:const Text('Reminder one day before vehicle requirement'),value:preBooking,onChanged:(v)=>setState(()=>preBooking=v)),
        DropdownButtonFormField<String>(value:mode,decoration:dec('Billing Type'),items:const[
          DropdownMenuItem(value:'KM Based',child:Text('KM Based')),DropdownMenuItem(value:'Full Day',child:Text('Full Day'))],
          onChanged:(v){if(v!=null){setState(()=>mode=v);calc();}}),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:vehicle,decoration:dec('Vehicle Type'),items:const[
          DropdownMenuItem(value:'Sedan',child:Text('Sedan')),DropdownMenuItem(value:'SUV',child:Text('SUV'))],
          onChanged:(v){if(v!=null){setState(()=>vehicle=v);calc();}}),
        const SizedBox(height:10),
        TextFormField(controller:vehicleNo,decoration:dec('Vehicle Number'),validator:(v)=>v==null||v.trim().isEmpty?'Vehicle number നൽകുക':null),
        const SizedBox(height:10),
        TextFormField(controller:guest,decoration:dec('Guest'),validator:(v)=>v==null||v.trim().isEmpty?'Guest name നൽകുക':null),
        const SizedBox(height:10),
        TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:dec('Guest WhatsApp Number'),validator:(v)=>v==null||v.trim().length<10?'WhatsApp number നൽകുക':null),
        const SizedBox(height:10),
        TextFormField(controller:driver,decoration:dec('Driver Name (Optional)')),
        const SizedBox(height:10),
        TextFormField(controller:details,maxLines:2,decoration:dec('Details of Trip (Optional)')),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:OutlinedButton(onPressed:pickStart,child:Text('Starting Date\n${fmt(startDate)}'))),
          const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:pickEnd,child:Text('Closing Date\n${fmt(endDate)}'))),
        ]),
        Card(child:ListTile(title:const Text('Duration'),trailing:Text('$days Days'))),
        TextFormField(controller:startKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Starting KM'),onChanged:(_)=>calc(),validator:(v)=>double.tryParse(v??'')==null?'Starting KM നൽകുക':null),
        const SizedBox(height:10),
        TextFormField(controller:closeKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Closing KM'),onChanged:(_)=>calc(),validator:(v){final c=double.tryParse(v??''),s=double.tryParse(startKm.text)??0;return c==null||c<s?'Closing KM ശരിയാക്കുക':null;}),
        Card(child:ListTile(title:const Text('Total KM'),trailing:Text(totalKm.toStringAsFixed(1),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))),
        TextFormField(controller:toll,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Toll Amount (Optional)'),onChanged:(_)=>calc()),
        const SizedBox(height:10),
        TextFormField(controller:parking,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Parking Amount (Optional)'),onChanged:(_)=>calc()),
        const SizedBox(height:16),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
          const Text('TOTAL AMOUNT',style:TextStyle(fontWeight:FontWeight.bold)),Text('₹${total.toStringAsFixed(2)}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold))
        ]))),
        const SizedBox(height:10),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saveBooking,icon:const Icon(Icons.save),label:const Text('Save Booking / Bill'))),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{
          if(!keyForm.currentState!.validate())return;calc();
          final b=Booking(id:DateTime.now().microsecondsSinceEpoch.toString(),guest:guest.text.trim(),phone:phone.text.trim(),vehicleType:vehicle,vehicleNumber:vehicleNo.text.trim(),driver:driver.text.trim(),tripDetails:details.text.trim(),startDate:startDate,endDate:endDate,startingKm:double.tryParse(startKm.text)??0,closingKm:double.tryParse(closeKm.text)??0,toll:double.tryParse(toll.text)??0,parking:double.tryParse(parking.text)??0,billingMode:mode,total:total,preBooking:preBooking);
          await sharePdf(b);
        },icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF → WhatsApp / Share'))),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:review,icon:const Icon(Icons.star),label:const Text('Review us on Google'))),
        TextButton.icon(onPressed:history,icon:const Icon(Icons.history),label:const Text('Booking / Guest History')),
        TextButton(onPressed:clearForm,child:const Text('Clear Form')),      ],
    ),
  ),
);
}
}
