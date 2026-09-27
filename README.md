# CryptoTrace — VASP Attribution Portal

> **Blockchain investigation and evidence platform for Ethereum wallet tracing**

CryptoTrace is a cybersecurity / blockchain-forensics prototype that traces Ethereum wallet transaction paths, identifies the nearest known VASP (Virtual Asset Service Provider), explains the heuristic attribution score, detects graph-derived investigation patterns, and packages the resulting evidence into a forensic PDF and machine-readable Case JSON.

The project is designed around **traceability, explainability, and evidence preservation** rather than automatic accusations or identity claims.

---

## ✨ What CryptoTrace Does

```text
Ethereum Wallet
      ↓
Transaction Collection
      ↓
Filtering + Classification
      ↓
Transaction Graph
      ↓
Path / VASP Attribution
      ↓
Confidence + Risk Explanation
      ↓
Investigation Pattern Detection
      ↓
Evidence + Case Snapshot
      ↓
PDF Report / Case JSON
```

### Core capabilities

- Ethereum wallet address validation
- Configurable tracing depth: **1–3 hops**
- Minimum native ETH transfer threshold: **0.0005 ETH**
- Ethereum mainnet transaction ingestion through Etherscan
- Normal ETH transactions
- Internal ETH transactions
- ERC-20 transfers represented structurally in the graph without token price conversion
- Contract interaction handling
- Candidate filtering and per-wallet limits
- Directed **NetworkX MultiDiGraph** transaction model
- Deterministic mock/demo mode
- VASP registry matching and provenance
- Direction-aware VASP path information
- Transparent confidence and risk scoring breakdown
- Graph-derived investigation indicators
- Transaction-level evidence and Etherscan links for live transactions
- Case IDs and in-memory case snapshots
- Forensic PDF reports
- Machine-readable Case JSON export
- Interactive Flutter transaction graph
- Pattern highlighting and transaction-path timeline
- Configurable frontend API URL
- Basic API rate limiting and short-TTL trace caching

---

## 🧭 Forensic Positioning

CryptoTrace is an **investigation aid**, not an automated identity or criminality verdict engine.

A graph path to a known VASP does **not** prove:

- wallet ownership
- wallet control
- user identity
- VASP ownership/control of the wallet
- criminal intent
- money laundering or other illegal activity

Likewise, detected patterns such as fan-in, fan-out, rapid forwarding, repeated routing, or near-threshold clustering are **indicators for investigation**, not proof of wrongdoing.

This distinction is intentionally reflected in the API models, frontend wording, scoring explanations, and exported evidence reports.

---

## 🏗️ Architecture

CryptoTrace is split into modular backend and frontend components.

### Backend

```text
backend/
├── main.py
├── cryptotrace/
│   ├── config.py
│   ├── registry.py
│   ├── models.py
│   ├── utils.py
│   ├── ingestion/
│   │   ├── etherscan.py
│   │   └── mock.py
│   ├── graph/
│   │   ├── tracer.py
│   │   ├── attribution.py
│   │   ├── scoring.py
│   │   └── patterns.py
│   ├── services/
│   │   ├── response.py
│   │   ├── case_store.py
│   │   ├── trace_cache.py
│   │   └── rate_limit.py
│   ├── reporting/
│   │   └── pdf.py
│   └── api/
│       ├── app.py
│       └── routes.py
└── tests/
```

### Frontend

```text
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   ├── services/
│   ├── screens/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│       ├── attribution/
│       ├── evidence/
│       └── graph/
└── test/
```

The modular split is intentional: ingestion, graph analysis, scoring, pattern detection, reporting, and HTTP orchestration have separate responsibilities rather than being placed in one large backend file. The Flutter application is similarly split into models, services, screens, and reusable widgets.

---

## 🔍 Investigation Workflow

1. Enter an Ethereum wallet address.
2. Select a trace depth from 1 to 3 hops.
3. CryptoTrace collects transaction candidates from Etherscan or deterministic mock data.
4. Candidates are classified, filtered, deduplicated, and prioritized.
5. Eligible transfers are added to a directed MultiDiGraph.
6. The graph is traversed within the configured hop limit.
7. The nearest registry VASP is identified and the observed path direction is reported as inbound, outbound, mixed, or unknown.
8. Confidence and risk are calculated using deterministic heuristic factors.
9. Graph-derived investigation indicators are detected.
10. Transaction-level evidence is attached to graph edges and selected path hops.
11. A case snapshot is created.
12. The user can export a forensic PDF or machine-readable Case JSON.

---

## 📊 Scoring

CryptoTrace uses a deterministic heuristic scoring model. The current implementation exposes its factors rather than presenting an unexplained percentage.

### Confidence factors

- hop distance
- direct edge context
- intermediary wallets
- VASP verification status
- mock/demo data penalty
- live API failure penalty

### Risk factors

- base heuristic risk
- intermediary wallets
- graph sparsity
- fragmented routing

The frontend and PDF expose the factor breakdown so the displayed score can be audited against the underlying arithmetic.

> These scores are heuristic indicators, not calibrated probabilities or legal determinations.

---

## 🧩 Investigation Patterns

The graph analysis can identify:

| Pattern | Meaning in CryptoTrace |
|---|---|
| **Fan-out** | One wallet sends to multiple downstream counterparties |
| **Fan-in** | Multiple upstream wallets send to one wallet |
| **Rapid forwarding** | An incoming transfer is followed by an outgoing transfer within a short time window |
| **Long routing chain** | The selected path reaches at least three hops |
| **Repeated routing** | An intermediary on the selected path has multiple inbound and outbound edges |
| **Near-threshold clustering** | Multiple transfers occur close to the configured tracing threshold in a short window |

All pattern descriptions are intentionally non-dispositive.

---

## 🧾 Evidence & Case Package

Each trace can produce a case snapshot containing:

- Case ID and creation timestamp
- Trace configuration
- Target wallet
- Graph nodes and edges
- Selected VASP path
- Observed VASP path direction
- VASP provenance
- Transaction evidence
- Confidence breakdown
- Risk breakdown
- Investigation patterns
- Trace filtering/accounting information
- Disclaimer and data-source information

### Export formats

**PDF** — human-readable forensic/evidence report.

**Case JSON** — machine-readable snapshot intended for reproducibility, downstream analysis, and integration with other systems.

Case exports use the stored case snapshot when a valid Case ID is supplied. A missing/expired Case ID is rejected rather than silently replaced with a new trace.

---

## 🌐 API

The current API includes:

```text
GET  /api/health
POST /api/trace
GET  /api/report/{wallet}
GET  /api/case/{wallet}
```

### Trace request

```json
{
  "wallet_address": "0x...",
  "max_hops": 2
}
```

The trace response contains the graph, attribution summary, analysis information, scoring breakdowns, detected patterns, provenance, and case metadata.

---

## ⚙️ Configuration

Backend configuration is environment-driven.

Copy the example file:

```powershell
copy backend\.env.example backend\.env
```

At minimum, configure the Etherscan API key for live blockchain ingestion:

```env
ETHERSCAN_API_KEY=YOUR_API_KEY_HERE
```

Do **not** commit the real `.env` file or any API secrets.

The backend also supports configuration for trace limits, rate limiting, and trace-cache TTL.

### Frontend API URL

The default frontend backend URL is:

```text
http://localhost:8000
```

For another machine or deployment target:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

---

## 🚀 Running Locally

### Backend

From the backend directory:

```powershell
python -m venv venv
venv\Scripts\activate
python -m pip install -r requirements.txt
python main.py
```

The development API runs on:

```text
http://localhost:8000
```

Health check:

```text
http://localhost:8000/api/health
```

### Frontend

From the Flutter frontend directory:

```powershell
flutter pub get
flutter analyze
flutter run
```

Make sure the backend is running and the frontend API base URL points to it.

---

## 🧪 Testing

### Backend

```powershell
python -m pytest -q
```

Current development baseline:

```text
34 passed
```

### Frontend

```powershell
flutter analyze
```

Current development baseline:

```text
No issues found!
```

The backend may report dependency deprecation warnings from Pydantic, ReportLab, or Starlette/AnyIO. These warnings are not test failures.

---

## 🛡️ Security & Prototype Boundaries

CryptoTrace is currently a local / hackathon-stage prototype.

Important boundaries:

- The API has no authentication/authorization layer.
- External API usage is protected by application-level request limiting, but public production deployment would require stronger operational controls.
- Case storage is in-memory and intended for prototype/session-level usage.
- The application should not be exposed publicly with a production API key without reviewing authentication, authorization, secret management, persistence, monitoring, and deployment controls.
- Live transaction data depends on the availability and limits of the upstream Etherscan API.

---

## 🧪 Mock / Demo Mode

CryptoTrace includes deterministic demo data so the application can be demonstrated without a live Etherscan key.

The mock dataset is designed to exercise multiple investigation paths and pattern types while remaining reproducible.

**Mock data is not real blockchain intelligence.** It must never be presented as evidence about a real wallet or real entity.

---

## 📌 Current Limits

Unless overridden through configuration, the current implementation is designed around:

- **Maximum trace depth:** 3 hops
- **Minimum native ETH transfer threshold:** 0.0005 ETH
- **Maximum graph nodes:** 100
- **Maximum live API calls per trace:** 30
- **Candidate and per-source transaction limits:** enforced by configuration

The source code is authoritative if these values change.

---

## 🧱 Development Principles

CryptoTrace intentionally prioritizes:

- explainability over opaque scoring
- evidence over assertions
- reproducible mock data
- modular architecture
- explicit data-quality states
- transparent heuristic limitations
- minimal dependencies
- deterministic behavior where possible

The project does **not** add AI/ML merely for presentation value. Future intelligent methods should be introduced only where they can be validated and explained.

---

## 🔮 Planned / Future Work

Potential future work includes:

- investigation search and graph filters
- Evidence Mode for focused case review
- frontend automated tests
- deeper ASGI/integration coverage
- persistent case storage
- stronger caching and operational controls
- broader token/asset handling
- multi-chain tracing
- richer verified VASP intelligence feeds
- entity clustering and advanced anomaly analysis

These are future directions, not claims about the current implementation.

---

## 👥 Project Context

CryptoTrace was developed as a cybersecurity / blockchain investigation project for a hackathon setting. The current codebase is intended to be understandable, testable, and demonstrable rather than production-scale infrastructure.

---

## ⚠️ Disclaimer

CryptoTrace provides heuristic blockchain-analysis results for investigative assistance and education. A graph relationship, VASP proximity, confidence score, risk score, or detected graph pattern is not proof of ownership, control, identity, criminal conduct, or illicit intent.

Investigators should independently verify conclusions using authoritative blockchain data, entity intelligence, legal/process context, and other evidence.
