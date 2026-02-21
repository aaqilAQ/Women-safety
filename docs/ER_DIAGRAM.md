# 📊 Entity-Relationship (ER) Diagram — SafeStep

> This document describes all data entities, their attributes, and the relationships between them in the SafeStep Women Safety Application.

---

## 1. ER Diagram (Text Representation)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SafeStep ER Diagram                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────┐          ┌───────────────────────────┐
  │        USER          │          │      EMERGENCY_CONTACT     │
  ├──────────────────────┤          ├───────────────────────────┤
  │ *uid : String (PK)   │  1    N  │ *contact_id : String (PK) │
  │  name : String       │──────────│  name : String            │
  │  phone : String      │  has     │  phone : String           │
  │  email : String      │          │  relation : String        │
  │  isActive : Boolean  │          │  user_uid : String (FK)   │
  └──────────────────────┘          └───────────────────────────┘
           │                                        
           │ 1                                      
           │                                        
           │ N                                      
  ┌───────────────────────┐
  │     ALERT_EVENT       │
  ├───────────────────────┤
  │ *alert_id : String(PK)│
  │  user_uid : String(FK)│         ┌──────────────────────────┐
  │  trigger_type : String│         │       VOICE_TRIGGER       │
  │  timestamp : DateTime │  1    N │ ──────────────────────── │
  │  latitude : Double    │         │ *trigger_id : String (PK) │
  │  longitude : Double   │  USER   │  user_uid : String (FK)  │
  │  location_text : String         │  word : String            │
  │  sms_sent : Boolean   │  has    │  created_at : DateTime   │
  │  audio_path : String? │         └──────────────────────────┘
  └───────────────────────┘
           │
           │ 1
           │
           │ N
  ┌───────────────────────┐
  │      SMS_LOG          │
  ├───────────────────────┤
  │ *log_id : String (PK) │
  │  alert_id : String(FK)│
  │  contact_phone : String│
  │  status : String      │  (sent / failed)
  │  sent_at : DateTime   │
  └───────────────────────┘


  ┌───────────────────────────────────────────────────┐
  │               APP_SETTINGS                        │
  ├───────────────────────────────────────────────────┤
  │  user_uid : String (FK, 1:1 with USER)            │
  │  shake_enabled : Boolean    (default: true)       │
  │  voice_enabled : Boolean    (default: true)       │
  │  hold_button_enabled : Boolean (default: true)    │
  │  shake_threshold_x : Double (default: 25.0)       │
  │  shake_threshold_y : Double (default: 25.0)       │
  │  shake_threshold_z : Double (default: 25.0)       │
  │  button_trigger_type : String (volume / power)    │
  │  voice_trained : Boolean    (default: false)      │
  └───────────────────────────────────────────────────┘
```

---

## 2. Entities & Attributes Detail

### 2.1 USER

Stored in: **Firebase Firestore** (`users/{uid}`)

| Attribute | Type | Constraint | Description |
|---|---|---|---|
| `uid` | String | PK, Not Null | Firebase Auth UID |
| `name` | String | Not Null | Display name |
| `phone` | String | Not Null, Unique | Registered phone number |
| `email` | String | Optional | Email address |
| `isActive` | Boolean | Default: true | Account active status |

---

### 2.2 EMERGENCY_CONTACT

Stored in: **Firebase Firestore** (`users/{uid}/emergencyContacts`) + **SharedPreferences** (`cached_contacts`) + **Hive** (local cache)

| Attribute | Type | Constraint | Description |
|---|---|---|---|
| `contact_id` | String | PK (auto) | Unique contact identifier |
| `name` | String | Not Null | Contact's display name |
| `phone` | String | Not Null | Contact's phone number |
| `relation` | String | Not Null | Relationship (e.g., "Mother", "Friend") |
| `user_uid` | String | FK → USER | Owner of this contact |

**Business Rules:**
- Maximum **5** emergency contacts per user
- Phone number must be valid format
- Duplicate phone numbers not allowed

---

### 2.3 ALERT_EVENT

Stored in: **Firebase Firestore** (`alerts/{alert_id}`) — *planned*; currently in **SharedPreferences** (recent alerts)

| Attribute | Type | Constraint | Description |
|---|---|---|---|
| `alert_id` | String | PK (UUID) | Unique alert identifier |
| `user_uid` | String | FK → USER | Who triggered the alert |
| `trigger_type` | String | Not Null | `voice` / `shake` / `volume_button` / `manual` |
| `timestamp` | DateTime | Not Null | When alert was triggered |
| `latitude` | Double | Nullable | GPS latitude at trigger time |
| `longitude` | Double | Nullable | GPS longitude at trigger time |
| `location_text` | String | Nullable | Human-readable address |
| `sms_sent` | Boolean | Default: false | Whether SMS was dispatched |
| `audio_path` | String | Nullable | Path to recorded audio file |

---

### 2.4 SMS_LOG

Stored in: **In-Memory** during alert session (ephemeral)

| Attribute | Type | Constraint | Description |
|---|---|---|---|
| `log_id` | String | PK | Unique log entry |
| `alert_id` | String | FK → ALERT_EVENT | Parent alert |
| `contact_phone` | String | Not Null | Recipient number |
| `status` | String | Not Null | `sent` / `failed` / `pending` |
| `sent_at` | DateTime | Nullable | Delivery timestamp |

---

### 2.5 VOICE_TRIGGER

Stored in: **SharedPreferences** (`custom_voice_triggers`)

| Attribute | Type | Constraint | Description |
|---|---|---|---|
| `trigger_id` | Auto | PK | Array index |
| `user_uid` | String | FK → USER | Owner |
| `word` | String | Not Null, Unique | Trigger keyword |
| `created_at` | DateTime | Not Null | When word was added |

**Default words** always active (hardcoded): `help`, `sos`, `emergency`, `bachao`, `madad`

**Business Rules:**
- Maximum **5** custom trigger words
- Words are case-insensitive (stored in lowercase)
- Duplicates are rejected

---

### 2.6 APP_SETTINGS

Stored in: **SharedPreferences** (key-value pairs per user)

| Attribute | Key String | Type | Default |
|---|---|---|---|
| Shake enabled | `shake_enabled` | Boolean | `true` |
| Voice enabled | `voice_enabled` | Boolean | `true` |
| Button enabled | `hold_button_enabled` | Boolean | `true` |
| Shake X threshold | `shake_threshold_x` | Double | `25.0` |
| Shake Y threshold | `shake_threshold_y` | Double | `25.0` |
| Shake Z threshold | `shake_threshold_z` | Double | `25.0` |
| Button type | `button_trigger_type` | String | `volume` |
| Voice trained | `voice_trained` | Boolean | `false` |
| Cached user name | `cached_user_name` | String | — |
| Cached contacts | `cached_contacts` | JSON String | `[]` |

---

## 3. Relationships Summary

| Relationship | Cardinality | Description |
|---|---|---|
| USER → EMERGENCY_CONTACT | 1 : N (max 5) | A user has multiple trusted contacts |
| USER → ALERT_EVENT | 1 : N | A user can trigger multiple alerts |
| USER → VOICE_TRIGGER | 1 : N (max 5) | A user can have multiple trigger words |
| USER → APP_SETTINGS | 1 : 1 | Each user has exactly one settings record |
| ALERT_EVENT → SMS_LOG | 1 : N | One alert sends SMS to multiple contacts |

---

## 4. Storage Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA STORAGE LAYERS                          │
├──────────────────┬──────────────────┬──────────────────────────┤
│  Firebase        │  SharedPreferences│  Hive (Local DB)        │
│  Firestore       │  (key-value)      │  (Box storage)          │
├──────────────────┼──────────────────┼──────────────────────────┤
│ • User profile   │ • All settings   │ • Contact cache          │
│ • Contacts (sync)│ • Contact cache  │  (isolate-safe backup)   │
│ • Alert history  │ • Voice triggers │                          │
│   (planned)      │ • Cached name    │                          │
└──────────────────┴──────────────────┴──────────────────────────┘

Why 3 storage layers?
• Firebase → cloud sync, multi-device access, backup
• SharedPreferences → fast foreground + background isolate reads
• Hive → isolate-safe persistent backup (fixes MissingPluginException)
```

---

*Document generated: February 2026 | SafeStep v1.0.0*
