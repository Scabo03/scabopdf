// Regenerates the Layer 1 -> Layer 2 contract artifacts inside app/ from the
// canonical schema at the repo root (shared/schema.json, owned by Layer 1).
//
// Produces two committed, generated files under src/consumption/:
//   - schema.json          a verbatim copy, bundled so the runtime validator
//                           can validate documents on-device (the canonical
//                           file lives outside app/ and Metro will not bundle
//                           imports from outside the project root).
//   - schema.generated.ts  TypeScript types mirroring the contract.
//
// Run with: npm run gen:schema

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compile } from 'json-schema-to-typescript';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const sourceSchemaPath = resolve(repoRoot, 'shared', 'schema.json');
const outDir = resolve(here, '..', 'src', 'consumption');
const outSchemaPath = resolve(outDir, 'schema.json');
const outTypesPath = resolve(outDir, 'schema.generated.ts');

const raw = readFileSync(sourceSchemaPath, 'utf8');
const schema = JSON.parse(raw);

mkdirSync(outDir, { recursive: true });

// 1. Bundle a verbatim copy for runtime validation.
writeFileSync(outSchemaPath, raw.endsWith('\n') ? raw : `${raw}\n`);

// 2. Generate TypeScript types from the contract.
const banner = [
  '/* eslint-disable */',
  '/**',
  ' * GENERATED FILE — do not edit by hand.',
  ' * Source of truth: shared/schema.json (the Layer 1 contract).',
  ' * Regenerate with: npm run gen:schema',
  ' */',
].join('\n');

const types = await compile(schema, 'ScabopdfDocument', {
  bannerComment: banner,
  additionalProperties: false,
  declareExternallyReferenced: true,
  style: { singleQuote: true, trailingComma: 'all' },
});

writeFileSync(outTypesPath, types);

console.log(`Wrote ${outSchemaPath}`);
console.log(`Wrote ${outTypesPath}`);
