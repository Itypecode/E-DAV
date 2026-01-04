from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from supabase_client import supabase
from supabase import create_client
from zoneinfo import ZoneInfo
from processors.submission_processor import process_submission
import uuid
from datetime import datetime, date, time, timedelta
from collections import defaultdict
import os
import jwt
from dotenv import load_dotenv

load_dotenv()

SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET")

app = FastAPI()

# Configure CORS
origins = [
    "http://localhost:5173",  # Vite dev server
    "http://localhost:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3000)

supabase_admin = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)

BUCKET_NAME = "submission"

HOUR_SLOTS = [
    (time(8, 45), time(9, 35)),   # 1
    (time(9, 40), time(10, 30)),  # 2
    (time(10, 50), time(11, 40)), # 3
    (time(11, 45), time(12, 35)), # 4
    (time(12, 40), time(13, 30)), # 5
]

def get_hour_slot(start_time: time):
    for i, (s, e) in enumerate(HOUR_SLOTS, start=1):
        if s <= start_time < e:
            return str(i)
    return None

def verify_token(authorization: str = Header(...)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    try:
        token = authorization.split(" ")[1]
        
        # If JWT secret is configured, use it for verification
        if SUPABASE_JWT_SECRET:
            try:
                payload = jwt.decode(
                    token,
                    SUPABASE_JWT_SECRET,
                    algorithms=["HS256"],
                    audience="authenticated"
                )
                return payload  # payload["sub"] = user_id
            except jwt.ExpiredSignatureError:
                raise HTTPException(status_code=401, detail="Token has expired")
            except jwt.InvalidTokenError:
                raise HTTPException(status_code=401, detail="Invalid token")
        else:
            # Fallback: Decode JWT without verification to get user ID, then verify user exists
            # This is less secure but works without JWT secret
            try:
                # Decode without verification (just to get the payload)
                unverified = jwt.decode(token, options={"verify_signature": False})
                user_id = unverified.get("sub")
                
                if not user_id:
                    raise HTTPException(status_code=401, detail="Invalid token: no user ID")
                
                # Verify user exists in Supabase
                user_check = supabase_admin.auth.admin.get_user_by_id(user_id)
                if not user_check or not user_check.user:
                    raise HTTPException(status_code=401, detail="User not found")
                
                # Check if token is expired
                exp = unverified.get("exp")
                if exp and exp < datetime.now().timestamp():
                    raise HTTPException(status_code=401, detail="Token has expired")
                
                return {"sub": user_id}
            except jwt.DecodeError:
                raise HTTPException(status_code=401, detail="Invalid token format")
            except Exception as e:
                raise HTTPException(status_code=401, detail=f"Token verification failed: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {str(e)}")


def require_student(user=Depends(verify_token)):
    profile = (
        supabase
        .table("profiles")
        .select("role")
        .eq("id", user["sub"])
        .single()
        .execute()
    )

    if not profile.data or profile.data["role"] != "student":
        raise HTTPException(status_code=403, detail="Students only")

    return user


def require_teacher(user=Depends(verify_token)):
    profile = (
        supabase
        .table("profiles")
        .select("role")
        .eq("id", user["sub"])
        .single()
        .execute()
    )

    if not profile.data or profile.data["role"] != "teacher":
        raise HTTPException(status_code=403, detail="Teachers only")

    return user
    
@app.post("/upload")
async def upload_submission(
    user_id: str = Form(...),
    lecture_instance_id: str = Form(...),
    file: UploadFile = File(...)
):
    # 1️⃣ Check lecture instance
    lecture = (
        supabase
        .table("lecture_instances")
        .select("status, attendance_locked")
        .eq("id", lecture_instance_id)
        .single()
        .execute()
    )

    if not lecture.data:
        raise HTTPException(404, "Lecture not found")

    if lecture.data["attendance_locked"] or lecture.data["status"] != "live":
        raise HTTPException(403, "Lecture is not accepting submissions")

    # 2️⃣ Check attendance placeholder
    attendance = (
        supabase
        .table("attendance_registry")
        .select("decision")
        .eq("user_id", user_id)
        .eq("lecture_instance_id", lecture_instance_id)
        .single()
        .execute()
    )

    if not attendance.data:
        raise HTTPException(403, "You are not enrolled for this lecture")

    if attendance.data["decision"] == "ABSENT":
        raise HTTPException(403, "You are marked absent for this lecture")

    # 3️⃣ Prevent duplicate submission
    existing = (
        supabase
        .table("submissions")
        .select("id")
        .eq("user_id", user_id)
        .eq("lecture_instance_id", lecture_instance_id)
        .execute()
    )

    if existing.data:
        raise HTTPException(409, "Submission already exists")

    # 4️⃣ Upload file to storage
    file_ext = file.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_ext}"
    file_bytes = await file.read()

    upload_res = supabase.storage.from_("submission").upload(
        file_name, file_bytes
    )

    if "error" in str(upload_res).lower():
        raise HTTPException(500, "File upload failed")

    public_url = supabase.storage.from_("submission").get_public_url(file_name)

    # 5️⃣ Create submission row
    record = supabase.table("submissions").insert({
        "user_id": user_id,
        "lecture_instance_id": lecture_instance_id,
        "uploaded_at": datetime.now().isoformat(),
        "image_url": public_url,
        "status": "pending"
    }).execute()

    submission_id = record.data[0]["id"]

    # 6️⃣ Mark attendance as PRESENT (AI will refine)
    supabase.table("attendance_registry").update({
        "decision": "PRESENT",
        "updated_at": "now()"
    }).eq("user_id", user_id)\
     .eq("lecture_instance_id", lecture_instance_id)\
     .execute()
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
        result = supabase.table("profiles").select("*").limit(1).execute()
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

@app.post("/auth/register")
async def register(
    username: str = Form(...),
    password: str = Form(...),
    role: str = Form(...)
):
    if role not in ["student", "teacher"]:
        raise HTTPException(status_code=400, detail="Invalid role")

    email = f"{username}@internal.app"

    auth_user = supabase_admin.auth.admin.create_user({
        "email": email,
        "password": password,
        "email_confirm": True
    })

    supabase_admin.table("profiles").insert({
        "id": auth_user.user.id,
        "username": username,
        "role": role
    }).execute()

    return {
        "status": "created",
        "username": username,
        "role": role
    }

@app.post("/auth/login")
async def login(
    username: str = Form(...),
    password: str = Form(...),
    user_type: str = Form(...)  # student | teacher
):
    if user_type not in ["student", "teacher"]:
        raise HTTPException(status_code=400, detail="Invalid user type")

    email = f"{username}@internal.app"

    # 1. Authenticate user
    try:
        auth = supabase.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id = auth.user.id
    access_token = auth.session.access_token

    # 2. Fetch role from profiles
    profile = (
        supabase
        .table("profiles")
        .select("role")
        .eq("id", user_id)
        .single()
        .execute()
    )

    if not profile.data:
        raise HTTPException(status_code=403, detail="Profile not found")

    if profile.data["role"] != user_type:
        raise HTTPException(status_code=403, detail="Role mismatch")

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": username,
        "role": profile.data["role"]
    }

@app.get("/auth/me")
def me(user=Depends(verify_token)):
    profile = (
        supabase
        .table("profiles")
        .select("*")
        .eq("id", user["sub"])
        .single()
        .execute()
    )

    return {
        "user_id": user["sub"],
        "username": profile.data["username"],
        "name": profile.data["Name"],
        "role": profile.data["role"]
    }   

@app.get("/lectures/today")
async def get_today_lectures(user_id: str):
    lectures = supabase.rpc(
        "get_today_lectures_for_student",
        {"student_id": user_id}
    ).execute()

    return {
        "date": date.today().isoformat(),
        "lectures": lectures.data
    }

@app.get("/classes")
async def get_my_classes(user_id: str):
    result = supabase.rpc(
        "get_classes_for_student",
        {"p_student_id": user_id}
    ).execute()

    return {
        "user_id": user_id,
        "classes": result.data
    }

@app.get("/attendance/student/overview")
async def attendance_student_overview(
    user_id: str,
    start_date: str,
    end_date: str
):
    rows = supabase.rpc(
        "get_attendance_rows_for_student",
        {
            "p_user_id": user_id,
            "p_start": start_date,
            "p_end": end_date
        }
    ).execute().data

    calendar_map = {}
    summary_map = defaultdict(lambda: {
        "present": 0,
        "absent": 0,
        "od": 0,
        "total": 0
    })

    for row in rows:
        date_str = row["lecture_date"]
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")

        slot = get_hour_slot(
            datetime.strptime(row["start_time"], "%H:%M:%S").time()
        )
        if not slot:
            continue

        if date_str not in calendar_map:
            calendar_map[date_str] = {
                "date": date_str,
                "day": date_obj.strftime("%a"),
                "day_order": date_obj.isoweekday(),
                "hours": {str(i): None for i in range(1, 6)}
            }

        subject_label = f'{row["subject_code"]} - {row["subject_name"]}'

        # calendar cell
        calendar_map[date_str]["hours"][slot] = {
            "subject": subject_label,
            "status": row["decision"]
        }

        # summary
        s = summary_map[subject_label]
        s["total"] += 1

        if row["decision"] == "PRESENT":
            s["present"] += 1
        elif row["decision"] == "ABSENT":
            s["absent"] += 1
        elif row["decision"] == "OD":
            s["od"] += 1

    summary = []
    for subject, s in summary_map.items():
        percentage = round(
            ((s["present"] + s["od"]) / s["total"]) * 100
        ) if s["total"] else 0

        summary.append({
            "subject": subject,
            "present": s["present"],
            "absent": s["absent"],
            "od": s["od"],
            "total": s["total"],
            "percentage": percentage
        })

    return {
        "calendar": list(calendar_map.values()),
        "summary": summary
    }
@app.get("/student/submissions")
def get_student_submissions(current_user=Depends(verify_token)):

    # 1. Get submissions
    submissions = (
        supabase
        .table("submissions")
        .select("uploaded_at, image_url, lecture_instance_id")
        .eq("user_id", current_user["sub"])
        .order("uploaded_at", desc=True)
        .execute()
    ).data

    if not submissions:
        return []

    # 2. lecture_instances
    lecture_instance_ids = list({s["lecture_instance_id"] for s in submissions})

    lecture_instances = (
        supabase
        .table("lecture_instances")
        .select("id, timetable_lecture_id")
        .in_("id", lecture_instance_ids)
        .execute()
    ).data

    li_map = {l["id"]: l["timetable_lecture_id"] for l in lecture_instances}

    # 3. timetable_lectures
    timetable_ids = list(set(li_map.values()))

    timetable_lectures = (
        supabase
        .table("timetable_lectures")
        .select("id, class_id")
        .in_("id", timetable_ids)
        .execute()
    ).data

    tl_map = {t["id"]: t["class_id"] for t in timetable_lectures}

    # 4. classes (subjects)
    class_ids = list(set(tl_map.values()))

    classes = (
        supabase
        .table("classes")
        .select("id, class_code, class_name")
        .in_("id", class_ids)
        .execute()
    ).data

    class_map = {c["id"]: c for c in classes}

    # 5. Final response
    response = []

    for s in submissions:
        li_id = s["lecture_instance_id"]
        tl_id = li_map.get(li_id)
        class_id = tl_map.get(tl_id)
        cls = class_map.get(class_id)

        if not cls:
            continue

        response.append({
            "date": s["uploaded_at"],
            "subject_code": cls["class_code"],
            "subject_name": cls["class_name"],
            "image_url": s["image_url"]
        })

    return response

