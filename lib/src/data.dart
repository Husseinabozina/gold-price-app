import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'market.dart';

abstract class AyarData {
  Stream<MarketQuote> watchQuote();
  Stream<List<MarketBulletin>> watchBulletins();
  Stream<List<PriceAlert>> watchAlerts();
  Future<void> signInGuest();
  Future<bool> isAdmin();
  Future<void> signInAdmin(String email, String password);
  Future<void> updateFx(double fx);
  Future<void> publishBulletin(String title, String body);
  Future<void> createAlert(int karat, double target, String direction);
  Future<void> deleteAlert(String id);
}

class PreviewData implements AyarData {
  // Illustrative preview ONLY: never presented as an actual Sudan market quote.
  final _quote = StreamController<MarketQuote>.broadcast();
  final _bulletins = StreamController<List<MarketBulletin>>.broadcast();
  final _alerts = StreamController<List<PriceAlert>>.broadcast();
  MarketQuote current = MarketQuote(
      ounceUsd: 4000, fxSdgPerUsd: 5000, isPreview: true,
      spotUpdatedAt: DateTime.now(), fxUpdatedAt: DateTime.now());
  List<MarketBulletin> news = [MarketBulletin(id: 'sample',
    title: 'معاينة النشرة', content: 'هذه بيانات توضيحية فقط. عند الربط بخدمة Firebase ستظهر النشرات الحقيقية المنشورة من الإدارة.',
    publishedAt: DateTime.now())];
  List<PriceAlert> alerts = [];
  @override Stream<MarketQuote> watchQuote() async* { yield current; yield* _quote.stream; }
  @override Stream<List<MarketBulletin>> watchBulletins() async* { yield List.of(news); yield* _bulletins.stream; }
  @override Stream<List<PriceAlert>> watchAlerts() async* { yield List.of(alerts); yield* _alerts.stream; }
  @override Future<void> signInGuest() async {}
  @override Future<bool> isAdmin() async => false;
  @override Future<void> signInAdmin(String email, String password) async =>
      throw StateError('الإدارة غير متاحة في وضع المعاينة');
  @override Future<void> updateFx(double fx) async {
    current = current.copyWithFx(fx); _quote.add(current);
  }
  @override Future<void> publishBulletin(String title, String body) async {
    news.insert(0, MarketBulletin(id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title, content: body, publishedAt: DateTime.now()));
    _bulletins.add(List.of(news));
  }
  @override Future<void> createAlert(int karat, double target, String direction) async {
    alerts.insert(0, PriceAlert(id: DateTime.now().microsecondsSinceEpoch.toString(),
        karat: karat, targetSdg: target, direction: direction, enabled: true));
    _alerts.add(List.of(alerts));
  }
  @override Future<void> deleteAlert(String id) async {
    alerts.removeWhere((a) => a.id == id); _alerts.add(List.of(alerts));
  }
}

class FirebaseData implements AyarData {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override Stream<MarketQuote> watchQuote() => _db.doc('market/state')
    .snapshots(includeMetadataChanges: true).map(MarketQuote.fromFirestore);

  @override Stream<List<MarketBulletin>> watchBulletins() => _db
    .collection('bulletins').orderBy('publishedAt', descending: true).limit(30)
    .snapshots().map((s) => s.docs.map((d) { final v = d.data();
      return MarketBulletin(id:d.id, title:v['title'] as String? ?? '',
        content:v['content'] as String? ?? '',
        publishedAt:(v['publishedAt'] as Timestamp?)?.toDate());
    }).toList());

  @override Stream<List<PriceAlert>> watchAlerts() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('alerts').where('ownerUid', isEqualTo: uid)
      .snapshots().map((s) => s.docs.map((d) { final v = d.data();
      return PriceAlert(id: d.id, karat:(v['karat'] as num).toInt(),
        targetSdg:(v['targetSdg'] as num).toDouble(),
        direction:v['direction'] as String, enabled:v['enabled'] == true);
      }).toList());
  }

  @override Future<void> signInGuest() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  @override Future<bool> isAdmin() async =>
    (await _auth.currentUser?.getIdTokenResult(true))?.claims?['admin'] == true;

  @override Future<void> signInAdmin(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email:email, password:password);
    if (!await isAdmin()) {
      await _auth.signOut();
      await _auth.signInAnonymously();
      throw StateError('هذا الحساب ليس حساب إدارة معتمداً');
    }
  }

  @override Future<void> updateFx(double fx) async {
    await _fn.httpsCallable('updateFx').call({'fx':fx});
  }

  @override Future<void> publishBulletin(String title, String body) async {
    await _fn.httpsCallable('publishBulletin').call({'title':title, 'body':body});
  }

  Future<void> _registerPushToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('يتطلب التنبيه دخولاً كزائر');
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError('اسمح بالإشعارات من إعدادات الهاتف أولاً');
    }
    // iOS may not have an APNs token until registration finishes.
    if (Platform.isIOS && await messaging.getAPNSToken() == null) {
      throw StateError('رمز APNs غير جاهز بعد؛ حاول مرة أخرى بعد قليل');
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('تعذر إنشاء رمز إشعارات لهذا الجهاز');
    }
    await _db.doc('users/$uid').set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge:true));
  }
  static bool _tokenRefreshRegistered = false;
  void _listenForTokenChanges() {
    if (_tokenRefreshRegistered) return;
    _tokenRefreshRegistered = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid != null && token.isNotEmpty) {
        await _db.doc('users/$uid').set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  @override Future<void> createAlert(int karat, double target, String direction) async {
    if (target <= 0 || !target.isFinite || ![18,21,24].contains(karat) ||
        !['above','below'].contains(direction)) throw ArgumentError('Invalid alert');
    await _registerPushToken();
    _listenForTokenChanges();
    final uid = _auth.currentUser!.uid;
    await _db.collection('alerts').add({
      'ownerUid':uid, 'karat':karat, 'targetSdg':target,
      'direction':direction, 'enabled':true,
      'createdAt':FieldValue.serverTimestamp(),
    });
  }

  @override Future<void> deleteAlert(String id) async {
    await _db.collection('alerts').doc(id).delete();
  }
}
