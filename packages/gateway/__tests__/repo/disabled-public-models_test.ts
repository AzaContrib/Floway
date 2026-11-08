import { test } from 'vitest';

import {
  normalizeDisabledPublicModelIds,
  normalizeEnabledPublicModelIds,
  normalizeModelFilterMode,
  parseDisabledPublicModelIdsWire,
  parseEnabledPublicModelIdsWire,
} from '../../src/repo/disabled-public-models.ts';
import { isModelAllowed } from '@floway-dev/provider';
import { assertEquals, assertRejects } from '@floway-dev/test-utils';

test('normalizeDisabledPublicModelIds trims, drops empties, and de-dupes preserving order', () => {
  assertEquals(
    normalizeDisabledPublicModelIds([' gpt-4o ', 'claude', 'gpt-4o', '', '  ', 'claude']),
    ['gpt-4o', 'claude'],
  );
});

test('normalizeDisabledPublicModelIds rejects non-string entries', async () => {
  await assertRejects(
    () => normalizeDisabledPublicModelIds([1 as unknown as string]),
    Error,
    'disabledPublicModelIds entries must be strings',
  );
});

test('parseDisabledPublicModelIdsWire treats an absent field as the empty set', () => {
  assertEquals(parseDisabledPublicModelIdsWire(undefined), []);
});

test('parseDisabledPublicModelIdsWire normalizes a present array', () => {
  assertEquals(parseDisabledPublicModelIdsWire([' a ', 'a', 'b']), ['a', 'b']);
});

test('parseDisabledPublicModelIdsWire rejects non-array and non-string shapes', async () => {
  await assertRejects(
    () => parseDisabledPublicModelIdsWire({}),
    Error,
    'disabled_public_model_ids must be an array of strings',
  );
  await assertRejects(
    () => parseDisabledPublicModelIdsWire(['ok', 7]),
    Error,
    'disabled_public_model_ids entries must be strings',
  );
});

test('normalizeEnabledPublicModelIds trims, drops empties, and de-dupes preserving order', () => {
  assertEquals(
    normalizeEnabledPublicModelIds([' gpt-4o ', 'claude', 'gpt-4o', '', '  ', 'claude']),
    ['gpt-4o', 'claude'],
  );
});

test('normalizeEnabledPublicModelIds rejects non-string entries', async () => {
  await assertRejects(
    () => normalizeEnabledPublicModelIds([1 as unknown as string]),
    Error,
    'enabledPublicModelIds entries must be strings',
  );
});

test('parseEnabledPublicModelIdsWire treats an absent field as the empty set', () => {
  assertEquals(parseEnabledPublicModelIdsWire(undefined), []);
});

test('parseEnabledPublicModelIdsWire normalizes a present array', () => {
  assertEquals(parseEnabledPublicModelIdsWire([' a ', 'a', 'b']), ['a', 'b']);
});

test('parseEnabledPublicModelIdsWire rejects non-array and non-string shapes', async () => {
  await assertRejects(
    () => parseEnabledPublicModelIdsWire({}),
    Error,
    'enabled_public_model_ids must be an array of strings',
  );
  await assertRejects(
    () => parseEnabledPublicModelIdsWire(['ok', 7]),
    Error,
    'enabled_public_model_ids entries must be strings',
  );
});

test('normalizeModelFilterMode accepts blacklist and whitelist and defaults undefined', () => {
  assertEquals(normalizeModelFilterMode('blacklist'), 'blacklist');
  assertEquals(normalizeModelFilterMode('whitelist'), 'whitelist');
  assertEquals(normalizeModelFilterMode(undefined), 'blacklist');
  assertEquals(normalizeModelFilterMode(null), 'blacklist');
});

test('normalizeModelFilterMode rejects invalid mode values', async () => {
  await assertRejects(
    () => normalizeModelFilterMode('invalid' as unknown as string),
    Error,
    "model_filter_mode must be 'blacklist' or 'whitelist'",
  );
});

test('isModelAllowed filters models in blacklist mode', () => {
  const target = {
    modelFilterMode: 'blacklist' as const,
    disabledPublicModelIds: ['blocked-model'],
    enabledPublicModelIds: [],
  };
  assertEquals(isModelAllowed(target, 'allowed-model'), true);
  assertEquals(isModelAllowed(target, 'blocked-model'), false);
});

test('isModelAllowed filters models in whitelist mode', () => {
  const target = {
    modelFilterMode: 'whitelist' as const,
    disabledPublicModelIds: [],
    enabledPublicModelIds: ['allowed-model'],
  };
  assertEquals(isModelAllowed(target, 'allowed-model'), true);
  assertEquals(isModelAllowed(target, 'other-model'), false);
});
