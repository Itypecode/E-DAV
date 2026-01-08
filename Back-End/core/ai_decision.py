from pydantic import BaseModel
import instructor
from groq import Groq
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()


class EvaluationResult(BaseModel):
    attendance_decision: str
    understanding_level: str
    reason: str


async def ai_decision_and_update_attendance(submission_id: str, supabase) -> dict:
    # 1. Fetch submission context
    submission = (
        supabase.table("submissions")
        .select(
            "id",
            "user_id",
            "lecture_instance_id",
            "ocr_text",
            "max_similarity",
            "copied_from_submission_id",
            "ai_score",
            "ai_confidence",
            "ai_reason",
            "status",
            "concept"
        )
        .eq("id", submission_id)
        .single()
        .execute()
        .data
    )

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

    # 5. Update attendance_registry
    supabase.table("attendance_registry") \
        .update(attendance_payload) \
        .eq("user_id", submission["user_id"]) \
        .eq("lecture_instance_id", submission["lecture_instance_id"]) \
        .execute()

    return decision
