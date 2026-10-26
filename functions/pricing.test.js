'use strict';
const {test} = require('node:test');
const assert=require('node:assert/strict');
const {gramPrice, reachedTarget, GRAMS_PER_TROY_OUNCE, validSpotPayload}=require('./pricing');
test('24k troy ounce equals spot times local FX',()=>{
  const price=gramPrice(4000,5000,24,GRAMS_PER_TROY_OUNCE);
  assert.ok(Math.abs(price-20_000_000)<1e-5);
});
test('21k is 21/24 of 24k price',()=>{
  assert.ok(Math.abs(gramPrice(4000,5000,21)/gramPrice(4000,5000,24)-.875)<1e-10);
});
test('18k, 21k, 24k pricing ordering',()=>{
  assert.ok(gramPrice(3000,4000,18)<gramPrice(3000,4000,21));
  assert.ok(gramPrice(3000,4000,21)<gramPrice(3000,4000,24));
});
test('invalid inputs fail',()=>{
  assert.throws(()=>gramPrice(0,5000,24));
  assert.throws(()=>gramPrice(4000,-10,24));
  assert.throws(()=>gramPrice(4000,5000,99));
});
test('alert triggers only across threshold',()=>{
  assert.equal(reachedTarget(100,120,110,'above'),true);
  assert.equal(reachedTarget(120,100,110,'below'),true);
  assert.equal(reachedTarget(120,125,110,'above'),false);
  assert.equal(reachedTarget(100,120,110,'below'),false);
});

test('fresh provider response accepted; stale or wrong units rejected',()=>{
  const sample={status:'success',unit:'toz',metal:'gold',currency:'USD',timestamp:new Date().toISOString(),rate:{price:3921.12}};
  assert.equal(validSpotPayload(sample).price,3921.12);
  assert.equal(validSpotPayload({...sample,unit:'g'}),null);
  assert.equal(validSpotPayload({...sample,metal:'silver'}),null);
  assert.equal(validSpotPayload({...sample,rate:{price:0}}),null);
  assert.equal(validSpotPayload({...sample,timestamp:new Date(Date.now()-16*60000).toISOString()}),null);
});
