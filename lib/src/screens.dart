import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data.dart';
import 'design.dart';
import 'market.dart';

void showError(BuildContext context,Object error) {
  if(!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(error.toString().replaceAll('Bad state: ',''))));
}

class WelcomeScreen extends StatefulWidget {
  final AyarData data;
  const WelcomeScreen({super.key,required this.data});
  @override State<WelcomeScreen> createState()=>_WelcomeScreenState();
}
class _WelcomeScreenState extends State<WelcomeScreen> {
  bool loading=false;
  Future<void> start() async {
    if(loading) return;
    setState(()=>loading=true);
    try {
      await widget.data.signInGuest();
      if(!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder:(_)=>AyarShell(data:widget.data)));
    } catch(e) {showError(context,e);} finally {
      if(mounted) setState(()=>loading=false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body:SafeArea(child:Padding(padding:const EdgeInsets.all(28),child:
      Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Spacer(flex:2),
        const Center(child:GoldMark(size:106)),
        const SizedBox(height:25),
        Text('عيار',textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.displayMedium?.copyWith(
            color:AyarColors.paleGold,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        const Text('ذهب السودان، بصورة أوضح.',textAlign:TextAlign.center,
          style:TextStyle(color:AyarColors.muted,fontSize:17)),
        const SizedBox(height:26),
        const AyarPanel(child:Column(children:[
          _FeatureText('أونصة الذهب العالمية'),SizedBox(height:14),
          _FeatureText('تسعير بالعملة المحلية'),SizedBox(height:14),
          _FeatureText('حاسبة وتنبيهات شخصية'),
        ])),
        const Spacer(flex:3),
        FilledButton(onPressed:loading?null:start,
          style:FilledButton.styleFrom(padding:const EdgeInsets.all(17),
            backgroundColor:AyarColors.gold,foregroundColor:AyarColors.background),
          child:loading?const SizedBox(width:22,height:22,
            child:CircularProgressIndicator(strokeWidth:2)):
            const Text('الدخول كزائر',style:TextStyle(fontWeight:FontWeight.w700))),
        const SizedBox(height:12),
        const Text('الأسعار استرشادية ولا تشمل المصنعية وهوامش التداول',
          textAlign:TextAlign.center,style:TextStyle(color:AyarColors.muted,fontSize:11)),
        const SizedBox(height:10),
      ]))),
  );
}
class _FeatureText extends StatelessWidget {
  final String text;
  const _FeatureText(this.text);
  @override Widget build(BuildContext context) => Row(children:[
    const Icon(LucideIcons.check,size:17,color:AyarColors.green),
    const SizedBox(width:12),Text(text),
  ]);
}

class AyarShell extends StatefulWidget {
  final AyarData data;
  const AyarShell({super.key,required this.data});
  @override State<AyarShell> createState()=>_AyarShellState();
}
class _AyarShellState extends State<AyarShell> {
  int tab=0;
  late final Stream<MarketQuote> quoteStream=widget.data.watchQuote();
  late final Stream<List<PriceAlert>> alertStream=widget.data.watchAlerts();
  late final Stream<List<MarketBulletin>> bulletinStream=widget.data.watchBulletins();
  StreamSubscription<RemoteMessage>? foregroundNotifications;
  @override void initState() {
    super.initState();
    if (widget.data is FirebaseData) {
      foregroundNotifications=FirebaseMessaging.onMessage.listen((message) {
        if(!mounted) return;
        final text=message.notification?.body ?? 'وصل تنبيه سعر جديد';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
      });
    }
  }
  @override void dispose() {
    foregroundNotifications?.cancel();
    super.dispose();
  }
  Future<void> openAdmin() async {
    try {
      if(widget.data is! PreviewData && !await widget.data.isAdmin()) {
        if(!mounted) return;
        final ok=await showDialog<bool>(context:context,builder:(_)=>AdminSignIn(data:widget.data));
        if(ok!=true || !mounted) return;
      }
      if(!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder:(_)=>AdminScreen(data:widget.data)));
    } catch(e) {showError(context,e);}
  }
  @override Widget build(BuildContext context) => StreamBuilder<MarketQuote>(
    stream:quoteStream,
    builder:(context,snapshot) {
      final quote = snapshot.data ?? const MarketQuote(ounceUsd:null,fxSdgPerUsd:null);
      return Scaffold(
        appBar:AppBar(toolbarHeight:76,
          title:Row(children:[const GoldMark(size:38),const SizedBox(width:10),
            Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('عيار',style:TextStyle(fontWeight:FontWeight.w800,fontSize:22)),
              Text('AYAR • SUDAN',style:Theme.of(context).textTheme.labelSmall?.copyWith(
                color:AyarColors.muted,letterSpacing:1.25)),
            ])]),
          actions:[IconButton(tooltip:'لوحة الإدارة',onPressed:openAdmin,
            icon:const Icon(LucideIcons.settings,color:AyarColors.paleGold)),
            const SizedBox(width:10)]),
        body:snapshot.hasError && !snapshot.hasData
          ? Center(child:Padding(padding:const EdgeInsets.all(24),child:
            Text('تعذر الوصول للأسعار: ${snapshot.error}',textAlign:TextAlign.center)))
          : snapshot.connectionState==ConnectionState.waiting && !snapshot.hasData
          ? const Center(child:CircularProgressIndicator(color:AyarColors.gold))
          : IndexedStack(index:tab,children:[
              PriceScreen(quote:quote),
              CalculatorScreen(quote:quote),
              AlertsScreen(data:widget.data,quote:quote,alerts:alertStream),
              BulletinScreen(data:widget.data,bulletins:bulletinStream),
            ]),
        bottomNavigationBar:NavigationBar(
          backgroundColor:AyarColors.panel,
          indicatorColor:AyarColors.gold.withValues(alpha:.14),
          selectedIndex:tab,
          onDestinationSelected:(value)=>setState(()=>tab=value),
          destinations:const [
            NavigationDestination(icon:Icon(LucideIcons.house),label:'الأسعار'),
            NavigationDestination(icon:Icon(LucideIcons.calculator),label:'الحاسبة'),
            NavigationDestination(icon:Icon(LucideIcons.bell),label:'التنبيهات'),
            NavigationDestination(icon:Icon(LucideIcons.newspaper),label:'النشرة'),
          ],
        ),
      );
    },
  );
}

class PriceScreen extends StatelessWidget {
  final MarketQuote quote;
  const PriceScreen({super.key,required this.quote});
  @override Widget build(BuildContext context) => ListView(
    padding:const EdgeInsets.fromLTRB(18,8,18,28),children:[
      const Text('الأسعار اليوم',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
      const SizedBox(height:7),
      Text('مؤشر الذهب العالمي وتسعيره بالجنيه السوداني',
        style:Theme.of(context).textTheme.bodySmall?.copyWith(color:AyarColors.muted)),
      const SizedBox(height:20),
      _GoldHero(quote:quote),
      const SizedBox(height:14),
      AyarPanel(child:Row(children:[
        Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(
          color:AyarColors.gold.withValues(alpha:.12),
          borderRadius:BorderRadius.circular(13)),
          child:const Icon(LucideIcons.wallet,color:AyarColors.gold)),
        const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('الدولار في السوق المحلي',style:TextStyle(color:AyarColors.muted,fontSize:12)),
          const SizedBox(height:5),
          AnimateNumber('${money(quote.fxSdgPerUsd,decimals:2)} SDG',
            style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
          Text('يحدده مدير التطبيق • ${ago(quote.fxUpdatedAt)}',
            style:const TextStyle(color:AyarColors.muted,fontSize:10)),
        ])),
      ])),
      const SizedBox(height:24),
      const SectionHeader('أسعار العيارات',subtitle:'قيمة الذهب الخام للجرام الواحد'),
      const SizedBox(height:13),
      Row(children:[
        Expanded(child:_KaratCard(quote:quote,karat:24)),const SizedBox(width:9),
        Expanded(child:_KaratCard(quote:quote,karat:21)),const SizedBox(width:9),
        Expanded(child:_KaratCard(quote:quote,karat:18)),
      ]),
      const SizedBox(height:14),
      AyarPanel(child:Row(children:[
        const GoldMark(size:43),const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('سعر المثقال • عيار 24',
            style:TextStyle(color:AyarColors.muted,fontSize:12)),
          const SizedBox(height:4),
          AnimateNumber('${money(quote.priceFor(karat:24,unit:WeightUnit.mithqal))} ج.س',
            style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19)),
          Text('المثقال = ${money(quote.mithqalGrams,decimals:2)} جرام (قابل للضبط)',
            style:const TextStyle(color:AyarColors.muted,fontSize:10)),
        ])),
      ])),
      const SizedBox(height:24),
      const AyarPanel(child:Text(
        'تنبيه: الأسعار المحسوبة تقديرية بناءً على السعر العالمي وسعر الصرف المعتمد في التطبيق، ولا تعني سعر البيع أو الشراء لدى الصاغة. لا تشمل المصنعية أو المصاريف.',
        style:TextStyle(color:AyarColors.muted,height:1.7,fontSize:12))),
    ]);
}

class _GoldHero extends StatelessWidget {
  final MarketQuote quote;
  const _GoldHero({required this.quote});
  @override Widget build(BuildContext context) => Container(
    height:235,clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(25),
      gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,
        colors:[Color(0xFF303124),Color(0xFF151F2A),Color(0xFF121923)]),
      border:Border.all(color:AyarColors.gold.withValues(alpha:.2))),
    child:Stack(children:[
      PositionedDirectional(end:-18,bottom:0,width:310,height:125,
        child:CustomPaint(painter:DecorativeWave())),
      PositionedDirectional(top:19,start:21,end:21,bottom:15,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('السعر العالمي للأونصة',
            style:TextStyle(color:AyarColors.paleGold,fontSize:15)),
          const SizedBox(height:5),
          const Text('XAU / USD  •  Troy Ounce',
            textDirection:TextDirection.ltr,
            style:TextStyle(color:AyarColors.muted,fontSize:11,letterSpacing:1)),
          const SizedBox(height:15),
          FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
            child:AnimateNumber('\$${money(quote.ounceUsd,decimals:2)}',
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:39,
                color:AyarColors.paleGold,letterSpacing:-1))),
          const Spacer(),
          FreshnessLabel(quote),
          const SizedBox(height:7),
          Text('المصدر: ${quote.source}',style:const TextStyle(
            color:AyarColors.muted,fontSize:11)),
        ])),
    ]));
}

class _KaratCard extends StatelessWidget {
  final int karat;
  final MarketQuote quote;
  const _KaratCard({required this.karat,required this.quote});
  @override Widget build(BuildContext context) => AyarPanel(
    padding:const EdgeInsets.symmetric(horizontal:9,vertical:17),
    child:Column(children:[
      Container(width:37,height:37,alignment:Alignment.center,
        decoration:BoxDecoration(shape:BoxShape.circle,
          color:AyarColors.gold.withValues(alpha:.13)),
        child:Text('$karat',style:const TextStyle(color:AyarColors.paleGold,
          fontWeight:FontWeight.bold,fontSize:16))),
      const SizedBox(height:9),
      Text('عيار $karat',style:const TextStyle(color:AyarColors.muted,fontSize:11)),
      const SizedBox(height:6),
      FittedBox(fit:BoxFit.scaleDown,child:AnimateNumber(
        money(quote.priceFor(karat:karat)),
        style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
      const Text('ج.س / جرام',style:TextStyle(color:AyarColors.muted,fontSize:10)),
    ]));
}

class CalculatorScreen extends StatefulWidget {
  final MarketQuote quote;
  const CalculatorScreen({super.key,required this.quote});
  @override State<CalculatorScreen> createState()=>_CalculatorScreenState();
}
class _CalculatorScreenState extends State<CalculatorScreen> {
  final weight=TextEditingController(text:'1');
  int karat=21;
  WeightUnit unit=WeightUnit.gram;
  @override void dispose(){weight.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final raw = double.tryParse(weight.text.trim().replaceAll(',','.'));
    final valid=raw!=null && raw>=0 && raw.isFinite;
    final result=valid?widget.quote.priceFor(karat:karat,weight:raw,unit:unit):null;
    return ListView(padding:const EdgeInsets.all(18),children:[
      const SectionHeader('حاسبة الذهب',subtitle:'احسب قيمة الذهب حسب الوزن والعيار'),
      const SizedBox(height:20),
      AyarPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('اختر العيار',style:TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:13),
        Row(children:[for(final k in [24,21,18]) ...[
          Expanded(child:Padding(padding:const EdgeInsetsDirectional.only(end:7),
            child:ChoiceChip(label:Text('عيار $k'),selected:k==karat,
              selectedColor:AyarColors.gold,labelStyle:TextStyle(
                fontWeight:FontWeight.bold,
                color:k==karat?AyarColors.background:Colors.white),
              onSelected:(_)=>setState(()=>karat=k)))),
        ]]),
        const SizedBox(height:22),
        const Text('الوزن',style:TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:12),
        TextField(controller:weight,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          textDirection:TextDirection.ltr,textAlign:TextAlign.right,
          onChanged:(_)=>setState((){}),
          decoration:InputDecoration(hintText:'مثال: 12.5',
            errorText:valid?null:'أدخل وزناً صحيحاً غير سالب')),
        const SizedBox(height:14),
        DropdownButtonFormField<WeightUnit>(
          initialValue:unit,
          decoration:const InputDecoration(labelText:'وحدة القياس'),
          items:WeightUnit.values.map((u)=>DropdownMenuItem(
            value:u,child:Text(u.label))).toList(),
          onChanged:(v){if(v!=null)setState(()=>unit=v);}),
        if(unit==WeightUnit.mithqal) ...[
          const SizedBox(height:9),Text(
            'تم اعتماد ${money(widget.quote.mithqalGrams,decimals:2)} جرام للمثقال. تحقّق من معيار التاجر المحلي.',
            style:const TextStyle(color:AyarColors.muted,fontSize:11)),
        ],
      ])),
      const SizedBox(height:18),
      Container(padding:const EdgeInsets.all(23),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),
          gradient:const LinearGradient(colors:[Color(0xFF362E23),Color(0xFF1B232D)])),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('القيمة الإجمالية التقديرية',
            style:TextStyle(color:AyarColors.paleGold,fontSize:14)),
          const SizedBox(height:12),
          FittedBox(child:AnimateNumber('${money(result)} ج.س',
            style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800))),
          const SizedBox(height:9),
          const Text('قبل المصنعية والضرائب وهوامش السوق',
            style:TextStyle(color:AyarColors.muted,fontSize:12)),
        ])),
    ]);
  }
}

class AlertsScreen extends StatelessWidget {
  final AyarData data;
  final MarketQuote quote;
  final Stream<List<PriceAlert>> alerts;
  const AlertsScreen({super.key,required this.data,required this.quote,required this.alerts});
  Future<void> add(BuildContext context) async {
    final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,
      backgroundColor:AyarColors.panel,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),
      builder:(_)=>AlertEditor(data:data,quote:quote));
    if(ok==true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('تم حفظ التنبيه. سيتحقق عند عبور السعر هدفك.')));
    }
  }
  @override Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.all(18),child:Column(children:[
      Row(children:[const Expanded(child:SectionHeader('تنبيهات الأسعار',
        subtitle:'ضع السعر الذي تنتظر وصول الذهب إليه')),
        IconButton(onPressed:()=>add(context),tooltip:'تنبيه جديد',
          icon:const Icon(LucideIcons.plus,color:AyarColors.gold))]),
      const SizedBox(height:18),
      Expanded(child:StreamBuilder<List<PriceAlert>>(stream:alerts,builder:(context,s){
        if(s.hasError) return Center(child:Text('تعذر تحميل التنبيهات: ${s.error}'));
        if(!s.hasData) return const Center(child:CircularProgressIndicator());
        if(s.data!.isEmpty) return const Center(child:Text('لا توجد تنبيهات حتى الآن',
          style:TextStyle(color:AyarColors.muted)));
        return ListView.separated(itemCount:s.data!.length,
          separatorBuilder:(_,__)=>const SizedBox(height:10),
          itemBuilder:(context,i){final a=s.data![i];return AyarPanel(child:Row(children:[
            Icon(a.direction=='above'?LucideIcons.trendingUp:LucideIcons.trendingDown,
              color:AyarColors.gold),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('عيار ${a.karat} • ${a.direction=='above'?'أعلى من':'أقل من'}',
                style:const TextStyle(color:AyarColors.muted,fontSize:12)),
              Text('${money(a.targetSdg)} ج.س / جرام',
                style:const TextStyle(fontWeight:FontWeight.w700)),
              Text(a.enabled?'بانتظار عبور الهدف':'تم بلوغ الهدف',
                style:const TextStyle(color:AyarColors.muted,fontSize:11)),
            ])),
            IconButton(tooltip:'حذف التنبيه',onPressed:()async{
              try{await data.deleteAlert(a.id);}catch(e){showError(context,e);}
            },icon:const Icon(LucideIcons.trash2,color:AyarColors.red)),
          ]));});
      })),
    ]));
}

class AlertEditor extends StatefulWidget {
  final AyarData data;
  final MarketQuote quote;
  const AlertEditor({super.key,required this.data,required this.quote});
  @override State<AlertEditor> createState()=>_AlertEditorState();
}
class _AlertEditorState extends State<AlertEditor> {
  final controller=TextEditingController();
  int karat=21;
  String direction='above';
  bool saving=false;
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Padding(
    padding:EdgeInsets.fromLTRB(20,22,20,MediaQuery.viewInsetsOf(context).bottom+24),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const SectionHeader('تنبيه جديد',subtitle:'عند تجاوز سعر الجرام الحد الذي تحدده'),
      const SizedBox(height:16),
      DropdownButtonFormField<int>(initialValue:karat,
        decoration:const InputDecoration(labelText:'العيار'),
        items:[24,21,18].map((k)=>DropdownMenuItem(value:k,child:Text('عيار $k'))).toList(),
        onChanged:(v){if(v!=null)setState(()=>karat=v);}),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(initialValue:direction,
        decoration:const InputDecoration(labelText:'نوع التنبيه'),
        items:const [DropdownMenuItem(value:'above',child:Text('عند ارتفاع السعر إلى الهدف')),
          DropdownMenuItem(value:'below',child:Text('عند انخفاض السعر إلى الهدف'))],
        onChanged:(v){if(v!=null)setState(()=>direction=v);}),
      const SizedBox(height:12),
      TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        textDirection:TextDirection.ltr,
        inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration:const InputDecoration(labelText:'السعر المستهدف بالجنيه السوداني')),
      const SizedBox(height:7),
      Text('السعر الحالي: ${money(widget.quote.priceFor(karat:karat))} ج.س للجرام',
        style:const TextStyle(color:AyarColors.muted,fontSize:11)),
      const SizedBox(height:15),
      FilledButton(onPressed:saving?null:()async{
        final value=double.tryParse(controller.text.replaceAll(',','.'));
        if(value==null || !value.isFinite || value<=0){
          showError(context,'أدخل سعراً صحيحاً أكبر من الصفر');return;
        }
        final current=widget.quote.priceFor(karat:karat);
        if(current==null){showError(context,'لا تتوفر أسعار محدثة لإنشاء تنبيه');return;}
        if((direction=='above' && value<=current) ||
           (direction=='below' && value>=current)){
          showError(context,'اختر هدفاً على الجانب الصحيح من السعر الحالي');return;
        }
        setState(()=>saving=true);
        try{
          await widget.data.createAlert(karat,value,direction);
          if(context.mounted) Navigator.pop(context,true);
        }catch(e){showError(context,e);}
        finally{if(mounted)setState(()=>saving=false);}
      },child:Text(saving?'جارٍ الحفظ':'إنشاء التنبيه')),
    ])));
}

class BulletinScreen extends StatelessWidget {
  final AyarData data;
  final Stream<List<MarketBulletin>> bulletins;
  const BulletinScreen({super.key,required this.data,required this.bulletins});
  @override Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.all(18),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const SectionHeader('النشرة السوقية',subtitle:'ملخصات ينشرها مدير عيار'),
      const SizedBox(height:19),
      Expanded(child:StreamBuilder<List<MarketBulletin>>(
        stream:bulletins,builder:(context,s){
          if(s.hasError)return Center(child:Text('تعذر تحميل النشرات: ${s.error}'));
          if(!s.hasData)return const Center(child:CircularProgressIndicator());
          if(s.data!.isEmpty)return const Center(child:Text('لا توجد نشرات منشورة بعد'));
          return ListView.separated(itemCount:s.data!.length,
            separatorBuilder:(_,__)=>const SizedBox(height:12),
            itemBuilder:(context,i){ final b=s.data![i];return AyarPanel(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(b.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
              const SizedBox(height:8),
              Text(b.content,style:const TextStyle(height:1.75)),
              const SizedBox(height:12),
              Text(ago(b.publishedAt),style:const TextStyle(color:AyarColors.muted,fontSize:11)),
            ]));});
        })),
      ]));
}

class AdminSignIn extends StatefulWidget {
  final AyarData data;
  const AdminSignIn({super.key,required this.data});
  @override State<AdminSignIn> createState()=>_AdminSignInState();
}
class _AdminSignInState extends State<AdminSignIn> {
  final email=TextEditingController();
  final password=TextEditingController();
  bool busy=false;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('دخول الإدارة'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:email,keyboardType:TextInputType.emailAddress,
        decoration:const InputDecoration(labelText:'البريد الإلكتروني')),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,
        decoration:const InputDecoration(labelText:'كلمة المرور')),
    ]),actions:[
      TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('إلغاء')),
      FilledButton(onPressed:busy?null:()async{
        setState(()=>busy=true);
        try{await widget.data.signInAdmin(email.text.trim(),password.text);
          if(context.mounted)Navigator.pop(context,true);
        }on FirebaseAuthException catch(e){showError(context,e.message??e.code);}
        catch(e){showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
      },child:Text(busy?'...':'دخول')),
    ]);
}

class AdminScreen extends StatefulWidget {
  final AyarData data;
  const AdminScreen({super.key,required this.data});
  @override State<AdminScreen> createState()=>_AdminScreenState();
}
class _AdminScreenState extends State<AdminScreen> {
  final fx=TextEditingController();
  final headline=TextEditingController();
  final body=TextEditingController();
  bool updating=false;
  bool publishing=false;
  @override void dispose(){fx.dispose();headline.dispose();body.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('إدارة عيار'),leading:const BackButton()),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      const SectionHeader('سعر الصرف',subtitle:'تحديث سعر الدولار المحلي يعيد تسعير كل العيارات تلقائيًا'),
      const SizedBox(height:15),
      AyarPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TextField(controller:fx,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          textDirection:TextDirection.ltr,
          decoration:const InputDecoration(labelText:'جنيه سوداني مقابل 1 USD')),
        const SizedBox(height:14),
        FilledButton(onPressed:updating?null:()async{
          final value=double.tryParse(fx.text.replaceAll(',','.'));
          if(value==null || !value.isFinite || value<=0){
            showError(context,'قيمة الصرف غير صحيحة');return;
          }
          setState(()=>updating=true);
          try{await widget.data.updateFx(value);
            if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('تم تحديث سعر الدولار')));
          }catch(e){showError(context,e);}finally{if(mounted)setState(()=>updating=false);}
        },child:Text(updating?'جارٍ التحديث':'حفظ سعر الصرف')),
      ])),
      const SizedBox(height:28),
      const SectionHeader('نشر موجز السوق',subtitle:'يظهر للمستخدمين في تبويب النشرة'),
      const SizedBox(height:14),
      AyarPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TextField(controller:headline,maxLength:120,
          decoration:const InputDecoration(labelText:'عنوان الموجز')),
        const SizedBox(height:12),
        TextField(controller:body,maxLines:5,maxLength:2000,
          decoration:const InputDecoration(labelText:'نص الموجز')),
        const SizedBox(height:12),
        FilledButton(onPressed:publishing?null:()async{
          if(headline.text.trim().isEmpty || body.text.trim().isEmpty){
            showError(context,'اكتب العنوان والمحتوى');return;
          }
          setState(()=>publishing=true);
          try{await widget.data.publishBulletin(headline.text.trim(),body.text.trim());
            headline.clear();body.clear();
            if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('تم نشر الموجز')));
          }catch(e){showError(context,e);}finally{if(mounted)setState(()=>publishing=false);}
        },child:Text(publishing?'جارٍ النشر':'نشر الموجز')),
      ])),
      const SizedBox(height:16),
      if(widget.data is PreviewData)
        const Text('هذه لوحة معاينة. الحفظ هنا محلي وغير متصل بالسوق الحقيقي.',
          style:TextStyle(color:AyarColors.muted,fontSize:12)),
    ]));
}
