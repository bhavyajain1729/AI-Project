import os
import re
import json
import shutil
import hashlib
from pathlib import Path
from typing import Dict, Any, List
from dotenv import load_dotenv
from tqdm import tqdm

from llm_client import GroqClient
from prompts import analysis_prompt

MODULES = ["DOA", "Billing", "Inventory", "Reporting", "Database", "Utilities", "Other"]
CACHE_VERSION = 1

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="latin-1", errors="ignore")

def truncate_content(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    head = text[: max_chars // 2]
    tail = text[-max_chars // 2 :]
    return f"{head}\n\n... [TRUNCATED] ...\n\n{tail}"

def sanitize_filename(name: str) -> str:
    name = name.strip().replace(" ", "_")
    name = re.sub(r"[^a-zA-Z0-9_\-\.]", "_", name)
    if not name.lower().endswith(".p"):
        name += ".p"
    return name

def extract_json(text: str) -> Dict[str, Any]:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object found")
    raw = text[start:end+1]
    return json.loads(raw)

def load_cache(cache_path: Path) -> Dict[str, Any]:
    if not cache_path.exists():
        return {"version": CACHE_VERSION, "items": {}}
    data = json.loads(cache_path.read_text())
    if data.get("version") != CACHE_VERSION:
        return {"version": CACHE_VERSION, "items": {}}
    return data

def save_cache(cache_path: Path, cache: Dict[str, Any]) -> None:
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(cache, indent=2))

def normalize_module(module: str) -> str:
    if not module:
        return "Other"
    module = module.strip()
    for m in MODULES:
        if module.lower() == m.lower():
            return m
    return "Other"

def ensure_unique_filename(dest_dir: Path, filename: str) -> str:
    base = filename
    counter = 1
    while (dest_dir / filename).exists():
        stem = Path(base).stem
        suffix = Path(base).suffix
        filename = f"{stem}_{counter}{suffix}"
        counter += 1
    return filename

def write_file_doc(doc_path: Path, analysis: Dict[str, Any], source_path: str):
    doc_path.parent.mkdir(parents=True, exist_ok=True)
    content = f"""# File Documentation

**Source file:** {source_path}

## Summary
{analysis.get("functionality", "N/A")}

## Module
{analysis.get("module", "N/A")} (confidence: {analysis.get("confidence", "N/A")})

## Procedures
- """ + "\n- ".join(analysis.get("procedures", []) or ["(none found)"]) + """

## Tables
- """ + "\n- ".join(analysis.get("tables", []) or ["(none found)"]) + """

## Entities
- """ + "\n- ".join(analysis.get("entities", []) or ["(none found)"]) + """

## Dependencies
- """ + "\n- ".join(analysis.get("dependencies", []) or ["(none found)"]) + """

## Notes
{analysis.get("notes", "")}
"""
    doc_path.write_text(content)

def build_architecture(output_dir: Path, metadata: List[Dict[str, Any]]):
    edges = set()
    for item in metadata:
        src = item["module_bucket"]
        for dst in item.get("referenced_modules", []):
            dst = normalize_module(dst)
            if dst and dst != src:
                edges.add((src, dst))

    mmd_lines = ["graph TD"]
    if not edges:
        mmd_lines.append("  A[No dependencies detected]")
    else:
        for a, b in sorted(edges):
            mmd_lines.append(f"  {a} --> {b}")

    arch_dir = output_dir / "architecture"
    arch_dir.mkdir(parents=True, exist_ok=True)
    (arch_dir / "architecture.mmd").write_text("\n".join(mmd_lines))
    (arch_dir / "architecture.txt").write_text("\n".join(mmd_lines))

def run_pipeline():
    load_dotenv()
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise SystemExit("Missing GROQ_API_KEY in .env")

    model = os.getenv("MODEL", "llama-3.1-8b-instant")
    input_dir = Path(os.getenv("INPUT_DIR", "./input"))
    output_dir = Path(os.getenv("OUTPUT_DIR", "./output"))
    rename_files = os.getenv("RENAME_FILES", "true").lower() == "true"
    max_chars = int(os.getenv("MAX_CHARS", "12000"))
    sleep_seconds = float(os.getenv("SLEEP_SECONDS", "1.0"))
    confidence_review = int(os.getenv("CONFIDENCE_REVIEW", "60"))
    confidence_unknown = int(os.getenv("CONFIDENCE_UNKNOWN", "40"))

    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    cache_path = output_dir / ".cache" / "analysis_cache.json"
    cache = load_cache(cache_path)

    client = GroqClient(api_key=api_key, model=model, sleep_seconds=sleep_seconds)

    files = list(input_dir.rglob("*.p"))
    if not files:
        print(f"No .p files found in {input_dir}")
        return

    metadata = []

    for path in tqdm(files, desc="Analyzing files"):
        raw = read_text(path)
        content = truncate_content(raw, max_chars=max_chars)
        file_hash = hashlib.sha256(raw.encode("utf-8", errors="ignore")).hexdigest()

        if file_hash in cache["items"]:
            analysis = cache["items"][file_hash]
        else:
            prompt = analysis_prompt(str(path), content, MODULES)
            response = client.generate(prompt)
            analysis = extract_json(response)
            cache["items"][file_hash] = analysis
            save_cache(cache_path, cache)

        analysis["module"] = normalize_module(analysis.get("module", "Other"))
        confidence = int(analysis.get("confidence", 0))

        if confidence < confidence_unknown:
            module_bucket = "Unknown"
        elif confidence < confidence_review:
            module_bucket = "Review"
        else:
            module_bucket = analysis["module"]

        suggested = analysis.get("suggested_filename") or path.name
        safe_name = sanitize_filename(suggested) if rename_files else path.name

        dest_dir = output_dir / module_bucket
        dest_dir.mkdir(parents=True, exist_ok=True)
        safe_name = ensure_unique_filename(dest_dir, safe_name)
        dest_path = dest_dir / safe_name

        shutil.copy2(path, dest_path)

        doc_path = output_dir / "docs" / module_bucket / f"{Path(safe_name).stem}.md"
        write_file_doc(doc_path, analysis, str(path))

        metadata.append({
            "original_path": str(path),
            "new_path": str(dest_path),
            "module": analysis["module"],
            "module_bucket": module_bucket,
            "confidence": confidence,
            "functionality": analysis.get("functionality"),
            "entities": analysis.get("entities", []),
            "procedures": analysis.get("procedures", []),
            "tables": analysis.get("tables", []),
            "dependencies": analysis.get("dependencies", []),
            "referenced_modules": analysis.get("referenced_modules", []),
            "suggested_filename": suggested
        })

    (output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
    (output_dir / "docs" / "modules.md").write_text(
        "# Module Summary\n\n" + "\n".join(
            [f"- {m}: {sum(1 for i in metadata if i['module_bucket']==m)} file(s)"
             for m in sorted(set(i["module_bucket"] for i in metadata))]
        )
    )
    build_architecture(output_dir, metadata)
    print(f"Done. Output written to: {output_dir}")

if __name__ == "__main__":
    run_pipeline()