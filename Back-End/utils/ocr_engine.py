# utils/ocr_engine.py
import os
import asyncio
from google import genai
import requests
from utils.ocr_engine_failsafe import ocr_extractor
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai import errors as gnai_errors


gemini_key = str(os.getenv("GEMINI_API_KEY"))
client = genai.Client(api_key = gemini_key)

prompt_ocr = """You are performing OCR and transcription ONLY.

CRITICAL RULES:
- Do NOT rewrite, paraphrase, summarize, or correct the text.
- Do NOT normalize grammar, spelling, or punctuation.
- Do NOT merge or split sentences.
- Do NOT remove redundancy or repeated lines.
- Do NOT infer missing words.
- Do NOT improve clarity or flow.

Preservation requirements:
- Preserve original line breaks, spacing, and paragraph structure.
- Preserve bullet points, numbering, and headings exactly as they appear.
- Preserve spelling mistakes, grammatical errors, and inconsistencies.
- Preserve duplicated phrases or sentences verbatim.
- Preserve capitalization and unusual formatting.

If text is unclear or ambiguous:
- Transcribe the closest visible characters.
- Use [UNCLEAR] only when characters cannot be read.

Output format:
- Plain text only.
- No commentary, no explanations, no corrections.

Goal:
Produce a faithful transcription that maximally preserves original authorship signals and entropy."""

def _extract_sync(file_url: str) -> str:
    try:
        image_bytes = requests.get(file_url).content
        image = types.Part.from_bytes(
            data=image_bytes, mime_type="image/jpeg"
        )

        responses = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[prompt_ocr, image],
        )


        return responses.text.strip() if responses and responses.text else ""

    except Exception as e:
        print(f"[OCR ERROR] An error occurred: {e}")
        print("[OCR PROCESSOR] Initiating another model call...")
        return ocr_extractor(file_url)



async def extract_text_from_file(file_url: str) -> str:
    return await asyncio.to_thread(_extract_sync, file_url)
