import 'package:cloud_firestore/cloud_firestore.dart';

const double gramsPerTroyOunce = 31.1034768;
const double defaultMithqalGrams = 4.25;

enum WeightUnit { gram, mithqal, troyOunce }

extension WeightUnitX on WeightUnit {
  String get label => switch (this) {
        WeightUnit.gram => 'جرام',
        WeightUnit.mithqal => 'مثقال',
        WeightUnit.troyOunce => 'أونصة تروي',
      };

  double inGrams(double mithqalGrams) => switch (this) {
        WeightUnit.gram => 1,
        WeightUnit.mithqal => mithqalGrams,
        WeightUnit.troyOunce => gramsPerTroyOunce,
      };
}

class MarketQuote {
  final double? ounceUsd;
  final double? fxSdgPerUsd;
  final double mithqalGrams;
  final DateTime? spotUpdatedAt;
  final DateTime? fxUpdatedAt;
  final String source;
  final bool isCached;
  final bool isPreview;

  const MarketQuote({
    required this.ounceUsd,
    required this.fxSdgPerUsd,
    this.mithqalGrams = defaultMithqalGrams,
    this.spotUpdatedAt,
    this.fxUpdatedAt,
    this.source = 'Metals.Dev',
    this.isCached = false,
    this.isPreview = false,
  });

  static DateTime? _date(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  factory MarketQuote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MarketQuote(
      ounceUsd: (data['ounceUsd'] as num?)?.toDouble(),
      fxSdgPerUsd: (data['fxSdgPerUsd'] as num?)?.toDouble(),
      mithqalGrams: (data['mithqalGrams'] as num?)?.toDouble() ?? defaultMithqalGrams,
      spotUpdatedAt: _date(data['spotUpdatedAt']),
      fxUpdatedAt: _date(data['fxUpdatedAt']),
      source: (data['provider'] as String?) ?? 'Metals.Dev',
      isCached: doc.metadata.isFromCache,
    );
  }

  double? priceFor({required int karat, double weight = 1, WeightUnit unit = WeightUnit.gram}) {
    if (karat < 1 || karat > 24 || !weight.isFinite || weight < 0 ||
        mithqalGrams <= 0 || ounceUsd == null || fxSdgPerUsd == null ||
        ounceUsd! <= 0 || fxSdgPerUsd! <= 0) {return null;}
    return ounceUsd! / gramsPerTroyOunce * fxSdgPerUsd! * karat / 24 *
        weight * unit.inGrams(mithqalGrams);
  }

  bool get isReady => priceFor(karat: 24) != null;
  bool get isFresh => !isPreview && !isCached && spotUpdatedAt != null &&
      DateTime.now().difference(spotUpdatedAt!).inMinutes < 12 &&
      !DateTime.now().isBefore(spotUpdatedAt!);

  MarketQuote copyWithFx(double fx) => MarketQuote(
        ounceUsd: ounceUsd,
        fxSdgPerUsd: fx,
        mithqalGrams: mithqalGrams,
        spotUpdatedAt: spotUpdatedAt,
        fxUpdatedAt: DateTime.now(),
        source: source,
        isCached: isCached,
        isPreview: isPreview,
      );
}

class MarketBulletin {
  final String id;
  final String title;
  final String content;
  final DateTime? publishedAt;
  MarketBulletin({required this.id, required this.title, required this.content, this.publishedAt});
}

class PriceAlert {
  final String id;
  final int karat;
  final double targetSdg;
  final String direction; // above | below
  final bool enabled;
  PriceAlert({required this.id, required this.karat, required this.targetSdg,
    required this.direction, required this.enabled});
}
