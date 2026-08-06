import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  isValidUuid,
  validateRecommendationBody,
} from "./validation.ts";

const validDescription =
  "My dog has a muddy coat and needs a full wash today.";
const validPetId = "550e8400-e29b-41d4-a716-446655440000";

Deno.test("accepts valid UUID and description", () => {
  const result = validateRecommendationBody({
    petId: `  ${validPetId}  `,
    ownerDescription: `  ${validDescription}  `,
  });
  assert(result.ok);
  if (result.ok) {
    assertEquals(result.value.petId, validPetId);
    assertEquals(result.value.ownerDescription, validDescription);
  }
});

Deno.test("rejects invalid UUID", () => {
  assertFalse(isValidUuid("not-a-uuid"));
  const result = validateRecommendationBody({
    petId: "pet-1",
    ownerDescription: validDescription,
  });
  assertFalse(result.ok);
});

Deno.test("rejects description under 20 characters", () => {
  const result = validateRecommendationBody({
    petId: validPetId,
    ownerDescription: "Too short for AI",
  });
  assertFalse(result.ok);
});

Deno.test("rejects description above 1000 characters", () => {
  const result = validateRecommendationBody({
    petId: validPetId,
    ownerDescription: "a".repeat(1001),
  });
  assertFalse(result.ok);
});

Deno.test("rejects whitespace-only description", () => {
  const result = validateRecommendationBody({
    petId: validPetId,
    ownerDescription: "                    ",
  });
  assertFalse(result.ok);
});
