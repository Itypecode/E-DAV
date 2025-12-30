# processors/submission_processor.py
from utils.aicheck_engine import detect_ai_content
from utils.ocr_engine import extract_text_from_file
from utils.embed_engine import embed_text
from supabase_client import supabase
#from core.ai_decision import AI_Decision

async def process_submission(submission_id: str):
    print(f"[PROCESSOR] Starting OCR for submission: {submission_id}")

    record = (
        supabase.table("submissions")
        .select("*")
        .eq("id", submission_id)
        .single()
        .execute()
    )

    if not record.data:
        print("[PROCESSOR] No submission found.")
        return

    image_url = record.data["image_url"]
   
    ocr_text = await extract_text_from_file(image_url)

    print("[PROCESSOR] OCR Output:", ocr_text[:80], "...")

    supabase.table("submissions").update({
        "ocr_text": ocr_text,
        "status": "ocr_done"
    }).eq("id", submission_id).execute()

    print("[PROCESSOR] OCR completed and saved.")

    print("[AI DETECTION started...]")

    ai_json = await detect_ai_content(ocr_text)
    
    print("[AI DETECTION] output:", ai_json["reason"][:20],"...")

    supabase.table("submissions").update({
        "ai_score": ai_json["ai_score"],
        "ai_confidence": ai_json["confidence"],
        "ai_reason": ai_json["reason"]
    }).eq("id", submission_id).execute()

    print("[PROCESSOR] OCR completed and saved.")

    supabase.table("submissions").update({
        "ai_status":"Done"
    }).eq("id", submission_id).execute()

    print("[AI detection] Detection completed and saved.")

    print(f"[PROCESSOR] Starting embedding for submission: {submission_id}")
    embedding_vector = await embed_text(ocr_text)
    supabase.table("submissions").update({
        "embedding": embedding_vector,
        "status": "embedding_done"
    }).eq("id", submission_id).execute()

    print("[PROCESSOR] Embedding completed and saved.")
 
    print("[PROCESSOR] Starting similarity cosine search...")

    similarity_result = supabase.rpc(
    "find_max_similarity_for_submission",
    {"p_submission_id": submission_id}
    ).execute()

    data = similarity_result.data

    if not data:
        print("[PROCESSOR] No similar submissions found.")

    match = data[0]
    supabase.table("submissions").update({
        "copied_from_submission_id": match["matched_submission_id"],
        "max_similarity": match["similarity"],
        "status": "All done"
    }).eq("id", submission_id).execute()

    print("[PROCESSOR] Similarity search completed.")

    # Trigger AI Decision
    #await AI_Decision(submission_id)

