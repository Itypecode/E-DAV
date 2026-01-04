# core/ai_decision.py
import os
from google import genai
from supabase_client import supabase

async def AI_Decision(submission_id: str):
    print(f"[AI_DECISION] Making decision for submission: {submission_id}")

    # Fetch submission data from Supabase
    record = (
        supabase.table("submissions")
        .select("*")
        .eq("id", submission_id)
        .single()
        .execute()
    )

    if not record.data:
        print("[AI_DECISION] No submission found.")
        return

    data = record.data
    ocr_text = data.get("ocr_text", "")
    ai_score = data.get("ai_score", 0)
    ai_confidence = data.get("ai_confidence", 0)
    ai_reason = data.get("ai_reason", "")
    max_similarity = data.get("max_similarity", 0)
    copied_from = data.get("copied_from_submission_id", None)

    # Build context for AI
    context = f"""
    Submission ID: {submission_id}
    OCR Text: {ocr_text[:500]}...  # Truncated for brevity
    AI Score: {ai_score}
    AI Confidence: {ai_confidence}
    AI Reason: {ai_reason}
    Max Similarity: {max_similarity}
    Copied From: {copied_from}
    """

    # Prompt for AI decision
    prompt = f"""
    Based on the following context from a submission processing system, make a decision on whether this submission should be flagged as potentially plagiarized or AI-generated.

    Context:
    {context}

    Please provide a decision: 'Flag' or 'Pass', along with a brief reason.
    """

    try:
        # Configure genai (assuming API key is set in environment)
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            print("[AI_DECISION] GOOGLE_API_KEY not set.")
            return
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        decision = response.text.strip()

        print(f"[AI_DECISION] Decision: {decision}")

        # Optionally, update the database with the decision
        supabase.table("submissions").update({
            "ai_decision": decision
        }).eq("id", submission_id).execute()

        print("[AI_DECISION] Decision saved.")

    except Exception as e:
        print(f"[AI_DECISION] Error: {e}")