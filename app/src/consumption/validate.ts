/**
 * Runtime validation of a candidate document against the Layer 1 contract
 * (shared/schema.json, bundled here as ./schema.json).
 *
 * Uses @cfworker/json-schema, a Draft 2020-12 validator that interprets the
 * schema at runtime without code generation. This matters because the app
 * runs on Hermes (the default engine under the New Architecture), where
 * eval / new Function are disabled — ajv's default runtime compilation would
 * throw there. @cfworker has no such dependency.
 */

import { Validator } from '@cfworker/json-schema';
import type { Schema } from '@cfworker/json-schema';
import schema from './schema.json';

/** A single, presentation-ready validation failure. */
export interface SchemaValidationError {
  /** JSON Pointer to the offending location, e.g. "#/structure/0/type". */
  location: string;
  /** Human-readable description of what failed. */
  message: string;
}

// The schema is self-contained ($defs + internal $ref), so one Validator
// instance can be built once and reused for every document.
let cachedValidator: Validator | undefined;

function getValidator(): Validator {
  if (cachedValidator === undefined) {
    cachedValidator = new Validator(schema as Schema, '2020-12');
  }
  return cachedValidator;
}

/**
 * Validates arbitrary parsed JSON against the contract.
 *
 * @returns an empty array when the data conforms, otherwise the list of
 * failures. It never throws: malformed input simply produces errors.
 */
export function validateAgainstSchema(data: unknown): SchemaValidationError[] {
  const result = getValidator().validate(data);
  if (result.valid) {
    return [];
  }
  return result.errors.map(unit => ({
    location: unit.instanceLocation,
    message: unit.error,
  }));
}
