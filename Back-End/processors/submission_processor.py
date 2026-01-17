# processors/submission_processor.py
from utils.aicheck_engine import detect_ai_content
from utils.ocr_engine import extract_text_from_file
from utils.embed_engine import embed_text
from supabase_client import supabase
import database_function as db
from core.ai_decision import ai_decision_and_update_attendance

async def process_submission(submission_id: str):
    print(f"[PROCESSOR] Starting OCR for submission: {submission_id}")

    record = db.get_submission(submission_id)

    if not record.data:
        print("[PROCESSOR] No submission found.")
        return

    image_url = record.data["image_url"]
   
    ocr_text = await extract_text_from_file(image_url)

    print("[PROCESSOR] OCR Output:", ocr_text[:80], "...")

    db.update_submission(submission_id, {
        "ocr_text": ocr_text,
        "status": "ocr_done"
    })

    print("[PROCESSOR] OCR completed and saved.")

    print("[AI DETECTION started...]")

    ai_json = await detect_ai_content(ocr_text)
    
    print("[AI DETECTION] output:", ai_json["reason"][:20],"...")

    db.update_submission(submission_id, {
        "ai_score": ai_json["ai_score"],
        "ai_confidence": ai_json["confidence"],
        "ai_reason": ai_json["reason"]
    })

    print("[PROCESSOR] OCR completed and saved.")

    db.update_submission(submission_id, {
        "ai_status":"Done"
    })

    print("[AI detection] Detection completed and saved.")

    print(f"[PROCESSOR] Starting embedding for submission: {submission_id}")
    embedding_vector = await embed_text(ocr_text)
    
    db.update_submission(submission_id, {
        "embedding": embedding_vector,
        "status": "embedding_done"
    })

    print("[PROCESSOR] Embedding completed and saved.")
 
    print("[PROCESSOR] Starting similarity cosine search...")

    similarity_result = db.find_max_similarity(submission_id)

    data = similarity_result.data

    if not data:
        print("[PROCESSOR] No similar submissions found.")

    match = data[0]
    db.update_submission(submission_id, {
        "copied_from_submission_id": match["matched_submission_id"],
        "max_similarity": match["similarity"],
        "status": "All done"
    })

    print("[PROCESSOR] Similarity search completed.")

    # Trigger AI Decision
    await ai_decision_and_update_attendance(submission_id, supabase)
