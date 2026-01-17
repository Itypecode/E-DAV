from supabase_client import supabase
from supabase import create_client
from datetime import datetime
import os

supabase_admin = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)

# --- Student Functions ---

def get_student_lectures_today(user_id: str):
    return supabase.rpc(
        "get_today_lectures_for_student",
        {"student_id": user_id}
    ).execute()

def get_student_classes(user_id: str):
    return supabase.rpc(
        "get_classes_for_student",
        {"p_student_id": user_id}
    ).execute()

def get_student_attendance_overview(user_id: str, start_date: str, end_date: str):
    return supabase.rpc(
        "get_attendance_rows_for_student",
        {
            "p_user_id": user_id,
            "p_start": start_date,
            "p_end": end_date
        }
    ).execute()

def resolve_lecture_instance(user_id: str, date: str, subject_code: str, slot_start: str, slot_end: str):
    return supabase.rpc(
        "resolve_lecture_instance",
        {
            "p_user_id": user_id,
            "p_date": date,
            "p_subject_code": subject_code,
            "p_slot_start": slot_start,
            "p_slot_end": slot_end,
        }
    ).execute()

def get_student_submissions(user_id: str):
    return supabase.table("submissions") \
        .select("uploaded_at, image_url, lecture_instance_id") \
        .eq("user_id", user_id) \
        .order("uploaded_at", desc=True) \
        .execute()

# --- Teacher Functions ---

def get_teacher_lectures_today(teacher_id: str):
    return supabase.rpc(
        "get_today_lectures_for_teacher",
        {"p_teacher_id": teacher_id}
    ).execute()

def get_teacher_attendance_overview(teacher_id: str, start_date: str, end_date: str):
    return supabase.rpc(
        "get_teacher_attendance_overview",
        {
            "p_teacher_id": teacher_id,
            "p_start_date": start_date,
            "p_end_date": end_date
        }
    ).execute()

def get_teacher_classes_with_students(teacher_id: str):
    return supabase.rpc(
        "get_teacher_classes_with_students",
        {"p_teacher_id": teacher_id}
    ).execute()

def get_lecture_attendance_detail(lecture_instance_id: str):
    return supabase.rpc(
        "get_present_students_for_lecture",
        {"p_lecture_instance_id": lecture_instance_id}
    ).execute()

def get_teacher_appeals(teacher_id: str, status: str):
    return supabase.rpc(
        "get_teacher_appeals",
        {
            "p_teacher_id": teacher_id,
            "p_status": status
        }
    ).execute()

def get_teacher_context(teacher_id: str):
    return supabase.rpc(
        "teacher_get_context",
        {"p_teacher_id": teacher_id}
    ).execute()

# --- Profile Functions ---

def get_user_profile(user_id: str):
    return supabase.table("profiles") \
        .select("*") \
        .eq("id", user_id) \
        .single() \
        .execute()

def get_user_role(user_id: str):
    return supabase.table("profiles") \
        .select("role") \
        .eq("id", user_id) \
        .single() \
        .execute()

def create_user_profile(user_id: str, username: str, role: str):
    return supabase_admin.table("profiles").insert({
        "id": user_id,
        "username": username,
        "role": role
    }).execute()

def get_profiles_by_usernames(usernames: list):
    return supabase.table("profiles") \
        .select("id, username") \
        .in_("username", usernames) \
        .execute()

# --- Lecture & Attendance Functions ---

def get_lecture_instance(lecture_instance_id: str):
    return supabase.table("lecture_instances") \
        .select("status, attendance_locked, timetable_lectures!inner(teacher_id)") \
        .eq("id", lecture_instance_id) \
        .single() \
        .execute()

def update_lecture_instance(lecture_instance_id: str, update_data: dict):
    return supabase.table("lecture_instances") \
        .update(update_data) \
        .eq("id", lecture_instance_id) \
        .execute()

def get_attendance_record(user_id: str, lecture_instance_id: str):
    return supabase.table("attendance_registry") \
        .select("decision") \
        .eq("user_id", user_id) \
        .eq("lecture_instance_id", lecture_instance_id) \
        .single() \
        .execute()

def update_attendance_record(user_id: str, lecture_instance_id: str, update_data: dict):
    return supabase.table("attendance_registry") \
        .update(update_data) \
        .eq("user_id", user_id) \
        .eq("lecture_instance_id", lecture_instance_id) \
        .execute()

def update_attendance_bulk(lecture_instance_id: str, user_ids: list, update_data: dict):
    return supabase.table("attendance_registry") \
        .update(update_data) \
        .eq("lecture_instance_id", lecture_instance_id) \
        .in_("user_id", user_ids) \
        .execute()

# --- Submission Functions ---

def get_submission(submission_id: str):
    return supabase.table("submissions") \
        .select("*") \
        .eq("id", submission_id) \
        .single() \
        .execute()

def get_existing_submission(user_id: str, lecture_instance_id: str):
    return supabase.table("submissions") \
        .select("id") \
        .eq("user_id", user_id) \
        .eq("lecture_instance_id", lecture_instance_id) \
        .execute()

def create_submission(data: dict):
    return supabase.table("submissions").insert(data).execute()

def update_submission(submission_id: str, update_data: dict):
    return supabase.table("submissions") \
        .update(update_data) \
        .eq("id", submission_id) \
        .execute()

def get_submission_with_ai_results(submission_id: str):
    return supabase.table("submissions") \
        .select("id, user_id, lecture_instance_id, ocr_text, max_similarity, copied_from_submission_id, ai_score, ai_confidence, ai_reason, status, concept") \
        .eq("id", submission_id) \
        .single() \
        .execute()

def find_max_similarity(submission_id: str):
    return supabase.rpc(
        "find_max_similarity_for_submission",
        {"p_submission_id": submission_id}
    ).execute()

def get_student_submission_for_appeal(user_id: str, lecture_instance_id: str):
    return supabase.table("submissions") \
        .select("image_url, max_similarity, copied_from_submission_id, ai_score, ai_reason, ai_confidence") \
        .eq("lecture_instance_id", lecture_instance_id) \
        .eq("user_id", user_id) \
        .order("uploaded_at", desc=True) \
        .limit(1) \
        .execute()

# --- Appeal Functions ---

def create_appeal(data: dict):
    return supabase.table("attendance_appeals").insert(data).execute()

def get_appeal_with_lecture_info(appeal_id: str):
    return supabase.table("attendance_appeals") \
        .select("id, user_id, lecture_instance_id, status, lecture_instances!inner(timetable_lectures!inner(teacher_id))") \
        .eq("id", appeal_id) \
        .single() \
        .execute()

def update_appeal(appeal_id: str, update_data: dict):
    return supabase.table("attendance_appeals") \
        .update(update_data) \
        .eq("id", appeal_id) \
        .execute()

# --- Utils ---

def execute_force_lecture_creation():
    return supabase_admin.rpc("exec_sql", {
        "sql": "UPDATE timetable_lectures SET is_active = true WHERE is_active = true;"
    }).execute()

def get_lecture_instances_by_ids(lecture_instance_ids: list):
    return supabase.table("lecture_instances") \
        .select("id, timetable_lecture_id") \
        .in_("id", lecture_instance_ids) \
        .execute()

def get_timetable_lectures_by_ids(timetable_ids: list):
    return supabase.table("timetable_lectures") \
        .select("id, class_id") \
        .in_("id", timetable_ids) \
        .execute()

def get_classes_by_ids(class_ids: list):
    return supabase.table("classes") \
        .select("id, class_code, class_name") \
        .in_("id", class_ids) \
        .execute()
