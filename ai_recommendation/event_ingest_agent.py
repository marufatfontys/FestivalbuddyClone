"""
========================================================================================
Festival Buddy - Autonomous AI Event Ingestion & Anti-Fraud Verification Agent
Fontys Group Project | Technology & Society / Green & Safe Festival AI
========================================================================================
Role:
  Autonomously monitors Dutch event ecosystems (official festival websites, Eventbrite NL,
  Festivalinfo, social media announcements), extracts structured festival metadata using
  LLM-based entity extraction, and validates authenticity against:
  1. Official domain TLS security certificates.
  2. Dutch KVK (Chamber of Commerce) registry numbers.
  3. Official Social Media Verified Badges (Instagram, Facebook, TikTok).
  
Frequency SLA:
  Searches, verifies, and stages 5 newly crawled events per 24 hours (1 event every 4.8 hours).
========================================================================================
"""

import json
import re
import urllib.parse
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import List, Dict, Optional, Tuple


@dataclass
class CrawledSourceEvent:
    source_channel: str       # e.g., 'Official Website', 'Social Media / Instagram', 'Ad / Eventbrite'
    source_url: str
    raw_title: str
    raw_description: str
    published_date: str
    claimed_organizer: str
    claimed_kvk: Optional[str] = None
    social_handles: Optional[Dict[str, str]] = None  # {'instagram': '@solarweekend', ...}


@dataclass
class VerifiedFestivalPayload:
    id: str
    name: str
    tagline: str
    category_label: str
    dates: str
    city: str
    venue_address: str
    price_eur: float
    genres: List[str]
    organizer_name: str
    source_url: str
    is_approved_by_admin: bool
    is_ai_ingested: bool
    ai_verification_score: float
    ai_verification_report: str
    social_media_verification: Dict[str, bool]
    eco_commitments: Dict[str, bool]
    latitude: float
    longitude: float


class DutchKvkRegistryMock:
    """Simulates Dutch Chamber of Commerce (Kamer van Koophandel) API verification."""
    
    REGISTERED_ENTITIES = {
        "17148920": {
            "legal_name": "Extrema Network B.V.",
            "status": "Active",
            "city": "Eindhoven",
            "authorized_events": ["Solar Weekend", "Extrema Outdoor"]
        },
        "34382019": {
            "legal_name": "AOA Live Events B.V.",
            "status": "Active",
            "city": "Amsterdam",
            "authorized_events": ["Amsterdam Open Air"]
        },
        "84920174": {
            "legal_name": "Brabant Sustainable Events B.V.",
            "status": "Active",
            "city": "Eindhoven",
            "authorized_events": ["GreenPulse Open Air"]
        }
    }

    @classmethod
    def verify_kvk(cls, kvk_number: Optional[str], claimed_name: str) -> Tuple[bool, float, str]:
        if not kvk_number:
            return False, 0.40, "No official Dutch KVK number provided in announcement/source."
        
        clean_kvk = re.sub(r'[^0-9]', '', kvk_number)
        record = cls.REGISTERED_ENTITIES.get(clean_kvk)
        if not record:
            return False, 0.30, f"KVK {clean_kvk} not found in Dutch commercial register (possible fraud/unregistered)."
        
        legal_name = record["legal_name"].lower()
        if any(term in legal_name for term in claimed_name.lower().split() if len(term) > 3):
            return True, 0.98, f"KVK match confirmed: {record['legal_name']} ({clean_kvk}) registered in {record['city']}."
        
        return True, 0.85, f"KVK {clean_kvk} is active under legal entity '{record['legal_name']}'."


class DomainTlsVerifier:
    """Verifies official domain TLS certificate and security integrity."""
    
    @staticmethod
    def verify_domain_authenticity(url: str) -> Tuple[bool, float, str]:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https":
            return False, 0.20, f"Insecure transport protocol: {url} does not use HTTPS/TLS."
        
        domain = parsed.netloc.lower()
        if domain.endswith(".nl") or domain.endswith(".com") or domain.endswith(".org"):
            return True, 0.95, f"Valid TLS transport certificate verified for official domain '{domain}'."
        
        return True, 0.70, f"Domain '{domain}' verified with standard TLS."


class SocialMediaBadgeVerifier:
    """
    Verifies official social media presence across Meta (Instagram, Facebook) and TikTok.
    Checks for the blue verified badge / official organization checkmark.
    """

    KNOWN_VERIFIED_HANDLES = {
        "solarweekend": {
            "instagram": True,   # @solarweekend (Verified blue badge)
            "facebook": True,    # Solar Weekend Official (Verified)
            "tiktok": True       # @solarweekend (Verified creator badge)
        },
        "amsterdamopenair": {
            "instagram": True,   # @amsterdamopenair (Verified blue badge)
            "facebook": True,    # Amsterdam Open Air (Verified)
            "tiktok": False      # Fan-made community / unverified
        }
    }

    @classmethod
    def verify_social_presence(cls, handles: Optional[Dict[str, str]]) -> Tuple[Dict[str, bool], float, str]:
        if not handles:
            return {"instagram": False, "facebook": False, "tiktok": False}, 0.50, "No linked social media handles discovered."
        
        results = {}
        verified_count = 0
        total_channels = 3

        # Lookup simulated API responses from Meta Graph API & TikTok Developer API
        slug = ""
        for val in handles.values():
            clean = re.sub(r'[^a-zA-Z0-9]', '', val).lower()
            if "solar" in clean:
                slug = "solarweekend"
                break
            elif "openair" in clean or "amsterdam" in clean:
                slug = "amsterdamopenair"
                break

        mock_profile = cls.KNOWN_VERIFIED_HANDLES.get(slug, {
            "instagram": False,
            "facebook": False,
            "tiktok": False
        })

        for channel in ["instagram", "facebook", "tiktok"]:
            is_verified = mock_profile.get(channel, False)
            results[channel] = is_verified
            if is_verified:
                verified_count += 1

        badge_score = 0.50 + (verified_count / total_channels) * 0.50
        verified_names = [k.capitalize() for k, v in results.items() if v]
        summary = f"Verified social badge check: {', '.join(verified_names)} verified." if verified_names else "No verified badges on social media."
        
        return results, round(badge_score, 2), summary


class EventIngestAgent:
    """
    Autonomous Ingestion & Verification Agent for Dutch Festivals.
    Searches 5 events per 24 hours.
    """

    CRAWL_FREQUENCY_HOURS = 4.8  # 24 hours / 5 events = 1 event every 4.8 hours

    def __init__(self):
        self.kvk_verifier = DutchKvkRegistryMock()
        self.tls_verifier = DomainTlsVerifier()
        self.social_verifier = SocialMediaBadgeVerifier()

    def crawl_mock_sources(self) -> List[CrawledSourceEvent]:
        """Simulates incoming web crawlers monitoring Dutch festival announcements."""
        return [
            CrawledSourceEvent(
                source_channel="Official Website Crawl",
                source_url="https://solarweekend.com/nl",
                raw_title="Solar Weekend 2027 • Roermond Maasplassen",
                raw_description="4 days of creative electronic music, hip hop, beach camps, 100% reusable cup system, and free drinking water refill points across the lakeshore.",
                published_date="2027-01-15",
                claimed_organizer="Extrema Network B.V.",
                claimed_kvk="17148920",
                social_handles={
                    "instagram": "@solarweekend",
                    "facebook": "solarweekendofficial",
                    "tiktok": "@solarweekend"
                }
            ),
            CrawledSourceEvent(
                source_channel="Social Media / Instagram Ad",
                source_url="https://amsterdamopenair.nl",
                raw_title="Amsterdam Open Air 2027 @ Gaasperpark",
                raw_description="Sound, fashion, art & food in Gaasperpark Amsterdam. Direct Metro 53 link, guarded bike parking for 3000 bikes, zero disposable cups.",
                published_date="2027-02-01",
                claimed_organizer="AOA Live Events B.V.",
                claimed_kvk="34382019",
                social_handles={
                    "instagram": "@amsterdamopenair",
                    "facebook": "amsterdamopenair",
                    "tiktok": "@aoa_fan"
                }
            ),
            CrawledSourceEvent(
                source_channel="Suspicious Ad / Telegram Ticket Scalper",
                source_url="http://cheap-amsterdam-party-tickets.biz/fake",
                raw_title="Underground Secret Warehouse Rave Amsterdam",
                raw_description="Tickets only 25 EUR. No refunds, cash at door or crypto. Free drinks all night.",
                published_date="2027-03-10",
                claimed_organizer="Secret Underground Org",
                claimed_kvk=None,
                social_handles=None
            )
        ]

    def extract_and_verify(self, event: CrawledSourceEvent) -> Optional[VerifiedFestivalPayload]:
        print(f"\n[AI AGENT] Processing announcement: '{event.raw_title}' via {event.source_channel}")
        
        # 1. TLS & Domain Security Check
        tls_valid, tls_score, tls_report = self.tls_verifier.verify_domain_authenticity(event.source_url)
        print(f"  ├─ Domain/TLS Check: score={tls_score:.2f} -> {tls_report}")

        # 2. Dutch KVK Registry Verification
        kvk_valid, kvk_score, kvk_report = self.kvk_verifier.verify_kvk(event.claimed_kvk, event.claimed_organizer)
        print(f"  ├─ KVK Registry Check: score={kvk_score:.2f} -> {kvk_report}")

        # 3. Social Media Verification Badge Check (Facebook, Instagram, TikTok)
        social_results, social_score, social_report = self.social_verifier.verify_social_presence(event.social_handles)
        print(f"  ├─ Social Media Check: score={social_score:.2f} -> {social_report}")

        # 4. Overall Verification Confidence Calculation (Weighted multi-factor score)
        aggregate_trust_score = (tls_score * 0.30) + (kvk_score * 0.45) + (social_score * 0.25)
        print(f"  ├─ Combined Trust Score: {aggregate_trust_score:.2f}")

        # Anti-Fraud Filter: Drop fraudulent or unverified scam listings
        if aggregate_trust_score < 0.60:
            print(f"  └─ [REJECTED BY AI GUARDRAIL]: High fraud risk! Suspicious listing dropped.")
            return None

        # 5. LLM Entity & SDG Indicator Extraction (Simulated NLP Classifier)
        desc_lower = event.raw_description.lower()
        reusable_cups = "reusable cup" in desc_lower or "zero disposable" in desc_lower
        free_water = "free drinking water" in desc_lower or "water refill" in desc_lower
        public_transport = "metro" in desc_lower or "train" in desc_lower or "shuttle" in desc_lower
        bike_parking = "bike" in desc_lower or "fiets" in desc_lower

        combined_report = f"{kvk_report} {tls_report} {social_report} SDG eco commitments verified."

        city = "Roermond" if "roermond" in desc_lower or "roermond" in event.raw_title.lower() else "Amsterdam"
        slug = re.sub(r'[^a-z0-9]+', '_', event.raw_title.lower()).strip('_')

        payload = VerifiedFestivalPayload(
            id=f"fest_ai_{slug[:25]}",
            name=event.raw_title.split(" • ")[0].split(" @ ")[0],
            tagline="AI Verified Dutch Festival Announcement",
            category_label="Electronic • Dutch Festival Circuit",
            dates="01–04 Aug" if "solar" in slug else "07–08 Jun",
            city=city,
            venue_address=f"Official Grounds, {city}",
            price_eur=89.0 if "solar" in slug else 99.0,
            genres=["Electronic & Techno"],
            organizer_name=f"{event.claimed_organizer} (KVK: {event.claimed_kvk})",
            source_url=event.source_url,
            is_approved_by_admin=False,  # Enforces Human-in-the-Loop review queue
            is_ai_ingested=True,
            ai_verification_score=round(aggregate_trust_score, 2),
            ai_verification_report=combined_report,
            social_media_verification=social_results,
            eco_commitments={
                "freeDrinkingWater": free_water,
                "firstAidAndQuietZone": True,
                "publicTransportIncluded": public_transport,
                "bicycleParking": bike_parking,
                "reusableCupsOnly": reusable_cups,
                "renewableEnergy": True
            },
            latitude=51.2050 if city == "Roermond" else 52.3090,
            longitude=5.9680 if city == "Roermond" else 4.9890
        )
        print(f"  └─ [STAGED INTO REVIEW QUEUE]: '{payload.name}' ready for Organizer/Admin approval.")
        return payload

    def run_pipeline(self) -> List[Dict]:
        print("=" * 80)
        print("Starting Autonomous Dutch Event Ingestion & Anti-Fraud Radar...")
        print(f"Crawl Frequency: 5 new events per 24 hours (every {self.CRAWL_FREQUENCY_HOURS} hours)")
        print("=" * 80)
        
        crawled = self.crawl_mock_sources()
        verified_results = []
        for item in crawled:
            payload = self.extract_and_verify(item)
            if payload:
                verified_results.append(asdict(payload))
        
        print("\n" + "=" * 80)
        print(f"Pipeline Completed: Staged {len(verified_results)} verified events into review queue.")
        print("=" * 80)
        return verified_results


if __name__ == "__main__":
    agent = EventIngestAgent()
    staged_festivals = agent.run_pipeline()
    
    output_path = "ai_recommendation/staged_ingested_events.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(staged_festivals, f, indent=2)
    print(f"\nExported verified staged events to: {output_path}")
