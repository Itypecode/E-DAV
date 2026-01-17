from pydantic import BaseModel
import instructor
from groq import Groq
from datetime import datetime
from dotenv import load_dotenv
import os
import database_function as db

load_dotenv()


class EvaluationResult(BaseModel):
    attendance_decision: str
    understanding_level: str
    reason: str


async def ai_decision_and_update_attendance(submission_id: str, supabase) -> dict:
    submission = db.get_submission_with_ai_results(submission_id).data

    if submission["status"] != "All done":
        raise RuntimeError("Submission processing not completed")

    # 2. Prompt
    prompt = f"""
You are an academic evaluation agent. You MUST output ONLY valid JSON.

{{
  "attendance_decision": "PRESENT | ABSENT",
  "understanding_level": "HIGH | MEDIUM | POOR",
  "reason": "Concise explanation based on the rules"
}}

OCR_TEXT: {submission['ocr_text']}
MAX_SIMILARITY: {submission['max_similarity']}
COPIED_FROM_SUBMISSION_ID: {submission['copied_from_submission_id']}
AI_SCORE: {submission['ai_score']}
AI_CONFIDENCE: {submission['ai_confidence']}
AI_REASON: {submission['ai_reason']}
CONCEPT: {submission['concept']}
"""

    # 3. LLM call
    client = instructor.from_groq(
        Groq(api_key=os.getenv("GROQ_API_KEY")),
        mode=instructor.Mode.JSON
    )

    result: EvaluationResult = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        response_model=EvaluationResult,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7
    )

    decision = result.model_dump()

    # 4. Map decision → attendance_registry fields
    attendance_payload = {
        "user_id": submission["user_id"],
        "lecture_instance_id": submission["lecture_instance_id"],
        "decision": decision["attendance_decision"],
        "reason": decision["reason"],
        "conceptual_understanding": decision["understanding_level"],
        "updated_at": datetime.utcnow().isoformat()
    }

    db.update_attendance_record(submission["user_id"], submission["lecture_instance_id"], attendance_payload)

    return decision
