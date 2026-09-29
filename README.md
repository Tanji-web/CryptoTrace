# CryptoTrace — VASP Attribution Portal

![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Backend-Python-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi&logoColor=white)
![Ethereum](https://img.shields.io/badge/Blockchain-Ethereum-3C3C3D?logo=ethereum&logoColor=white)
![Tests](https://img.shields.io/badge/Backend%20tests-34%20passed-success)
![Flutter Tests](https://img.shields.io/badge/Frontend%20tests-8%20passed-success)

## Overview

**CryptoTrace** is an evidence-oriented Ethereum transaction investigation prototype for **automated, explainable VASP attribution**.

Given an Ethereum wallet and a configurable trace depth, CryptoTrace:

1. collects and filters transaction candidates,
2. builds a bounded transaction graph,
3. identifies the nearest known/demo VASP,
4. explains the heuristic confidence and risk scores,
5. detects graph-derived investigation patterns,
6. exposes transaction-level evidence and direction,
7. creates a reproducible case snapshot,
8. exports a forensic PDF and machine-readable Case JSON.

The project was built for **Smart India Hackathon (SIH) 2026**, under the Blockchain & Cybersecurity theme.

> **Important:** CryptoTrace is an investigation aid, not an identity-verification or criminality-verdict system. Graph proximity does not prove wallet ownership, VASP control, identity, or illicit activity.

---

## Why CryptoTrace?

Traditional wallet investigation can require manually moving between blockchain explorers, transaction histories, graph relationships, and entity information.

CryptoTrace combines that workflow into one interface:

```text
Wallet
  ↓
Transaction Graph
  ↓
VASP Candidate
  ↓
Evidence
  ↓
Explainable Scores
  ↓
Investigation Patterns
  ↓
Case Package
```

The emphasis is on **evidence + explainability**, not an opaque verdict.

---

## Key Features

### Ethereum tracing
- Ethereum mainnet
- configurable 1–3 hop trace
- minimum native ETH threshold of 0.0005 ETH
- normal ETH transfers
- internal ETH transfers
- ERC-20 structural tracing
- contract interaction handling
- bounded graph traversal

### VASP attribution
- registry-based candidate matching
- nearest-path attribution
- observed path direction:
  - outbound
  - inbound
  - mixed
  - unknown
- VASP provenance
- source information
- verification status
- public source URL where available

### Explainability
- heuristic confidence score
- heuristic risk score
- factor-by-factor score breakdown
- trace analysis counters
- transparent data-source status

### Investigation patterns
- fan-out
- fan-in
- rapid forwarding
- long routing chain
- repeated routing
- near-threshold transfer clustering

These are **indicators for further investigation**, not proof of wrongdoing.

### Transaction evidence
- transaction hash
- amount
- asset
- timestamp
- block number
- transaction type
- token metadata
- live explorer links
- exact transaction hashes for selected attribution-path hops

### Case package
- Case ID
- case snapshot
- forensic PDF
- Case JSON
- VASP provenance
- transaction evidence
- scoring breakdown
- investigation patterns
- disclaimers

### Investigation workspace
- graph search
- asset filter
- direction filter
- pattern-only mode
- evidence mode
- path highlighting
- reset filters
- collapse/expand Attribution & Evidence on wide layouts

### Reliability
- deterministic demo/mock mode
- short-TTL trace caching
- API rate protection
- structured API error handling
- loading/retry UX
- frontend automated tests
- backend automated tests

---

## Architecture

```text
                     ┌───────────────────────────┐
                     │       Flutter UI          │
                     │                           │
                     │ Wallet Input              │
                     │ Graph + Controls          │
                     │ Attribution               │
                     │ Evidence                  │
                     │ Case Export               │
                     └────────────┬──────────────┘
                                  │ HTTP
                                  ▼
                     ┌───────────────────────────┐
                     │        FastAPI API        │
                     └────────────┬──────────────┘
                                  │
               ┌──────────────────┼──────────────────┐
               ▼                  ▼                  ▼
        Etherscan API          Mock Data       Case Services
               │                  │                  │
               └──────────────────┼──────────────────┘
                                  ▼
                     ┌───────────────────────────┐
                     │ Parse / Filter / Classify │
                     └────────────┬──────────────┘
                                  ▼
                     ┌───────────────────────────┐
                     │ NetworkX Transaction Graph│
                     └────────────┬──────────────┘
                                  ▼
               ┌──────────────────┼──────────────────┐
               ▼                  ▼                  ▼
          Attribution          Scoring          Patterns
               │                  │                  │
               └──────────────────┼──────────────────┘
                                  ▼
                     ┌───────────────────────────┐
                     │ Response / Case Evidence │
                     │ PDF / JSON                │
                     └───────────────────────────┘
```

---

## Repository Structure

```text
CryptoTrace/
├── backend/
│   ├── main.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── .gitignore
│   ├── cryptotrace/
│   │   ├── config.py
│   │   ├── registry.py
│   │   ├── models.py
│   │   ├── utils.py
│   │   ├── ingestion/
│   │   │   ├── etherscan.py
│   │   │   └── mock.py
│   │   ├── graph/
│   │   │   ├── tracer.py
│   │   │   ├── attribution.py
│   │   │   ├── scoring.py
│   │   │   └── patterns.py
│   │   ├── services/
│   │   │   ├── response.py
│   │   │   ├── case_store.py
│   │   │   ├── trace_cache.py
│   │   │   └── rate_limit.py
│   │   ├── reporting/
│   │   │   └── pdf.py
│   │   └── api/
│   │       ├── app.py
│   │       └── routes.py
│   └── tests/
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── models/
│   │   ├── services/
│   │   ├── screens/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── widgets/
│   │       ├── graph/
│   │       ├── attribution/
│   │       └── evidence/
│   └── test/
│
├── README.md
└── PROJECT_CONTEXT.md
```

---

## Backend Technology

- Python
- FastAPI
- Pydantic
- NetworkX
- httpx
- python-dotenv
- ReportLab
- Etherscan API

## Frontend Technology

- Flutter
- Dart
- Material 3
- StatefulWidget + setState
- http
- url_launcher

---

## Configuration

### Backend

Use an environment file based on:

```text
backend/.env.example
```

Never commit real secrets.

The Etherscan API key belongs only in the backend environment.

### Frontend

Default development backend:

```text
http://localhost:8000
```

A different backend can be supplied at runtime:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

---

## Running the Backend

From `backend/`:

```powershell
python main.py
```

Health endpoint:

```text
GET http://localhost:8000/api/health
```

---

## Running the Frontend

From `frontend/`:

```powershell
flutter pub get
flutter run
```

---

## API

### Health

```text
GET /api/health
```

### Trace

```text
POST /api/trace
```

Example:

```json
{
  "wallet_address": "0x...",
  "max_hops": 2
}
```

### Forensic PDF

```text
GET /api/report/{wallet}
```

Optional case ID may be supplied so the exact stored case snapshot is exported.

### Case JSON

```text
GET /api/case/{wallet}
```

Optional case ID may be supplied.

---

## Graph Investigation Controls

The top graph toolbar currently supports:

### Search

Search for wallet/address or transaction information and emphasize matching graph content.

### Asset

```text
All
ETH
ERC-20
Contract
```

### Direction

```text
All
Outgoing from target
Incoming to target
```

### Patterns only

Focus on graph elements associated with detected investigation patterns.

### Evidence mode

Focus on the selected attribution path and its supporting transaction evidence.

### Reset

Restore all graph filters and modes.

### Collapse Attribution & Evidence

On wide desktop layouts, the right-side evidence panel can be hidden so the graph takes over the workspace.

---

## Graph Visualization

The graph supports:

- zoom and pan
- directed arrows
- multiple transactions between the same wallets
- opposite-direction edge separation
- transaction labels
- pattern highlighting
- evidence-path highlighting
- node details
- safe node placement without boundary clipping

---

## Mock / Demo Mode

CryptoTrace includes deterministic demo data.

The mock is intentionally designed for demonstrations and testing without a live Etherscan key.

It is designed to support:
- meaningful 1-hop traces
- meaningful 2-hop traces
- meaningful 3-hop traces
- VASP reachability at the requested depth
- investigation-pattern examples
- below-threshold filtering behavior

> Mock data is demonstration data only. It is not real blockchain intelligence.

---

## Live Ethereum Mode

Live mode uses Etherscan Ethereum mainnet data.

The implementation includes:
- bounded API calls
- timeouts
- candidate limits
- graph-node limits
- partial-data handling
- rate protection
- live failure reporting

Explorer links are provided for live transaction hashes.

---

## VASP Provenance

Registry records can include:
- VASP name
- VASP type
- address
- source
- source type
- source URL
- verification status
- last verified
- notes

Demo registry records are intentionally labeled as demo/unverified.

A registry match is not proof of ownership or control.

---

## Scoring

CryptoTrace uses deterministic heuristic scores.

### Confidence

Considers:
- hop distance
- direct-path relationship
- intermediary wallets
- verification state
- demo/mock data
- live API failure

### Risk

Considers:
- base risk
- intermediary wallets
- graph sparsity
- fragmented routing

The UI exposes the factors used to derive the final numbers.

These are heuristic scores, not statistical probabilities.

---

## Investigation Patterns

CryptoTrace can detect:

| Pattern | Meaning |
|---|---|
| Fan-out | One wallet sends to multiple downstream counterparties |
| Fan-in | Multiple upstream wallets send into one wallet |
| Rapid forwarding | Incoming value is followed by outgoing movement within a short window |
| Long route | Attribution path reaches a longer hop depth |
| Repeated routing | Intermediary shows repeated inbound/outbound relationships |
| Near-threshold cluster | Multiple transfers appear near the configured threshold in a time window |

These patterns are **investigation indicators only**.

They do not prove:
- criminal intent
- money laundering
- illegal activity
- ownership
- VASP control

---

## Evidence and Case Workflow

```text
Trace
  ↓
Case ID
  ↓
Graph
  ↓
Attribution
  ↓
Provenance
  ↓
Transaction Evidence
  ↓
Score Explanation
  ↓
Pattern Indicators
  ↓
PDF + Case JSON
```

Case snapshots are session-level prototype data unless persistent storage is added in the future.

If an existing case ID is missing/expired, the backend does not silently create a replacement trace under the old ID.

---

## Testing

### Backend

```powershell
cd backend
python -m pytest -q
```

Current baseline:

```text
34 passed
```

Current warnings are dependency deprecations, not test failures.

### Frontend

```powershell
cd frontend
flutter analyze
flutter test
```

Current baseline:

```text
No issues found!
8 tests passed
```

---

## Current Feature Milestones

```text
Step 0  Architecture / modularization       ✅
Step 1  VASP provenance                      ✅
Step 2  Transaction evidence                 ✅
Step 3  Confidence/risk explanation          ✅
Step 4  Investigation patterns               ✅
Step 5  Evidence + Case package              ✅
P0      Demo hardening                       ✅
P1      Forensic correctness                 ✅
P2      Reliability/security hardening       ✅
Step 6  Investigation controls               ✅
Step 7  Frontend testing                     ✅
Step 8  Loading/error UX                     ✅
Step 9  Graph workspace improvements         ✅
```

---

## Security Notes

Before publishing:

- never commit `.env`
- never commit API keys
- use `.env.example`
- review CORS before public deployment
- keep rate limits enabled
- keep graph/API limits enabled
- avoid exposing backend credentials to Flutter

---

## Limitations

CryptoTrace is a hackathon-stage prototype.

It is not currently:
- multi-chain
- authenticated multi-user case management
- persistent enterprise evidence storage
- a probabilistic identity-attribution engine
- a substitute for regulated compliance or forensic intelligence

---

## Responsible Interpretation

Use wording such as:

> "The wallet is graphically connected to a known/demo VASP within N hops."

> "The observed direction is outbound/inbound/mixed."

> "The graph contains a fan-out pattern."

Avoid stating:

> "This wallet belongs to the exchange."

> "This wallet is definitely illicit."

> "This proves money laundering."

---

## Project Status

CryptoTrace is considered **feature-complete for the SIH final-round prototype**.

The current focus is:
- final integration verification
- demo rehearsal
- presentation
- screenshots/documentation
- GitHub cleanup
- optional future hardening

---

## License / Open Source

The project is built around open-source technologies and public blockchain data sources. Add the final project-specific license and repository links here when publishing.

---

## Responsible Use

CryptoTrace should be used as an investigative aid with human review. Any real-world attribution or compliance decision should be independently verified using authoritative intelligence and appropriate legal/compliance processes.
