# Festival Buddy — Sustainable Festival Discovery & Offline Companion

**Fontys Group Project:** Burdzhu, Maruf, Yusuf, Priya, Filip

Festival Buddy is a cross-platform **iOS & Android (Flutter)** application and **Python AI Recommendation System** that connects environmentally conscious festival discovery with an offline-first on-site festival companion.

---

## Project Structure & Group Deliverables

| Study Area | Key Deliverables Included in Repository |
| :--- | :--- |
| **Analysis & Advice Report** | [`docs/Festival_Buddy_Analysis_and_Advice.md`](docs/Festival_Buddy_Analysis_and_Advice.md) — Complete report with Section 1.2 (Software), Section 1.4 (Cybersecurity 2), full Functional/Non-Functional Requirements, and MoSCoW table. |
| **Interactive Media** | [`lib/screens/main_shell.dart`](lib/screens/main_shell.dart), [`lib/screens/festival_detail_screen.dart`](lib/screens/festival_detail_screen.dart), [`lib/screens/companion_view.dart`](lib/screens/companion_view.dart) — Joyful, low-tech accessible UI with High-Contrast Night Mode and Easy-Read Large Text toggles. |
| **Software Engineering** | [`lib/models/festival_models.dart`](lib/models/festival_models.dart), [`lib/services/app_state.dart`](lib/services/app_state.dart), [`test/widget_test.dart`](test/widget_test.dart) — Modular state architecture, Guest-First onboarding, offline tent/car/bike pin saver, and automated tests. |
| **Cybersecurity 1 & 2** | [`lib/screens/auth_modal.dart`](lib/screens/auth_modal.dart), [`lib/screens/profile_security_screen.dart`](lib/screens/profile_security_screen.dart), [`docs/cybersecurity_diagrams.puml`](docs/cybersecurity_diagrams.puml), [`docs/secure_schema.sql`](docs/secure_schema.sql) — Argon2id hashing, 5-attempt 15-min lockout, 30-min inactivity logout, 24h single-use reset, account-bound QR tickets, 1-click GDPR JSON export/deletion, and live Security Audit Log. |
| **AI Basics** | [`ai_recommendation/festival_recommender.py`](ai_recommendation/festival_recommender.py) & [`lib/services/app_state.dart`](lib/services/app_state.dart) — Content-based cosine similarity recommender, *"Why recommended"* explainable AI badges, and 9-point SDG Eco-Commitment scoring. |

---

## Demo Accounts (Pre-Seeded in Prototype)

You can also use the **1-Tap Quick Fill** buttons inside the Sign-In sheet or the **Role Switcher** in the Organizer tab:

- **Visitor:** `visitor@fontys.nl` / `EcoPassword2027!`
- **Organizer:** `organizer@greenpulse.nl` / `OrgSecure2027!`
- **Admin:** `admin@festivalbuddy.nl` / `AdminVault2027!`

---

## Running the App & AI Script

### 1. Run the Flutter App (iOS / Android / Chrome)
```bash
"/Users/marufahmed/Fontys Group Project/flutter/bin/flutter" run
```

### 2. Run Automated Tests
```bash
"/Users/marufahmed/Fontys Group Project/flutter/bin/flutter" test
```

### 3. Run the Python AI Recommendation Script
```bash
python3 ai_recommendation/festival_recommender.py
```
