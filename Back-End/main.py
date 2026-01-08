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

origins = [
    "http://localhost:5173",  
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
    uvicorn.run(app, host="0.0.0.0", port=8000)

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

    file_ext = file.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_ext}"
    file_bytes = await file.read()

    upload_res = supabase.storage.from_("submission").upload(
        file_name, file_bytes
    )

    if "error" in str(upload_res).lower():
        raise HTTPException(500, "File upload failed")

    public_url = supabase.storage.from_("submission").get_public_url(file_name)

    record = supabase.table("submissions").insert({
        "user_id": user_id,
        "lecture_instance_id": lecture_instance_id,
        "uploaded_at": datetime.now().isoformat(),
        "image_url": public_url,
        "status": "pending"
    }).execute()

    submission_id = record.data[0]["id"]

    supabase.table("attendance_registry").update({
        "decision": "PENDING",
        "updated_at": "now()"
    }).eq("user_id", user_id)\
     .eq("lecture_instance_id", lecture_instance_id)\
     .execute()
    submission_id = record.data[0]["id"]

    await process_submission(submission_id)

    return {
        "status": "success",
        "submission_id": submission_id,
        "image_url": public_url
    }

@app.get("/test-supabase")
def test_supabase():
    try:
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
    user_type: str = Form(...) 
):
    if user_type not in ["student", "teacher"]:
        raise HTTPException(status_code=400, detail="Invalid user type")

    email = f"{username}@internal.app"

    try:
        auth = supabase.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id = auth.user.id
    access_token = auth.session.access_token

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
        "dept": profile.data["Dept"],
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

        calendar_map[date_str]["hours"][slot] = {
            "subject": subject_label,
            "status": row["decision"]
        }

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

    lecture_instance_ids = list({s["lecture_instance_id"] for s in submissions})

    lecture_instances = (
        supabase
        .table("lecture_instances")
        .select("id, timetable_lecture_id")
        .in_("id", lecture_instance_ids)
        .execute()
    ).data

    li_map = {l["id"]: l["timetable_lecture_id"] for l in lecture_instances}

    timetable_ids = list(set(li_map.values()))

    timetable_lectures = (
        supabase
        .table("timetable_lectures")
        .select("id, class_id")
        .in_("id", timetable_ids)
        .execute()
    ).data

    tl_map = {t["id"]: t["class_id"] for t in timetable_lectures}

    class_ids = list(set(tl_map.values()))

    classes = (
        supabase
        .table("classes")
        .select("id, class_code, class_name")
        .in_("id", class_ids)
        .execute()
    ).data

    class_map = {c["id"]: c for c in classes}

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

@app.post("/lectures/resolve")
async def resolve_lecture_instance_endpoint(
    user_id: str,
    date: str,
    hour_slot: int,
    subject_code: str
):

    if hour_slot < 1 or hour_slot > len(HOUR_SLOTS):
        raise HTTPException(400, "Invalid hour slot")

    slot_start, slot_end = HOUR_SLOTS[hour_slot - 1]

    result = supabase.rpc(
    "resolve_lecture_instance",
    {
        "p_user_id": user_id,
        "p_date": date,
        "p_subject_code": subject_code,
        "p_slot_start": slot_start.strftime("%H:%M:%S"),
        "p_slot_end": slot_end.strftime("%H:%M:%S"),
    }
).execute()

    if not result.data:
        raise HTTPException(404, "No matching lecture found")

    if len(result.data) > 1:
        raise HTTPException(
            409,
            "Multiple lectures found for this slot. Contact admin."
        )

    return {
        "lecture_instance_id": result.data[0]["id"]
    }

@app.post("/attendance/appeal")
async def create_attendance_appeal(
    user_id: str,
    lecture_instance_id: str,
    reason: str
):
    
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
        raise HTTPException(403, "Not enrolled for this lecture")

    if attendance.data["decision"] != "ABSENT":
        raise HTTPException(
            400,
            "Appeal allowed only for ABSENT lectures"
        )

    
    submission = (
        supabase
        .table("submissions")
        .select("image_url")
        .eq("user_id", user_id)
        .eq("lecture_instance_id", lecture_instance_id)
        .order("uploaded_at", desc=True)
        .limit(1)
        .execute()
    )

    evidence_url = None
    if submission.data:
        evidence_url = submission.data[0]["image_url"]

    
    try:
        supabase.table("attendance_appeals").insert({
            "user_id": user_id,
            "lecture_instance_id": lecture_instance_id,
            "reason": reason,
            "evidence_url": evidence_url
        }).execute()
    except Exception as e:
        # Check for duplicate key violation (Postgres code 23505)
        if "23505" in str(e):
            raise HTTPException(
                status_code=409,
                detail="You have already appealed for this lecture."
            )
        raise e

    return {
        "status": "success",
        "message": "Appeal submitted successfully",
        "evidence_used": bool(evidence_url)
    }
    
@app.get("/teacher/lectures/today")
async def teacher_lectures_today(teacher_id: str):
    result = supabase.rpc(
        "get_today_lectures_for_teacher",
        {"p_teacher_id": teacher_id}
    ).execute()

    return {
        "date": date.today().isoformat(),
        "lectures": result.data
    }

@app.post("/teacher/lectures/{lecture_instance_id}")
async def control_lecture(
    lecture_instance_id: str,
    teacher_id: str,
    action: str,
    lock_attendance: bool | None = None,
    concept: str | None = None,
):
    action = action.upper()

    if action not in ["START", "CLOSE"]:
        raise HTTPException(400, "Invalid action")

    lecture = (
        supabase
        .table("lecture_instances")
        .select(
            "status, timetable_lectures!inner(teacher_id)"
        )
        .eq("id", lecture_instance_id)
        .single()
        .execute()
    )

    if not lecture.data:
        raise HTTPException(404, "Lecture not found")

    if lecture.data["timetable_lectures"]["teacher_id"] != teacher_id:
        raise HTTPException(403, "Not authorized")

    current_status = lecture.data["status"]

    if action == "START" and current_status != "scheduled":
        raise HTTPException(400, "Lecture cannot be started")

    if action == "CLOSE" and current_status not in ["live", "scheduled"]:
        raise HTTPException(400, "Lecture cannot be closed")

    update_data = {}

    if action == "START":
        update_data["status"] = "live"
        update_data["concept"] = concept or ""

    if action == "CLOSE":
        update_data["status"] = "closed"
        update_data["attendance_locked"] = True

    supabase.table("lecture_instances") \
        .update(update_data) \
        .eq("id", lecture_instance_id) \
        .execute()

    return {
        "status": "success",
        "lecture_instance_id": lecture_instance_id,
        "new_status": update_data["status"],
        "concept": concept or ""
    }

@app.get("/attendance/teacher/overview")
async def teacher_attendance_overview(
    teacher_id: str,
    start_date: str,
    end_date: str
):
    result = supabase.rpc(
        "get_teacher_attendance_overview",
        {
            "p_teacher_id": teacher_id,
            "p_start_date": start_date,
            "p_end_date": end_date
        }
    ).execute()

    lectures = []

    for row in result.data:
        start_time = datetime.strptime(
            row["start_time"], "%H:%M:%S"
        ).time()

        lectures.append({
            "lecture_instance_id": row["lecture_instance_id"],
            "date": row["lecture_date"],
            "hour_slot": get_hour_slot(start_time),
            "subject": f'{row["class_code"]} - {row["class_name"]}',
            "present": row["present_count"],
            "absent": row["absent_count"],
            "od": row["od_count"],
            "pending": row["pending_count"],
            "total": row["total_students"]
        })

    return {"lectures": lectures}

@app.get("/teacher/classes")
async def teacher_classes(teacher_id: str):
    result = (
        supabase
        .rpc(
            "get_teacher_classes_with_students",
            {"p_teacher_id": teacher_id}
        )
        .execute()
    )

    classes_map = {}

    for row in result.data:
        class_id = row["class_id"]

        if class_id not in classes_map:
            classes_map[class_id] = {
                "class_id": class_id,
                "class_code": row["class_code"],
                "class_name": row["class_name"],
                "semester": row["semester"],
                "department": row["department"],
                "students": []
            }

        classes_map[class_id]["students"].append({
            "student_id": row["student_id"],
            "username": row["username"],
            "name": row["name"],
            "dept": row["dept"]
        })

    return {
        "classes": list(classes_map.values())
    }

@app.get("/teacher/lectures/{lecture_instance_id}/attendance")
async def lecture_attendance_detail(lecture_instance_id: str):
    result = supabase.rpc(
        "get_present_students_for_lecture",
        {"p_lecture_instance_id": lecture_instance_id}
    ).execute()

    return {
        "lecture_instance_id": lecture_instance_id,
        "students": result.data
    }

@app.get("/teacher/appeals")
async def get_teacher_appeals(
    teacher_id: str,
    status: str = "PENDING"
):
    status = status.upper()

    if status not in ["PENDING", "APPROVED", "REJECTED"]:
        raise HTTPException(400, "Invalid status")

    result = supabase.rpc(
        "get_teacher_appeals",
        {
            "p_teacher_id": teacher_id,
            "p_status": status
        }
    ).execute()

    return {
        "appeals": result.data
    }

@app.post("/teacher/appeals/{appeal_id}/resolve")
async def resolve_appeal(
    appeal_id: str,
    teacher_id: str,
    decision: str,
    teacher_comment: str | None = None
):
    decision = decision.upper()
    if decision not in ["APPROVED", "REJECTED"]:
        raise HTTPException(400, "Invalid decision")

    appeal = (
        supabase
        .table("attendance_appeals")
        .select(
            "id, user_id, lecture_instance_id, status, lecture_instances!inner(timetable_lectures!inner(teacher_id))"
        )
        .eq("id", appeal_id)
        .single()
        .execute()
    )

    if not appeal.data:
        raise HTTPException(404, "Appeal not found")

    if appeal.data["lecture_instances"]["timetable_lectures"]["teacher_id"] != teacher_id:
        raise HTTPException(403, "Not authorized")

    if appeal.data["status"] != "PENDING":
        raise HTTPException(400, "Appeal already resolved")

    supabase.table("attendance_appeals").update({
        "status": decision,
        "teacher_comment": teacher_comment,
        "resolved_at": "now()"
    }).eq("id", appeal_id).execute()

    if decision == "APPROVED":
        supabase.table("attendance_registry").update({
            "decision": "PRESENT"
        }).eq("user_id", appeal.data["user_id"]) \
         .eq("lecture_instance_id", appeal.data["lecture_instance_id"]) \
         .execute()

    return {"status": "success", "decision": decision}

