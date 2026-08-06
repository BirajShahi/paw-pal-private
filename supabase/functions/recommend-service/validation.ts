/** Pure request validation for recommend-service (testable without Deno serve). */

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ParsedRecommendationRequest = {
  petId: string;
  ownerDescription: string;
};

export type ValidationResult =
  | { ok: true; value: ParsedRecommendationRequest }
  | { ok: false; message: string };

export function isValidUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function validateRecommendationBody(body: unknown): ValidationResult {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return {
      ok: false,
      message: "Please provide valid recommendation details.",
    };
  }

  const record = body as Record<string, unknown>;

  if (typeof record.petId !== "string") {
    return {
      ok: false,
      message: "Please provide valid recommendation details.",
    };
  }

  const petId = record.petId.trim();
  if (petId.length === 0 || !isValidUuid(petId)) {
    return {
      ok: false,
      message: "Please provide valid recommendation details.",
    };
  }

  if (typeof record.ownerDescription !== "string") {
    return {
      ok: false,
      message: "Please provide valid recommendation details.",
    };
  }

  const ownerDescription = record.ownerDescription.trim();
  if (ownerDescription.length < 20 || ownerDescription.length > 1000) {
    return {
      ok: false,
      message: "Please provide valid recommendation details.",
    };
  }

  return {
    ok: true,
    value: { petId, ownerDescription },
  };
}
