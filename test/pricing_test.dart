import 'package:flutter_test/flutter_test.dart';
import 'package:ayar/src/market.dart';

void main() {
  test('24k ounce equals spot x FX', () {
    const quote=MarketQuote(ounceUsd:4000,fxSdgPerUsd:5000);
    final actual=quote.priceFor(karat:24,weight:1,unit:WeightUnit.troyOunce)!;
    expect(actual,closeTo(20000000,0.0001));
  });
  test('21k and 18k proportional to 24k', () {
    const quote=MarketQuote(ounceUsd:3200,fxSdgPerUsd:4500);
    final pure=quote.priceFor(karat:24)!;
    expect(quote.priceFor(karat:21),closeTo(pure*21/24,0.001));
    expect(quote.priceFor(karat:18),closeTo(pure*18/24,0.001));
  });
  test('mithqal weight default and negative input rejected', () {
    const quote=MarketQuote(ounceUsd:3200,fxSdgPerUsd:4500);
    expect(quote.priceFor(karat:24,unit:WeightUnit.mithqal),
      closeTo(quote.priceFor(karat:24)!*4.25,0.001));
    expect(quote.priceFor(karat:24,weight:-1),isNull);
  });
  test('missing FX yields no fabricated market value', () {
    const quote=MarketQuote(ounceUsd:3200,fxSdgPerUsd:null);
    expect(quote.priceFor(karat:21),isNull);
  });
}
