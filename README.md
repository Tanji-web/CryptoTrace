# CryptoTrace — VASP Attribution Portal

**CryptoTrace** is a prototype Ethereum wallet tracing and VASP (Virtual Asset Service Provider) attribution application[cite: 1]. It inspects blockchain transaction activity, constructs a multi-asset transaction graph, traces wallet relationships up to 3 hops, identifies the nearest known VASP in its registry, and calculates heuristic risk/confidence indicators[cite: 1].

---

## Important System Context & Limitations

* **Heuristic Attribution Only:** Graph proximity to a known VASP is an investigative lead, **not** proof of wallet ownership, identity, or legal attribution[cite: 1].
* **Heuristic Scoring:** Confidence and Risk values are heuristic indicators derived from graph properties, not statistical probabilities[cite: 1].
* **Prototype Scope:** Designed for demonstration, analytical visualization, and judge/investigator presentation[cite: 1].

---

## Application Architecture

The system operates across five clear execution layers[cite: 1]:

1. **Input Layer:** Accepts target Ethereum address and hop depth ($1$–$3$)[cite: 1].
2. **Data Layer:** Fetches native ETH, internal ETH transfers, and ERC-20 token events via Etherscan V2 API[cite: 1].
3. **Analysis Layer:** Applies economic qualification rules ($\ge 0.0005\text{ ETH}$ threshold), reclassifies zero-value contract interactions, prioritizes candidates, and deduplicates transactions[cite: 1].
4. **Attribution Layer:** Traverses a NetworkX `MultiDiGraph` to locate the nearest reachable VASP using shortest-path analysis and derives explainable heuristic scores[cite: 1].
5. **Presentation Layer:** Interactive Flutter Web/Desktop dashboard with graph zoom/pan, node inspection, metrics breakdown, and forensic ReportLab PDF export[cite: 1].

---

## Data Qualification Rules

* **Economic Threshold:** Direct transfer limit of **`0.0005 ETH`**[cite: 1].
  * Native & Internal ETH transfers $\ge 0.0005\text{ ETH}$ are included[cite: 1].
  * Native & Internal ETH transfers $< 0.0005\text{ ETH}$ are filtered out[cite: 1].
* **ERC-20 Token Transfers:** Preserved as metadata for token interaction context; they do not participate in the direct ETH valuation threshold[cite: 1].
* **Zero-Value Transactions:** $0\text{ ETH}$ transfers are classified as non-economic contract calls rather than financial transfers[cite: 1].

---

## Tech Stack

* **Backend:** Python 3, FastAPI, Pydantic, NetworkX, HTTPX, ReportLab[cite: 1]
* **Frontend:** Flutter, Dart, CustomPaint, InteractiveViewer[cite: 1]
* **Data Provider:** Etherscan V2 API (Mainnet, Chain ID 1)[cite: 1]

---

## Local Development Setup

### 1. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
# Create a .env file with your Etherscan key:
# ETHERSCAN_API_KEY=your_etherscan_api_key

# Run FastAPI backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000

```

### 2. Frontend Setup

```bash
cd frontend

# Get Flutter dependencies
flutter pub get

# Run Flutter Web / Desktop application
flutter run -d chrome

```

---

## API Endpoints

* `GET /api/health` — Backend status and API configuration health check.


* `POST /api/trace` — Dispatches wallet tracing, graph building, and heuristic attribution.


* `GET /api/report/{wallet}?max_hops={n}` — Generates and downloads the forensic evidence PDF report.



---

## License & References

Distributed under the Open Source MIT License. Built using standard protocols and open tools:

* [Ethereum Protocol](https://ethereum.org/)

* [Etherscan V2 API](https://docs.etherscan.io/)

* [NetworkX Graph Analytics Engine](https://networkx.org/)

* [Flutter Framework](https://flutter.dev/)

* [FastAPI](https://fastapi.tiangolo.com/)
