import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'market.dart';

class AyarColors {
  static const background = Color(0xFF0B1018);
  static const panel = Color(0xFF161F2A);
  static const panelHigh = Color(0xFF202B38);
  static const gold = Color(0xFFD6A85C);
  static const paleGold = Color(0xFFF0D69B);
  static const muted = Color(0xFF95A2B1);
  static const green = Color(0xFF35B99B);
  static const red = Color(0xFFE18A87);
}

ThemeData ayarTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AyarColors.gold,
    brightness: Brightness.dark, surface: AyarColors.background,
    primary: AyarColors.gold);
  final text = GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.dark().textTheme)
    .apply(bodyColor: Colors.white, displayColor: Colors.white);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AyarColors.background,
    colorScheme: scheme,
    textTheme: text,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent,
      elevation: 0, centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled:true, fillColor:AyarColors.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal:18,vertical:16),
      border: OutlineInputBorder(borderRadius:BorderRadius.circular(16),
        borderSide:BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(16),
        borderSide:const BorderSide(color:AyarColors.gold)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior:SnackBarBehavior.floating),
  );
}

String money(num? value, {int decimals=0}) {
  if (value == null || !value.isFinite) return '—';
  return intl.NumberFormat.decimalPatternDigits(locale:'en', decimalDigits:decimals)
      .format(value);
}

String ago(DateTime? time) {
  if (time == null) return 'لم يتم التحديث بعد';
  final minutes = DateTime.now().difference(time).inMinutes;
  if (minutes < 0) return 'وقت غير متطابق';
  if (minutes < 1) return 'منذ لحظات';
  if (minutes < 60) return 'منذ $minutes دقيقة';
  if (minutes < 1440) return 'منذ ${minutes ~/ 60} ساعة';
  return intl.DateFormat('yyyy/MM/dd HH:mm','en').format(time.toLocal());
}

class GoldMark extends StatelessWidget {
  final double size;
  const GoldMark({super.key, this.size=52});
  @override Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter:_GoldMarkPainter());
}
class _GoldMarkPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final p = Paint()..color=AyarColors.gold..strokeWidth=2.1..style=PaintingStyle.stroke;
    final outer=Path()
      ..moveTo(s.width*.5,s.height*.07)..lineTo(s.width*.88,s.height*.28)
      ..lineTo(s.width*.88,s.height*.72)..lineTo(s.width*.5,s.height*.93)
      ..lineTo(s.width*.12,s.height*.72)..lineTo(s.width*.12,s.height*.28)..close();
    canvas.drawPath(outer,p);
    final a=Path()..moveTo(s.width*.33,s.height*.65)..lineTo(s.width*.50,s.height*.29)
      ..lineTo(s.width*.67,s.height*.65)
      ..moveTo(s.width*.40,s.height*.52)..lineTo(s.width*.60,s.height*.52);
    canvas.drawPath(a,p..strokeWidth=3);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class AyarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const AyarPanel({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color});
  @override Widget build(BuildContext context) => Container(
    width:double.infinity, padding:padding,
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(22),
      color: color ?? AyarColors.panel,
      border:Border.all(color:Colors.white.withValues(alpha:.065)),
    ),child:child);
}

class SectionHeader extends StatelessWidget {
  final String text;
  final String? subtitle;
  const SectionHeader(this.text,{super.key,this.subtitle});
  @override Widget build(BuildContext context) => Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(text,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
      if(subtitle!=null) ...[const SizedBox(height:4),
        Text(subtitle!,style:const TextStyle(color:AyarColors.muted,fontSize:12))],
    ]);
}

class DecorativeWave extends CustomPainter {
  @override void paint(Canvas canvas,Size size) {
    final stroke=Paint()..style=PaintingStyle.stroke..strokeWidth=1.65
      ..shader=const LinearGradient(colors:[AyarColors.gold, Color(0x00D6A85C)])
        .createShader(Offset.zero & size);
    for(var layer=0;layer<3;layer++) {
      final path=Path();
      for(double x=0;x<=size.width;x+=3) {
        final y=size.height*(.51+layer*.12) +
          math.sin((x/size.width*math.pi*2.2)+(layer*.6))*size.height*.12;
        if(x==0) {path.moveTo(x,y);} else {path.lineTo(x,y);}
      }
      canvas.drawPath(path,stroke);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class AnimateNumber extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const AnimateNumber(this.text,{super.key,this.style});
  @override Widget build(BuildContext context) => AnimatedSwitcher(
    duration:const Duration(milliseconds:220),
    switchInCurve:Curves.easeOut,
    transitionBuilder:(child,a)=>FadeTransition(opacity:a,child:child),
    child:Text(text,key:ValueKey(text),textDirection:TextDirection.ltr,
      style:style),
  );
}

class FreshnessLabel extends StatelessWidget {
  final MarketQuote quote;
  const FreshnessLabel(this.quote,{super.key});
  @override Widget build(BuildContext context) {
    final label = quote.isPreview ? 'وضع معاينة • أرقام توضيحية' :
      quote.isCached ? 'بيانات محفوظة • قد تكون قديمة' :
      quote.isFresh ? 'آخر سعر عالمي متاح' : 'سعر غير محدّث';
    return Wrap(spacing:7,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[
      Container(width:7,height:7,decoration:BoxDecoration(
        color:quote.isFresh ? AyarColors.green : AyarColors.gold,shape:BoxShape.circle)),
      Text(label,style:const TextStyle(color:AyarColors.muted,fontSize:11)),
      Text('• ${ago(quote.spotUpdatedAt)}',
        style:const TextStyle(color:AyarColors.muted,fontSize:11)),
    ]);
  }
}

class DirectionChevron extends StatelessWidget {
  const DirectionChevron({super.key});
  @override Widget build(BuildContext context) => Icon(
      Directionality.of(context)==TextDirection.rtl
        ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size:22,color:AyarColors.gold);
}
