from fastapi import FastAPI, File, UploadFile, Form
from supabase_client import supabase
from zoneinfo import ZoneInfo
from processors.submission_processor import process_submission
import uuid
import datetime

app = FastAPI()

orgins = [
    "http://localhost:3000",
]

BUCKET_NAME = "submission"

@app.post("/upload")
async def upload_submission(
    user_id: str = Form(...),
    class_id: str = Form(...),
    file: UploadFile  = File(...)
):
    # Generate unique filename
    file_ext = file.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_ext}"

    # Upload image to Supabase storage
    file_bytes = await file.read()
    upload_res = supabase.storage.from_(BUCKET_NAME).upload(
        file_name, file_bytes
    )
    print("UPLOAD RESULT:", upload_res)
    if "error" in str(upload_res).lower():
        return {"status": "error", "message": "storage upload failed"}

    public_url = supabase.storage.from_(BUCKET_NAME).get_public_url(file_name)

    # Create submissions row
    record = supabase.table("submissions").insert({
        "user_id": user_id,
        "class_id": class_id,
        "image_url": public_url,
        "uploaded_at": datetime.datetime.now(ZoneInfo("Asia/Kolkata")).isoformat(),
        "status": "pending"
    }).execute()

    submission_id = record.data[0]["id"]

    # Trigger the processing pipeline
    await process_submission(submission_id)

    return {
        "status": "success",
        "submission_id": submission_id,
        "image_url": public_url
    }

@app.get("/test-supabase")
def test_supabase():
    try:
        # Try listing tables or any simple query
        result = supabase.table("users").select("*").limit(1).execute()
        return {
            "connected": True,
            "message": "Supabase connection successful",
            "sample": result.data
        }
    except Exception as e:
        return {
            "connected": False,
            "error": str(e)
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3000)