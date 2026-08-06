// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { validateRecommendationBody } from "./validation.ts";

type RecommendationPet = {
  id: string;
  name: string;
  species: string;
  breed: string | null;
  ageYears: number | null;
  size: string | null;
  coatType: string | null;
  medicalNotes: string | null;
  behaviourNotes: string | null;
  careNotes: string | null;
};

type RecommendationService = {
  id: string;
  code: string;
  name: string;
  category: string;
  description: string;
  includedItems: string[];
  recommendationTags: string[];
  canBeAddOn: boolean;
};

/** Internal context for T09B2 — never returned to Flutter or logged. */
type RecommendationContext = {
  pet: RecommendationPet;
  ownerDescription: string;
  availableServices: RecommendationService[];
};

function jsonError(
  status: number,
  code: string,
  message: string,
  extraHeaders?: HeadersInit,
): Response {
  return Response.json(
    {
      error: {
        code,
        message,
      },
    },
    {
      status,
      headers: extraHeaders,
    },
  );
}

function serverError(): Response {
  return jsonError(
    500,
    "server_error",
    "Something went wrong. Please try again.",
  );
}

// This endpoint uses 'user' access; credentials are required.
export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    try {
      if (req.method !== "POST") {
        return jsonError(
          405,
          "invalid_request",
          "Method not allowed. Use POST.",
          { Allow: "POST" },
        );
      }

      let body: unknown;
      try {
        body = await req.json();
      } catch {
        return jsonError(
          400,
          "invalid_request",
          "Please provide valid recommendation details.",
        );
      }

      const parsed = validateRecommendationBody(body);
      if (!parsed.ok) {
        return jsonError(400, "invalid_request", parsed.message);
      }

      const userId = ctx.userClaims?.id;
      if (!userId) {
        return serverError();
      }

      const { data: profile, error: profileError } = await ctx.supabase
        .from("profiles")
        .select("id, role")
        .eq("id", userId)
        .maybeSingle();

      if (profileError) {
        return serverError();
      }

      if (
        profile == null ||
        profile.id !== userId ||
        profile.role !== "owner"
      ) {
        return jsonError(
          403,
          "not_an_owner",
          "Only pet owners can request service recommendations.",
        );
      }

      const { data: pet, error: petError } = await ctx.supabase
        .from("pets")
        .select(
          "id, name, species, breed, age_years, size, coat_type, " +
            "medical_notes, behaviour_notes, care_notes",
        )
        .eq("id", parsed.value.petId)
        .eq("owner_id", userId)
        .maybeSingle();

      if (petError) {
        return serverError();
      }

      if (pet == null) {
        return jsonError(404, "pet_not_found", "Pet not found.");
      }

      const { data: services, error: servicesError } = await ctx.supabase
        .from("services")
        .select(
          "id, code, name, category, description, included_items, " +
            "recommendation_tags, can_be_add_on, display_order",
        )
        .eq("is_active", true)
        .order("display_order", { ascending: true });

      if (servicesError) {
        return serverError();
      }

      if (services == null || services.length === 0) {
        return jsonError(
          503,
          "catalogue_unavailable",
          "Service catalogue is temporarily unavailable.",
        );
      }

      const recommendationContext: RecommendationContext = {
        pet: {
          id: pet.id,
          name: pet.name,
          species: pet.species,
          breed: pet.breed,
          ageYears: pet.age_years,
          size: pet.size,
          coatType: pet.coat_type,
          medicalNotes: pet.medical_notes,
          behaviourNotes: pet.behaviour_notes,
          careNotes: pet.care_notes,
        },
        ownerDescription: parsed.value.ownerDescription,
        availableServices: services.map((service) => ({
          id: service.id,
          code: service.code,
          name: service.name,
          category: service.category,
          description: service.description,
          includedItems: service.included_items ?? [],
          recommendationTags: service.recommendation_tags ?? [],
          canBeAddOn: service.can_be_add_on,
        })),
      };

      // Prepared for T09B2; intentionally unused in this ticket.
      void recommendationContext;

      return Response.json({
        ready: true,
        petId: pet.id,
        serviceCount: services.length,
        requestId: crypto.randomUUID(),
      });
    } catch {
      return serverError();
    }
  }),
};

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/recommend-service' \
    --header 'apiKey: <publishable-key>' \
    --header 'Authorization: Bearer <UserToken>' \
    --header 'Content-Type: application/json' \
    --data '{"petId":"<uuid>","ownerDescription":"My dog needs a wash and nail trim today."}'
*/
