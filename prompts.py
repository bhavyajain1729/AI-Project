def analysis_prompt(file_path: str, content: str, modules: list[str]) -> str:
    modules_list = ", ".join(modules)
    return f"""
You are analyzing a Progress 4GL (ABL) .p file.

Return ONLY valid JSON (no markdown, no code fences).
Use this exact schema and double quotes:

{{
  "functionality": "short summary",
  "module": "one of: {modules_list}",
  "confidence": 0-100,
  "entities": ["tables/functions/procedures"],
  "procedures": ["procedure names if any"],
  "tables": ["table names if any"],
  "dependencies": ["external systems or modules if known"],
  "referenced_modules": ["module names if it depends on other modules"],
  "suggested_filename": "short_meaningful_name.p",
  "notes": "optional"
}}

If unsure, set module="Other" and confidence below 50.

File path: {file_path}

File content:
{content}
""".strip()