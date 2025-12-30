from groq import Groq
import os
from dotenv import load_dotenv

load_dotenv()   
keys = os.getenv("GROQ_API_KEY")
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
Produce a faithful transcription that maximally preserves original authorship signals and entropy.
"""
def ocr_extractor(file_url: str) -> str:
    try:
        client = Groq(api_key = keys)
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-maverick-17b-128e-instruct",
            messages=[
                {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": prompt_ocr
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": file_url
                        }
                    }
                ]
            }
        ],
        temperature=0.1,
        max_completion_tokens=1024,
        top_p=1,
        stream=False,
        stop=None,
        )
        return str(completion.choices[0].message.content)
    except Exception as e:
        print("[OCR ERROR]", e)
        return ""