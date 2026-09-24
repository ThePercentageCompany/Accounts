import test from 'node:test';
import assert from 'node:assert/strict';
import { validateBusinessValues as validate } from '../src/business-values.js';

test('financial values reject string coercion, booleans, non-finite and excessive amounts', () => {
  for (const value of ['100', true, null, NaN, Infinity, 1e13]) {
    assert.throws(() => validate({ amount: value }), e => e.code === 'INVALID_NUMBER');
  }
  validate({ amount: -100, taxRate: 5, quantity: 2.5 });
  assert.throws(() => validate({ quantity: -1 }), e => e.code === 'INVALID_NUMBER');
  assert.throws(() => validate({ percentage: 101 }), e => e.code === 'INVALID_NUMBER');
  assert.throws(() => validate({ lineNumber: 1.5 }), e => e.code === 'INVALID_NUMBER');
});

test('dates reject nonexistent days and timestamps; text rejects non-text values', () => {
  validate({ date: '2024-02-29', month: '2026-09', currency: 'AED', notes: 'Line one\nLine two' });
  for (const value of ['2025-02-29', '2026-04-31', '2026-01-01T00:00:00Z']) {
    assert.throws(() => validate({ date: value }), e => e.code === 'INVALID_DATE');
  }
  assert.throws(() => validate({ month: '2026-13' }), e => e.code === 'INVALID_DATE');
  assert.throws(() => validate({ name: false }), e => e.code === 'INVALID_TEXT');
  assert.throws(() => validate({ currency: 'aed' }), e => e.code === 'INVALID_CURRENCY');
});
