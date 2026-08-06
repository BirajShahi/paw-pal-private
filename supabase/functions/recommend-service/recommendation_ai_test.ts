import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  extractGroqChatContent,
  parseAiRecommendationJson,
  validateAiRecommendation,
  type CatalogueService,
} from "./recommendation_ai.ts";

const catalogue: CatalogueService[] = [
  {
    code: "wash_dry_and_brush",
    name: "Wash, Dry and Brush",
    category: "grooming",
    description: "Cleaning and brushing service.",
    includedItems: ["Wash"],
    recommendationTags: ["dirty coat"],
    canBeAddOn: false,
  },
  {
    code: "deshedding_treatment",
    name: "De-shedding Treatment",
    category: "grooming",
    description: "Removes loose undercoat.",
    includedItems: ["Brushing"],
    recommendationTags: ["shedding"],
    canBeAddOn: true,
  },
  {
    code: "full_grooming",
    name: "Full Grooming",
    category: "grooming",
    description: "Complete grooming package.",
    includedItems: ["Wash", "Trim"],
    recommendationTags: ["full groom"],
    canBeAddOn: false,
  },
];

const baseReasoning =
  "The coat is muddy and needs washing with light brushing support.";
const baseAdvice = "Book a wash and brush session soon.";

Deno.test("accepts valid primary and add-on codes", () => {
  const result = validateAiRecommendation(
    {
      outcome: "service_recommendation",
      primaryServiceCode: "wash_dry_and_brush",
      additionalServiceCodes: ["deshedding_treatment"],
      reasoning: baseReasoning,
      sitterRequirements: ["Gentle dryer handling"],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assert(result.ok);
  if (result.ok && result.outcome === "service_recommendation") {
    assertEquals(result.primary.code, "wash_dry_and_brush");
    assertEquals(result.additional[0].code, "deshedding_treatment");
  }
});

Deno.test("rejects unknown primary code", () => {
  const result = validateAiRecommendation(
    {
      outcome: "service_recommendation",
      primaryServiceCode: "unknown_service",
      additionalServiceCodes: [],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assertFalse(result.ok);
});

Deno.test("rejects duplicate additional codes", () => {
  const result = validateAiRecommendation(
    {
      outcome: "service_recommendation",
      primaryServiceCode: "wash_dry_and_brush",
      additionalServiceCodes: [
        "deshedding_treatment",
        "deshedding_treatment",
      ],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assertFalse(result.ok);
});

Deno.test("rejects non-add-on additional service", () => {
  const result = validateAiRecommendation(
    {
      outcome: "service_recommendation",
      primaryServiceCode: "wash_dry_and_brush",
      additionalServiceCodes: ["full_grooming"],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assertFalse(result.ok);
});

Deno.test("urgent outcome cannot contain services", () => {
  const withPrimary = validateAiRecommendation(
    {
      outcome: "urgent_vet",
      primaryServiceCode: "wash_dry_and_brush",
      additionalServiceCodes: [],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assertFalse(withPrimary.ok);

  const withAdditional = validateAiRecommendation(
    {
      outcome: "urgent_vet",
      primaryServiceCode: "none",
      additionalServiceCodes: ["deshedding_treatment"],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assertFalse(withAdditional.ok);

  const valid = validateAiRecommendation(
    {
      outcome: "urgent_vet",
      primaryServiceCode: "none",
      additionalServiceCodes: [],
      reasoning: baseReasoning,
      sitterRequirements: [],
      ownerAdvice: baseAdvice,
    },
    catalogue,
  );
  assert(valid.ok);
});

Deno.test("extracts choices[0].message.content", () => {
  const extracted = extractGroqChatContent({
    choices: [
      {
        message: {
          content: ' {"outcome":"urgent_vet"} ',
        },
      },
    ],
  });
  assertEquals(extracted.kind, "text");
  if (extracted.kind === "text") {
    assertEquals(extracted.text, '{"outcome":"urgent_vet"}');
  }
});

Deno.test("rejects missing choices", () => {
  assertEquals(extractGroqChatContent({ choices: [] }).kind, "missing");
  assertEquals(extractGroqChatContent({}).kind, "missing");
});

Deno.test("rejects blank message content", () => {
  const extracted = extractGroqChatContent({
    choices: [{ message: { content: "   " } }],
  });
  assertEquals(extracted.kind, "missing");
});

Deno.test("rejects invalid JSON content", () => {
  const extracted = extractGroqChatContent({
    choices: [{ message: { content: "not-json" } }],
  });
  assertEquals(extracted.kind, "text");
  if (extracted.kind === "text") {
    assertFalse(parseAiRecommendationJson(extracted.text).ok);
  }
});
