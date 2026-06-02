# Progress ABL (.p) File Analyzer (Gemini)

## Quick Start

```bash
python -m venv venv
source venv/bin/activate   # Windows: .\venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# edit .env and set GEMINI_API_KEY
python main.py
```

## Input
Place your .p files in:
```
./input
```

## Output
The system creates:
```
./output
├── Billing/
├── Inventory/
├── Reporting/
├── Database/
├── Utilities/
├── DOA/
├── Review/
├── Unknown/
├── docs/
├── metadata.json
└── architecture/
```

## Notes
- The app reads `GEMINI_API_KEY` from `.env`.
- `MODEL` defaults to `gemini-2.0-flash`.
- If classification confidence is low, files go to `Review/` or `Unknown/`.