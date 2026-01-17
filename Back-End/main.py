from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends, Header, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from supabase_client import supabase as supabase_client_obj
from supabase import create_client
from zoneinfo import ZoneInfo
from pydantic import BaseModel
from typing import List
from processors.submission_processor import process_submission
import database_function as db
import uuid
from datetime import datetime, date, time, timedelta
from collections import defaultdict
import os
import jwt
from dotenv import load_dotenv
from chatbot import chat    

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
    profile = db.get_user_role(user["sub"])

    if not profile.data or profile.data["role"] != "student":
        raise HTTPException(status_code=403, detail="Students only")

    return user


def require_teacher(user=Depends(verify_token)):
    profile = db.get_user_role(user["sub"])

    if not profile.data or profile.data["role"] != "teacher":
        raise HTTPException(status_code=403, detail="Teachers only")

    return user
    
@app.post("/upload")
async def upload_submission(
    user_id: str = Form(...),
    lecture_instance_id: str = Form(...),
    file: UploadFile = File(...)
):
    lecture = db.get_lecture_instance(lecture_instance_id)

    if not lecture.data:
        raise HTTPException(404, "Lecture not found")

    if lecture.data["attendance_locked"] or lecture.data["status"] != "live":
        raise HTTPException(403, "Lecture is not accepting submissions")

    attendance = supabase_client_obj.table("attendance_registry").select("decision").eq("user_id", user_id).eq("lecture_instance_id", lecture_instance_id).single().execute()

    if not attendance.data:
        raise HTTPException(403, "You are not enrolled for this lecture")

    if attendance.data["decision"] == "ABSENT":
        raise HTTPException(403, "You are marked absent for this lecture")

    existing = db.get_existing_submission(user_id, lecture_instance_id)

    if existing.data:
        raise HTTPException(409, "Submission already exists")

    file_ext = file.filename.split(".")[-1]
    file_name = f"{uuid.uuid4()}.{file_ext}"
    file_bytes = await file.read()

    upload_res = supabase_client_obj.storage.from_("submission").upload(
        file_name, file_bytes
    )

    if "error" in str(upload_res).lower():
        raise HTTPException(500, "File upload failed")

    public_url = supabase_client_obj.storage.from_("submission").get_public_url(file_name)

    record = db.create_submission({
        "user_id": user_id,
        "lecture_instance_id": lecture_instance_id,
        "uploaded_at": datetime.now().isoformat(),
        "image_url": public_url,
        "status": "pending"
    })

    submission_id = record.data[0]["id"]

    db.update_attendance_record(user_id, lecture_instance_id, {
        "decision": "PENDING",
        "updated_at": "now()"
    })
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
        # Using a simple query to test connection
        result = db.get_user_profile(None) # This will fail but it's just a test
        # Better test:
        result = db.get_user_profile("00000000-0000-0000-0000-000000000000") # Dummy UUID
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

    db.create_user_profile(auth_user.user.id, username, role)

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
        auth = supabase_client_obj.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
    except Exception as e:
        print(f"Login failed for {email}: {str(e)}")
        # If it's a supabase error, it might have more details
        raise HTTPException(status_code=401, detail=f"Invalid credentials: {str(e)}")

    user_id = auth.user.id
    access_token = auth.session.access_token

    profile = db.get_user_role(user_id)

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
    profile = db.get_user_profile(user["sub"])

    return {
        "user_id": user["sub"],
        "username": profile.data["username"],
        "dept": profile.data["Dept"],
        "name": profile.data["Name"],
        "role": profile.data["role"]
    }   

@app.get("/lectures/today")
async def get_today_lectures(user_id: str):
    lectures = db.get_student_lectures_today(user_id)

    return {
        "date": date.today().isoformat(),
        "lectures": lectures.data
    }

@app.get("/classes")
async def get_my_classes(user_id: str):
    result = db.get_student_classes(user_id)

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
    rows = db.get_student_attendance_overview(user_id, start_date, end_date).data

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

    submissions = db.get_student_submissions(current_user["sub"]).data

    if not submissions:
        return []

    lecture_instance_ids = list({s["lecture_instance_id"] for s in submissions})

    lecture_instances = db.get_lecture_instances_by_ids(lecture_instance_ids).data

    li_map = {l["id"]: l["timetable_lecture_id"] for l in lecture_instances}

    timetable_ids = list(set(li_map.values()))

    timetable_lectures = db.get_timetable_lectures_by_ids(timetable_ids).data

    tl_map = {t["id"]: t["class_id"] for t in timetable_lectures}

    class_ids = list(set(tl_map.values()))

    classes = db.get_classes_by_ids(class_ids).data

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

    result = db.resolve_lecture_instance(
        user_id,
        date,
        subject_code,
        slot_start.strftime("%H:%M:%S"),
        slot_end.strftime("%H:%M:%S")
    )

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
    
    attendance = db.get_attendance_record(user_id, lecture_instance_id)

    if not attendance.data:
        raise HTTPException(403, "Not enrolled for this lecture")

    if attendance.data["decision"] != "ABSENT":
        raise HTTPException(
            400,
            "Appeal allowed only for ABSENT lectures"
        )

    
    submission = db.get_student_submission_for_appeal(user_id, lecture_instance_id)

    evidence_url = None
    if submission.data:
        evidence_url = submission.data[0]["image_url"]

    
    try:
        db.create_appeal({
            "user_id": user_id,
            "lecture_instance_id": lecture_instance_id,
            "reason": reason,
            "evidence_url": evidence_url
        })
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
    result = db.get_teacher_lectures_today(teacher_id)

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

    lecture = db.get_lecture_instance(lecture_instance_id)

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

    db.update_lecture_instance(lecture_instance_id, update_data)

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
    result = db.get_teacher_attendance_overview(teacher_id, start_date, end_date)

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
    result = db.get_teacher_classes_with_students(teacher_id)

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
    result = db.get_lecture_attendance_detail(lecture_instance_id)

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

    result = db.get_teacher_appeals(teacher_id, status)

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

    appeal = db.get_appeal_with_lecture_info(appeal_id)

    if not appeal.data:
        raise HTTPException(404, "Appeal not found")

    if appeal.data["lecture_instances"]["timetable_lectures"]["teacher_id"] != teacher_id:
        raise HTTPException(403, "Not authorized")

    if appeal.data["status"] != "PENDING":
        raise HTTPException(400, "Appeal already resolved")

    db.update_appeal(appeal_id, {
        "status": decision,
        "teacher_comment": teacher_comment,
        "resolved_at": "now()"
    })

    if decision == "APPROVED":
        db.update_attendance_record(appeal.data["user_id"], appeal.data["lecture_instance_id"], {
            "decision": "PRESENT"
        })

    return {"status": "success", "decision": decision}

@app.get("/do")
async def force_create_today_lectures():
    db.execute_force_lecture_creation()

    return {
        "status": "ok",
        "message": "Trigger fired. Lecture instances created if applicable."
    }

@app.get("/teacher/appeals/studata")
async def get_student_appeal_data(
    lecture_instance_id: str,
    student_id: str
):
    response = db.get_student_submission_for_appeal(student_id, lecture_instance_id)

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="No submission found for this student and lecture"
        )

    return response.data[0]

class MarkAbsentRequest(BaseModel):
    lecture_instance_id: str
    students_username: List[str]

@app.post("/teacher/attendance/mark-absent")
async def mark_students_absent(payload: MarkAbsentRequest):
    if not payload.students_username:
        raise HTTPException(
            status_code=400,
            detail="students_username cannot be empty"
        )

    try:
        profiles_res = db.get_profiles_by_usernames(payload.students_username)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    if not profiles_res.data:
        raise HTTPException(
            status_code=404,
            detail="No matching students found"
        )

    username_to_id = {p["username"]: p["id"] for p in profiles_res.data}
    user_ids = list(username_to_id.values())

    try:
        attendance_res = db.update_attendance_bulk(payload.lecture_instance_id, user_ids, {
            "decision": "ABSENT",
            "updated_at": datetime.utcnow().isoformat()
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    not_found_usernames = list(
        set(payload.students_username) - set(username_to_id.keys())
    )

    return {
        "success": True,
        "lecture_instance_id": payload.lecture_instance_id,
        "marked_absent": list(username_to_id.keys()),
        "usernames_not_found": not_found_usernames,
        "updated_rows": len(attendance_res.data)
    }

@app.post("/teacher/chat")
async def teacher_chat(
    teacher_id: str,
    message: str
):
    ctx = db.get_teacher_context(teacher_id)

    if not ctx.data:
        raise HTTPException(500, "Context fetch failed")

    teacher_context = dict(ctx.data)

    response = await chat(
        teacher_context,
        message
    )

    return {"reply": response}

