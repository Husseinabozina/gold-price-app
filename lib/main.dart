import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/data.dart';
import 'src/design.dart';
import 'src/screens.dart';

// Run with --dart-define=AYAR_PREVIEW=false after configuring Firebase.
const preview = bool.fromEnvironment('AYAR_PREVIEW', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AyarData data;
  if (preview) {
    data = PreviewData();
  } else {
    try {
      // flutterfire configure installs the required native Firebase config.
      await Firebase.initializeApp();
      data = FirebaseData();
    } catch (error) {
      runApp(_StartupError('$error'));
      return;
    }
  }
  runApp(AyarApp(data: data));
}

class AyarApp extends StatelessWidget {
  final AyarData data;
  const AyarApp({super.key, required this.data});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title:'عيار | AYAR',
    theme:ayarTheme(),
    locale:const Locale('ar'),
    supportedLocales:const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WelcomeScreen(data:data),
  );
}

class _StartupError extends StatelessWidget {
  final String error;
  const _StartupError(this.error);
  @override Widget build(BuildContext context) => MaterialApp(
    theme:ayarTheme(),
    home:Scaffold(body:Center(child:Padding(
      padding:const EdgeInsets.all(24),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        const GoldMark(),const SizedBox(height:24),
        const Text('إعداد Firebase غير مكتمل',textAlign:TextAlign.center),
        const SizedBox(height:8),
        const Text('شغّل flutterfire configure أو استخدم وضع المعاينة.',textAlign:TextAlign.center),
        const SizedBox(height:8), Text(error,maxLines:3,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:AyarColors.muted,fontSize:11)),
      ]))),),
  );
}
