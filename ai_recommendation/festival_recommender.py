"""
Festival Buddy — AI Basics Deliverable
Content-Based Festival Recommendation & SDG Eco-Scoring System
Uses Pandas + Scikit-Learn Cosine Similarity (ready for Google Colab or local Python).

Requirements satisfied:
1. Recommend festivals based on user preferences (genres, travel distance, SDG priorities, past festivals).
2. Compare user interests with festival characteristics using feature vectors & cosine similarity.
3. Rank and show the most related festivals first.
4. Explain WHY each festival is recommended ("Explainable AI") and calculate a transparent SDG Eco-Score
   without misleading greenwashing claims.
"""

from __future__ import annotations
import math
from typing import Dict, List, Any

try:
    import pandas as pd
    from sklearn.metrics.pairwise import cosine_similarity
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False


FESTIVAL_DATASET: List[Dict[str, Any]] = [
    {
        "id": "fest_greenpulse",
        "name": "GreenPulse Open Air",
        "city": "Eindhoven, NL",
        "distance_km": 4,
        "price_eur": 79.0,
        "genres": ["Electronic & Techno", "Indie & Alternative", "Pop & Dance"],
        # SDG & Environmental Commitments (Binary verified checklist)
        "free_drinking_water_sdg3": 1,
        "first_aid_quiet_zone_sdg3": 1,
        "public_transport_shuttle_sdg11": 1,
        "bicycle_parking_sdg11": 1,
        "reusable_cups_only_sdg12": 1,
        "recycling_stations_sdg12": 1,
        "renewable_energy_sdg13": 1,
        "safe_space_stewards_sdg16": 1,
        "local_eco_partners_sdg17": 1,
    },
    {
        "id": "fest_canal_roots",
        "name": "Dommel Acoustic & Roots",
        "city": "Tilburg, NL",
        "distance_km": 32,
        "price_eur": 54.0,
        "genres": ["Acoustic & Folk", "World & Jazz", "Indie & Alternative"],
        "free_drinking_water_sdg3": 1,
        "first_aid_quiet_zone_sdg3": 1,
        "public_transport_shuttle_sdg11": 1,
        "bicycle_parking_sdg11": 1,
        "reusable_cups_only_sdg12": 1,
        "recycling_stations_sdg12": 1,
        "renewable_energy_sdg13": 0,
        "safe_space_stewards_sdg16": 1,
        "local_eco_partners_sdg17": 1,
    },
    {
        "id": "fest_neon_horizon",
        "name": "Horizon Beats Festival",
        "city": "Rotterdam, NL",
        "distance_km": 98,
        "price_eur": 95.0,
        "genres": ["Pop & Dance", "Hip-Hop & R&B", "Electronic & Techno"],
        "free_drinking_water_sdg3": 1,
        "first_aid_quiet_zone_sdg3": 1,
        "public_transport_shuttle_sdg11": 1,
        "bicycle_parking_sdg11": 1,
        "reusable_cups_only_sdg12": 1,
        "recycling_stations_sdg12": 1,
        "renewable_energy_sdg13": 0,
        "safe_space_stewards_sdg16": 1,
        "local_eco_partners_sdg17": 0,
    },
    {
        "id": "fest_veluwe_bloom",
        "name": "Veluwe Bloom Gathering",
        "city": "Arnhem, NL",
        "distance_km": 68,
        "price_eur": 84.0,
        "genres": ["World & Jazz", "Acoustic & Folk", "Indie & Alternative"],
        "free_drinking_water_sdg3": 1,
        "first_aid_quiet_zone_sdg3": 1,
        "public_transport_shuttle_sdg11": 1,
        "bicycle_parking_sdg11": 1,
        "reusable_cups_only_sdg12": 1,
        "recycling_stations_sdg12": 1,
        "renewable_energy_sdg13": 1,
        "safe_space_stewards_sdg16": 1,
        "local_eco_partners_sdg17": 1,
    },
]

ALL_GENRES = [
    "Electronic & Techno",
    "Indie & Alternative",
    "Pop & Dance",
    "Hip-Hop & R&B",
    "Acoustic & Folk",
    "World & Jazz",
]

ECO_FEATURE_KEYS = [
    "free_drinking_water_sdg3",
    "first_aid_quiet_zone_sdg3",
    "public_transport_shuttle_sdg11",
    "bicycle_parking_sdg11",
    "reusable_cups_only_sdg12",
    "recycling_stations_sdg12",
    "renewable_energy_sdg13",
    "safe_space_stewards_sdg16",
    "local_eco_partners_sdg17",
]


def _manual_cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    dot = sum(a * b for a, b in zip(vec_a, vec_b))
    norm_a = math.sqrt(sum(a * a for a in vec_a))
    norm_b = math.sqrt(sum(b * b for b in vec_b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def build_feature_vector(
    genres: List[str],
    eco_flags: Dict[str, int],
    distance_km: float,
    max_preferred_distance: float,
) -> List[float]:
    # Genre one-hot encoding (weighted 1.5x so music taste is strong)
    genre_vec = [1.5 if g in genres else 0.0 for g in ALL_GENRES]
    # Eco/SDG commitments vector
    eco_vec = [float(eco_flags.get(k, 0)) for k in ECO_FEATURE_KEYS]
    # Proximity feature (1.0 if within preferred distance, else decays smoothly)
    proximity = 1.0 if distance_km <= max_preferred_distance else max(0.1, 1.0 - (distance_km - max_preferred_distance) / 120.0)
    return genre_vec + eco_vec + [proximity * 1.2]


def recommend_festivals(user_profile: Dict[str, Any]) -> List[Dict[str, Any]]:
    preferred_genres = set(user_profile.get("preferred_genres", []))
    attended_ids = set(user_profile.get("attended_festival_ids", []))
    max_dist = float(user_profile.get("max_distance_km", 60.0))

    # Include genres from previously attended festivals
    for fest in FESTIVAL_DATASET:
        if fest["id"] in attended_ids:
            preferred_genres.update(fest["genres"])

    user_eco_prefs = {
        "free_drinking_water_sdg3": 1,
        "first_aid_quiet_zone_sdg3": 1 if user_profile.get("prioritize_health_sdg3", True) else 0,
        "public_transport_shuttle_sdg11": 1 if user_profile.get("prioritize_transit_sdg11", True) else 0,
        "bicycle_parking_sdg11": 1,
        "reusable_cups_only_sdg12": 1 if user_profile.get("prioritize_zero_waste_sdg12", True) else 0,
        "recycling_stations_sdg12": 1 if user_profile.get("prioritize_zero_waste_sdg12", True) else 0,
        "renewable_energy_sdg13": 1,
        "safe_space_stewards_sdg16": 1,
        "local_eco_partners_sdg17": 1,
    }

    user_vector = build_feature_vector(
        genres=list(preferred_genres),
        eco_flags=user_eco_prefs,
        distance_km=0.0,
        max_preferred_distance=max_dist,
    )

    recommendations = []
    for fest in FESTIVAL_DATASET:
        fest_vector = build_feature_vector(
            genres=fest["genres"],
            eco_flags=fest,
            distance_km=fest["distance_km"],
            max_preferred_distance=max_dist,
        )

        if HAS_SKLEARN:
            sim = float(cosine_similarity([user_vector], [fest_vector])[0][0])
        else:
            sim = _manual_cosine_similarity(user_vector, fest_vector)

        eco_met = sum(fest[k] for k in ECO_FEATURE_KEYS)
        eco_pct = round((eco_met / len(ECO_FEATURE_KEYS)) * 100)

        # Build human-readable Explainable AI reasons
        matching_genres = [g for g in fest["genres"] if g in user_profile.get("preferred_genres", [])]
        reasons = []
        if matching_genres:
            reasons.append(f"Matches your favorite genres ({', '.join(matching_genres)})")
        if fest["reusable_cups_only_sdg12"] and fest["recycling_stations_sdg12"]:
            reasons.append("100% reusable cups & recycling bins (SDG 12)")
        if fest["public_transport_shuttle_sdg11"]:
            reasons.append("Direct public transport & shuttle access (SDG 11 & 13)")
        if fest["distance_km"] <= max_dist:
            reasons.append(f"Within your {int(max_dist)} km travel radius ({fest['distance_km']} km)")

        recommendations.append({
            "festival_name": fest["name"],
            "city": fest["city"],
            "match_percentage": round(sim * 100),
            "eco_score_percentage": eco_pct,
            "eco_commitments_met": f"{eco_met}/{len(ECO_FEATURE_KEYS)}",
            "why_recommended": " | ".join(reasons),
        })

    # Sort descending by match_percentage (Requirement 3: Show most related festivals first)
    recommendations.sort(key=lambda x: x["match_percentage"], reverse=True)
    return recommendations


if __name__ == "__main__":
    sample_user = {
        "preferred_genres": ["Electronic & Techno", "Indie & Alternative"],
        "max_distance_km": 60,
        "prioritize_zero_waste_sdg12": True,
        "prioritize_transit_sdg11": True,
        "prioritize_health_sdg3": True,
        "attended_festival_ids": ["fest_greenpulse"],
    }

    print("=" * 78)
    print("FESTIVAL BUDDY — AI RECOMMENDATION ENGINE (COSINE SIMILARITY + SDG SCORE)")
    print(f"Engine Backend: {'Pandas + Scikit-Learn' if HAS_SKLEARN else 'Standard Python Cosine Vector Engine'}")
    print("=" * 78)

    ranked = recommend_festivals(sample_user)
    if HAS_SKLEARN:
        df = pd.DataFrame(ranked)
        print(df.to_string(index=False))
    else:
        for idx, item in enumerate(ranked, start=1):
            print(
                f"{idx}. {item['festival_name']} ({item['city']}) — "
                f"Match: {item['match_percentage']}% | Eco Score: {item['eco_score_percentage']}% ({item['eco_commitments_met']})\n"
                f"   Why Recommended: {item['why_recommended']}\n"
            )
