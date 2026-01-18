


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE OR REPLACE FUNCTION "public"."auto_close_scheduled_lectures"() RETURNS "void"
    LANGUAGE "sql"
    AS $$
  update lecture_instances
  set
    status = 'closed',
    attendance_locked = true
  where status = 'scheduled'
    and (
      lecture_date < current_date
      or (
        lecture_date = current_date
        and end_time < current_time
      )
    );
$$;


ALTER FUNCTION "public"."auto_close_scheduled_lectures"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_attendance_on_live"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- Only when lecture actually starts
  if old.status = 'scheduled' and new.status = 'live' then
    insert into attendance_registry (
      user_id,
      lecture_instance_id,
      decision
    )
    select
      cs.student_id,
      new.id,
      'PENDING'
    from timetable_lectures tl
    join class_students cs
      on cs.class_id = tl.class_id
    where tl.id = new.timetable_lecture_id;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."create_attendance_on_live"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_lecture_instances_for_date"("p_class_id" "uuid", "p_date" "date") RETURNS TABLE("lecture_instance_id" "uuid", "timetable_lecture_id" "uuid", "lecture_date" "date", "start_time" time without time zone, "end_time" time without time zone)
    LANGUAGE "plpgsql"
    AS $$
declare
  v_day_of_week int;
begin
  -- Postgres: Sunday=0 → convert to 1–7 (Mon–Sun)
  v_day_of_week := extract(dow from p_date);
  if v_day_of_week = 0 then
    v_day_of_week := 7;
  end if;

  return query
  insert into lecture_instances (
    timetable_lecture_id,
    lecture_date,
    start_time,
    end_time
  )
  select
    tl.id,
    p_date,
    tl.start_time,
    tl.end_time
  from timetable_lectures tl
  where tl.class_id = p_class_id
    and tl.day_of_week = v_day_of_week
    and tl.is_active = true
    and not exists (
      select 1
      from lecture_instances li
      where li.timetable_lecture_id = tl.id
        and li.lecture_date = p_date
    )
  returning
    lecture_instances.id,
    lecture_instances.timetable_lecture_id,
    lecture_instances.lecture_date,
    lecture_instances.start_time,
    lecture_instances.end_time;
end;
$$;


ALTER FUNCTION "public"."create_lecture_instances_for_date"("p_class_id" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."exec_sql"("sql" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  EXECUTE sql;
END;
$$;


ALTER FUNCTION "public"."exec_sql"("sql" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_max_similarity_for_submission"("p_submission_id" "uuid") RETURNS TABLE("matched_submission_id" "uuid", "similarity" double precision)
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  with target as (
    select
      id,
      embedding,
      class_id,
      uploaded_at::date as upload_date
    from submissions
    where id = p_submission_id
      and embedding is not null
  )
  select
    s.id as matched_submission_id,
    1 - (s.embedding <=> t.embedding) as similarity
  from submissions s
  join target t
    on s.class_id = t.class_id
   and s.uploaded_at::date = t.upload_date
  where s.id != t.id
    and s.embedding is not null
  order by similarity desc
  limit 1;
$$;


ALTER FUNCTION "public"."find_max_similarity_for_submission"("p_submission_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_max_similarity_for_submission"("query_id" "uuid", "query_embedding" "public"."vector", "query_course_code" "uuid", "query_date" "date", "similarity_threshold" double precision DEFAULT 0.85) RETURNS TABLE("matched_submission_id" "uuid", "similarity" double precision)
    LANGUAGE "sql"
    AS $$
  select
    s.id,
    1 - (s.embedding <=> query_embedding) as similarity
  from submissions s
  where s.id != query_id
    and s.embedding is not null
    and s.class_id = query_course_code
    and s.uploaded_at = query_date
    and (1 - (s.embedding <=> query_embedding)) >= similarity_threshold
  order by similarity desc
  limit 1;
$$;


ALTER FUNCTION "public"."find_max_similarity_for_submission"("query_id" "uuid", "query_embedding" "public"."vector", "query_course_code" "uuid", "query_date" "date", "similarity_threshold" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_attendance_rows_for_student"("p_user_id" "uuid", "p_start" "date", "p_end" "date") RETURNS TABLE("lecture_date" "date", "start_time" time without time zone, "decision" "text", "subject_code" "text", "subject_name" "text")
    LANGUAGE "sql"
    AS $$
  select
    li.lecture_date,
    li.start_time,
    ar.decision,
    c.class_code,
    c.class_name
  from attendance_registry ar
  join lecture_instances li
    on li.id = ar.lecture_instance_id
  join timetable_lectures tl
    on tl.id = li.timetable_lecture_id
  join classes c
    on c.id = tl.class_id
  where ar.user_id = p_user_id
    and li.lecture_date between p_start and p_end
  order by li.lecture_date, li.start_time;
$$;


ALTER FUNCTION "public"."get_attendance_rows_for_student"("p_user_id" "uuid", "p_start" "date", "p_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_classes_for_student"("p_student_id" "uuid") RETURNS TABLE("class_id" "uuid", "class_code" "text", "class_name" "text", "semester" integer, "department" "text")
    LANGUAGE "sql"
    AS $$
  select
    c.id,
    c.class_code,
    c.class_name,
    c.semester,
    c.department
  from class_students cs
  join classes c
    on c.id = cs.class_id
  where cs.student_id = p_student_id
  order by c.class_code;
$$;


ALTER FUNCTION "public"."get_classes_for_student"("p_student_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_lecture_attendance_detail"("p_lecture_instance_id" "uuid") RETURNS TABLE("student_id" "uuid", "username" "text", "name" "text", "decision" "text", "reason" "text", "conceptual_understanding" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "upload_url" "text")
    LANGUAGE "sql"
    AS $$
  select
    ar.user_id,
    p.username,
    p."Name",
    ar.decision,
    ar.reason,
    ar."Conceptual_Understanding",
    ar.created_at,
    ar.updated_at,
    s.image_url
  from attendance_registry ar
  join profiles p
    on p.id = ar.user_id
  left join submissions s
    on s.user_id = ar.user_id
   and s.lecture_instance_id = ar.lecture_instance_id
  where ar.lecture_instance_id = p_lecture_instance_id
  order by p."Name";
$$;


ALTER FUNCTION "public"."get_lecture_attendance_detail"("p_lecture_instance_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_present_students_for_lecture"("p_lecture_instance_id" "uuid") RETURNS TABLE("student_id" "uuid", "username" "text", "name" "text", "decision" "text", "reason" "text", "conceptual_understanding" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "upload_url" "text")
    LANGUAGE "sql"
    AS $$
  select
    ar.user_id,
    p.username,
    p."Name",
    ar.decision,
    ar.reason,
    ar."Conceptual_Understanding",
    ar.created_at,
    ar.updated_at,
    s.image_url
  from attendance_registry ar
  join profiles p
    on p.id = ar.user_id
  left join submissions s
    on s.user_id = ar.user_id
   and s.lecture_instance_id = ar.lecture_instance_id
  where ar.lecture_instance_id = p_lecture_instance_id
  order by p."Name";
$$;


ALTER FUNCTION "public"."get_present_students_for_lecture"("p_lecture_instance_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid") RETURNS TABLE("appeal_id" "uuid", "lecture_instance_id" "uuid", "lecture_date" "date", "class_code" "text", "class_name" "text", "student_id" "uuid", "student_name" "text", "reason" "text", "evidence_url" "text", "current_decision" "text", "appeal_status" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql"
    AS $$
  select
    aa.id,
    aa.lecture_instance_id,
    li.lecture_date,
    c.class_code,
    c.class_name,
    p.id,
    p."Name",
    aa.reason,
    aa.evidence_url,
    ar.decision,
    aa.status,
    aa.created_at
  from attendance_appeals aa
  join lecture_instances li on li.id = aa.lecture_instance_id
  join timetable_lectures tl on tl.id = li.timetable_lecture_id
  join classes c on c.id = tl.class_id
  join profiles p on p.id = aa.user_id
  join attendance_registry ar
    on ar.user_id = aa.user_id
   and ar.lecture_instance_id = aa.lecture_instance_id
  where tl.teacher_id = p_teacher_id
    and aa.status = 'PENDING'
  order by aa.created_at asc;
$$;


ALTER FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid", "p_status" "text") RETURNS TABLE("appeal_id" "uuid", "lecture_instance_id" "uuid", "lecture_date" "date", "class_code" "text", "class_name" "text", "student_id" "uuid", "student_name" "text", "reason" "text", "evidence_url" "text", "current_decision" "text", "appeal_status" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql"
    AS $$select
  aa.id,
  aa.lecture_instance_id,
  li.lecture_date,
  c.class_code,
  c.class_name,
  p.id as student_id,
  p."Name",
  aa.reason,
  aa.evidence_url,
  ar.decision,
  aa.status,
  aa.created_at
from attendance_appeals aa
join lecture_instances li on li.id = aa.lecture_instance_id
join timetable_lectures tl on tl.id = li.timetable_lecture_id
join classes c on c.id = tl.class_id
join profiles p on p.id = aa.user_id
LEFT JOIN attendance_registry ar
  on ar.user_id = aa.user_id
 and ar.lecture_instance_id = aa.lecture_instance_id
where tl.teacher_id = p_teacher_id
  and aa.status = p_status
order by aa.created_at asc;$$;


ALTER FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_teacher_attendance_overview"("p_teacher_id" "uuid", "p_start_date" "date", "p_end_date" "date") RETURNS TABLE("lecture_instance_id" "uuid", "lecture_date" "date", "start_time" time without time zone, "class_code" "text", "class_name" "text", "present_count" bigint, "absent_count" bigint, "od_count" bigint, "pending_count" bigint, "total_students" bigint)
    LANGUAGE "sql"
    AS $$
  select
    li.id,
    li.lecture_date,
    li.start_time,
    c.class_code,
    c.class_name,
    count(*) filter (where ar.decision = 'PRESENT'),
    count(*) filter (where ar.decision = 'ABSENT'),
    count(*) filter (where ar.decision = 'OD'),
    count(*) filter (where ar.decision = 'PENDING'),
    count(ar.user_id)
  from lecture_instances li
  join timetable_lectures tl
    on tl.id = li.timetable_lecture_id
  join classes c
    on c.id = tl.class_id
  join attendance_registry ar
    on ar.lecture_instance_id = li.id
  where tl.teacher_id = p_teacher_id
    and li.lecture_date between p_start_date and p_end_date
  group by
    li.id,
    li.lecture_date,
    li.start_time,
    c.class_code,
    c.class_name
  order by li.lecture_date, li.start_time;
$$;


ALTER FUNCTION "public"."get_teacher_attendance_overview"("p_teacher_id" "uuid", "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_teacher_classes_with_students"("p_teacher_id" "uuid") RETURNS TABLE("class_id" "uuid", "class_code" "text", "class_name" "text", "semester" integer, "department" "text", "student_id" "uuid", "username" "text", "name" "text", "dept" "text")
    LANGUAGE "sql"
    AS $$
  select distinct on (c.id, p.id)
    c.id as class_id,
    c.class_code,
    c.class_name,
    c.semester,
    c.department,

    p.id as student_id,
    p.username,
    p."Name",
    p."Dept"

  from timetable_lectures tl
  join classes c
    on c.id = tl.class_id
  join class_students cs
    on cs.class_id = c.id
  join profiles p
    on p.id = cs.student_id

  where tl.teacher_id = p_teacher_id
    and p.role = 'student'

  order by c.id, p.id;
$$;


ALTER FUNCTION "public"."get_teacher_classes_with_students"("p_teacher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_teacher_context"("p_teacher_id" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(

    -- Classes
    'classes', COALESCE((
      SELECT json_agg(
        json_build_object(
          'class_code', c.class_code,
          'class_name', c.class_name
        )
      )
      FROM timetable_lectures tl
      JOIN classes c ON c.id = tl.class_id
      WHERE tl.teacher_id = p_teacher_id
    ), '[]'::json),

    -- Recent lectures
    'recent_lectures', COALESCE((
      SELECT json_agg(x)
      FROM (
        SELECT
          li.lecture_date,
          li.concept,
          c.class_code
        FROM lecture_instances li
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN classes c ON c.id = tl.class_id
        WHERE tl.teacher_id = p_teacher_id
        ORDER BY li.lecture_date DESC
        LIMIT 5
      ) x
    ), '[]'::json),

    -- Appeals
    'appeals', COALESCE((
      SELECT json_agg(y)
      FROM (
        SELECT
          p."Name"        AS student_name,
          aa.status,
          aa.reason,
          li.lecture_date
        FROM attendance_appeals aa
        JOIN lecture_instances li ON li.id = aa.lecture_instance_id
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN profiles p ON p.id = aa.user_id
        WHERE tl.teacher_id = p_teacher_id
        ORDER BY aa.created_at DESC
      ) y
    ), '[]'::json)

  ) INTO result;

  RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_teacher_context"("p_teacher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_today_lectures_for_student"("student_id" "uuid") RETURNS TABLE("lecture_instance_id" "uuid", "lecture_date" "date", "start_time" time without time zone, "end_time" time without time zone, "status" "text", "attendance_locked" boolean, "attendance_status" "text", "subject_name" "text", "class_code" "text")
    LANGUAGE "sql"
    AS $$
  select
    li.id,
    li.lecture_date,
    li.start_time,
    li.end_time,
    li.status,
    li.attendance_locked,
    ar.decision,
    c.class_name,
    c.class_code
  from attendance_registry ar
  join lecture_instances li
    on li.id = ar.lecture_instance_id
  join timetable_lectures tl
    on tl.id = li.timetable_lecture_id
  join classes c
    on c.id = tl.class_id
  where ar.user_id = student_id
    and li.lecture_date = current_date
  order by li.start_time;
$$;


ALTER FUNCTION "public"."get_today_lectures_for_student"("student_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_today_lectures_for_teacher"("p_teacher_id" "uuid") RETURNS TABLE("lecture_instance_id" "uuid", "lecture_date" "date", "start_time" time without time zone, "end_time" time without time zone, "status" "text", "attendance_locked" boolean, "class_code" "text", "class_name" "text", "total_students" bigint)
    LANGUAGE "sql"
    AS $$
  select
    li.id,
    li.lecture_date,
    li.start_time,
    li.end_time,
    li.status,
    li.attendance_locked,
    c.class_code,
    c.class_name,
    count(cs.student_id)
  from lecture_instances li
  join timetable_lectures tl
    on tl.id = li.timetable_lecture_id
  join classes c
    on c.id = tl.class_id
  join class_students cs
    on cs.class_id = c.id
  where tl.teacher_id = p_teacher_id
    and li.lecture_date = current_date
  group by
    li.id,
    li.lecture_date,
    li.start_time,
    li.end_time,
    li.status,
    li.attendance_locked,
    c.class_code,
    c.class_name
  order by li.start_time;
$$;


ALTER FUNCTION "public"."get_today_lectures_for_teacher"("p_teacher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_lecture_instance"("p_user_id" "uuid", "p_date" "date", "p_subject_code" "text", "p_slot_start" time without time zone, "p_slot_end" time without time zone) RETURNS TABLE("id" "uuid")
    LANGUAGE "sql"
    AS $$
  select li.id
  from lecture_instances li
  join timetable_lectures tl
    on tl.id = li.timetable_lecture_id
  join classes c
    on c.id = tl.class_id
  join class_students cs
    on cs.class_id = c.id
  where cs.student_id = p_user_id
    and li.lecture_date = p_date
    and c.class_code = p_subject_code
    and li.start_time >= p_slot_start
    and li.start_time < p_slot_end;
$$;


ALTER FUNCTION "public"."resolve_lecture_instance"("p_user_id" "uuid", "p_date" "date", "p_subject_code" "text", "p_slot_start" time without time zone, "p_slot_end" time without time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."teacher_get_context"("p_teacher_id" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(

    /* =====================
       Classes handled
       ===================== */
    'classes', COALESCE((
      SELECT json_agg(
        json_build_object(
          'class_code', c.class_code,
          'class_name', c.class_name
        )
      )
      FROM timetable_lectures tl
      JOIN classes c ON c.id = tl.class_id
      WHERE tl.teacher_id = p_teacher_id
    ), '[]'::json),

    /* =====================
       Recent lectures
       ===================== */
    'recent_lectures', COALESCE((
      SELECT json_agg(x)
      FROM (
        SELECT
          li.id AS lecture_instance_id,
          li.lecture_date,
          li.concept,
          c.class_code
        FROM lecture_instances li
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN classes c ON c.id = tl.class_id
        WHERE tl.teacher_id = p_teacher_id
        ORDER BY li.lecture_date DESC
        LIMIT 5
      ) x
    ), '[]'::json),

    /* =====================
       Attendance summary
       ===================== */
    'attendance_summary', COALESCE((
      SELECT json_agg(y)
      FROM (
        SELECT
          li.id AS lecture_instance_id,
          li.lecture_date,
          c.class_code,
          COUNT(*) FILTER (WHERE ar.decision = 'PRESENT') AS present,
          COUNT(*) FILTER (WHERE ar.decision = 'ABSENT') AS absent,
          COUNT(*) FILTER (WHERE ar.decision = 'OD') AS od
        FROM attendance_registry ar
        JOIN lecture_instances li ON li.id = ar.lecture_instance_id
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN classes c ON c.id = tl.class_id
        WHERE tl.teacher_id = p_teacher_id
        GROUP BY li.id, li.lecture_date, c.class_code
        ORDER BY li.lecture_date DESC
      ) y
    ), '[]'::json),

    /* =====================
       Submission + AI details
       ===================== */
    'submissions_summary', COALESCE((
      SELECT json_agg(z)
      FROM (
        SELECT
          s.lecture_instance_id,
          p."Name" AS student_name,
          s.max_similarity,
          s.ai_score,
          s.ai_confidence,
          s.ai_reason
        FROM submissions s
        JOIN lecture_instances li ON li.id = s.lecture_instance_id
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN profiles p ON p.id = s.user_id
        WHERE tl.teacher_id = p_teacher_id
        ORDER BY s.uploaded_at DESC
        LIMIT 20
      ) z
    ), '[]'::json),

    /* =====================
       Appeals
       ===================== */
    'appeals', COALESCE((
      SELECT json_agg(a)
      FROM (
        SELECT
          p."Name" AS student_name,
          aa.status,
          aa.reason,
          li.lecture_date
        FROM attendance_appeals aa
        JOIN lecture_instances li ON li.id = aa.lecture_instance_id
        JOIN timetable_lectures tl ON tl.id = li.timetable_lecture_id
        JOIN profiles p ON p.id = aa.user_id
        WHERE tl.teacher_id = p_teacher_id
        ORDER BY aa.created_at DESC
      ) a
    ), '[]'::json)

  ) INTO result;

  RETURN result;
END;
$$;


ALTER FUNCTION "public"."teacher_get_context"("p_teacher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_create_lecture_instance"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_today date := current_date;
  v_day_of_week int;
begin
  -- Convert Postgres DOW (Sun=0) → 1–7 (Mon–Sun)
  v_day_of_week := extract(dow from v_today);
  if v_day_of_week = 0 then
    v_day_of_week := 7;
  end if;

  -- Only create if timetable matches today
  if NEW.is_active = true and NEW.day_of_week = v_day_of_week then

    insert into lecture_instances (
      timetable_lecture_id,
      lecture_date,
      start_time,
      end_time
    )
    values (
      NEW.id,
      v_today,
      NEW.start_time,
      NEW.end_time
    )
    on conflict (timetable_lecture_id, lecture_date) do nothing;

  end if;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."trg_create_lecture_instance"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."attendance_appeals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "lecture_instance_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "evidence_url" "text",
    "status" "text" DEFAULT 'PENDING'::"text",
    "teacher_comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "resolved_at" timestamp with time zone,
    CONSTRAINT "attendance_appeals_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'APPROVED'::"text", 'REJECTED'::"text"])))
);


ALTER TABLE "public"."attendance_appeals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attendance_registry" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "lecture_instance_id" "uuid" NOT NULL,
    "decision" "text" DEFAULT 'PENDING'::"text",
    "confidence" "text",
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    "Conceptual_Understanding" "text",
    CONSTRAINT "attendance_registry_decision_check" CHECK (("decision" = ANY (ARRAY['PENDING'::"text", 'PRESENT'::"text", 'ABSENT'::"text", 'OD'::"text"])))
);


ALTER TABLE "public"."attendance_registry" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."class_students" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "class_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "enrolled_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."class_students" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."classes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "class_code" "text" NOT NULL,
    "class_name" "text" NOT NULL,
    "semester" integer NOT NULL,
    "department" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."classes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lecture_instances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "timetable_lecture_id" "uuid" NOT NULL,
    "lecture_date" "date" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "status" "text" DEFAULT 'scheduled'::"text",
    "attendance_locked" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "concept" "text",
    CONSTRAINT "lecture_instances_status_check" CHECK (("status" = ANY (ARRAY['scheduled'::"text", 'live'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."lecture_instances" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "Name" "text" DEFAULT ''::"text",
    "Dept" "text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['student'::"text", 'teacher'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "lecture_instance_id" "uuid",
    "image_url" "text",
    "uploaded_at" timestamp without time zone,
    "ocr_text" "text",
    "embedding" "public"."vector"(768),
    "status" "text" DEFAULT 'pending'::"text",
    "max_similarity" real,
    "copied_from_submission_id" "uuid",
    "ai_score" integer,
    "ai_reason" "text",
    "ai_confidence" "text",
    "ai_status" "text"
);


ALTER TABLE "public"."submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."timetable_lectures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "class_id" "uuid" NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "day_of_week" integer NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "timetable_lectures_day_of_week_check" CHECK ((("day_of_week" >= 1) AND ("day_of_week" <= 7)))
);


ALTER TABLE "public"."timetable_lectures" OWNER TO "postgres";


ALTER TABLE ONLY "public"."attendance_appeals"
    ADD CONSTRAINT "attendance_appeals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_appeals"
    ADD CONSTRAINT "attendance_appeals_user_id_lecture_instance_id_key" UNIQUE ("user_id", "lecture_instance_id");



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "attendance_registry_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "attendance_registry_user_id_lecture_instance_id_key" UNIQUE ("user_id", "lecture_instance_id");



ALTER TABLE ONLY "public"."class_students"
    ADD CONSTRAINT "class_students_class_id_student_id_key" UNIQUE ("class_id", "student_id");



ALTER TABLE ONLY "public"."class_students"
    ADD CONSTRAINT "class_students_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."classes"
    ADD CONSTRAINT "classes_class_code_key" UNIQUE ("class_code");



ALTER TABLE ONLY "public"."classes"
    ADD CONSTRAINT "classes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lecture_instances"
    ADD CONSTRAINT "lecture_instances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lecture_instances"
    ADD CONSTRAINT "lecture_instances_timetable_lecture_id_lecture_date_key" UNIQUE ("timetable_lecture_id", "lecture_date");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."timetable_lectures"
    ADD CONSTRAINT "timetable_lectures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "uniq_attendance_per_lecture" UNIQUE ("user_id", "lecture_instance_id");



ALTER TABLE ONLY "public"."timetable_lectures"
    ADD CONSTRAINT "uniq_class_day_time" UNIQUE ("class_id", "day_of_week", "start_time", "end_time");



ALTER TABLE ONLY "public"."class_students"
    ADD CONSTRAINT "uniq_class_student" UNIQUE ("class_id", "student_id");



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "uniq_submission_per_lecture" UNIQUE ("user_id", "lecture_instance_id");



ALTER TABLE ONLY "public"."lecture_instances"
    ADD CONSTRAINT "uniq_timetable_date" UNIQUE ("timetable_lecture_id", "lecture_date");



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "unique_attendance" UNIQUE ("user_id", "lecture_instance_id");



CREATE OR REPLACE TRIGGER "/do" AFTER UPDATE ON "public"."timetable_lectures" FOR EACH ROW EXECUTE FUNCTION "public"."trg_create_lecture_instance"();



CREATE OR REPLACE TRIGGER "after_timetable_lecture_insert" AFTER INSERT ON "public"."timetable_lectures" FOR EACH ROW EXECUTE FUNCTION "public"."trg_create_lecture_instance"();



CREATE OR REPLACE TRIGGER "trg_create_attendance_on_live" AFTER UPDATE OF "status" ON "public"."lecture_instances" FOR EACH ROW EXECUTE FUNCTION "public"."create_attendance_on_live"();



ALTER TABLE ONLY "public"."attendance_appeals"
    ADD CONSTRAINT "attendance_appeals_lecture_instance_id_fkey" FOREIGN KEY ("lecture_instance_id") REFERENCES "public"."lecture_instances"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "attendance_registry_lecture_instance_id_fkey" FOREIGN KEY ("lecture_instance_id") REFERENCES "public"."lecture_instances"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_registry"
    ADD CONSTRAINT "attendance_registry_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."class_students"
    ADD CONSTRAINT "class_students_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."class_students"
    ADD CONSTRAINT "class_students_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lecture_instances"
    ADD CONSTRAINT "lecture_instances_timetable_lecture_id_fkey" FOREIGN KEY ("timetable_lecture_id") REFERENCES "public"."timetable_lectures"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_lecture_instance_id_fkey" FOREIGN KEY ("lecture_instance_id") REFERENCES "public"."lecture_instances"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timetable_lectures"
    ADD CONSTRAINT "timetable_lectures_class_id_fkey" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timetable_lectures"
    ADD CONSTRAINT "timetable_lectures_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";














































































































































































GRANT ALL ON FUNCTION "public"."auto_close_scheduled_lectures"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_close_scheduled_lectures"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_close_scheduled_lectures"() TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_attendance_on_live"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_attendance_on_live"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_attendance_on_live"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_lecture_instances_for_date"("p_class_id" "uuid", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."create_lecture_instances_for_date"("p_class_id" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_lecture_instances_for_date"("p_class_id" "uuid", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("p_submission_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("p_submission_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("p_submission_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("query_id" "uuid", "query_embedding" "public"."vector", "query_course_code" "uuid", "query_date" "date", "similarity_threshold" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("query_id" "uuid", "query_embedding" "public"."vector", "query_course_code" "uuid", "query_date" "date", "similarity_threshold" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_max_similarity_for_submission"("query_id" "uuid", "query_embedding" "public"."vector", "query_course_code" "uuid", "query_date" "date", "similarity_threshold" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_attendance_rows_for_student"("p_user_id" "uuid", "p_start" "date", "p_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_attendance_rows_for_student"("p_user_id" "uuid", "p_start" "date", "p_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_attendance_rows_for_student"("p_user_id" "uuid", "p_start" "date", "p_end" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_classes_for_student"("p_student_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_classes_for_student"("p_student_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_classes_for_student"("p_student_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_lecture_attendance_detail"("p_lecture_instance_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_lecture_attendance_detail"("p_lecture_instance_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_lecture_attendance_detail"("p_lecture_instance_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_present_students_for_lecture"("p_lecture_instance_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_present_students_for_lecture"("p_lecture_instance_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_present_students_for_lecture"("p_lecture_instance_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_teacher_appeals"("p_teacher_id" "uuid", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_teacher_attendance_overview"("p_teacher_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_teacher_attendance_overview"("p_teacher_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_teacher_attendance_overview"("p_teacher_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_teacher_classes_with_students"("p_teacher_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_teacher_classes_with_students"("p_teacher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_teacher_classes_with_students"("p_teacher_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_teacher_context"("p_teacher_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_teacher_context"("p_teacher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_teacher_context"("p_teacher_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_today_lectures_for_student"("student_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_today_lectures_for_student"("student_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_today_lectures_for_student"("student_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_today_lectures_for_teacher"("p_teacher_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_today_lectures_for_teacher"("p_teacher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_today_lectures_for_teacher"("p_teacher_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_lecture_instance"("p_user_id" "uuid", "p_date" "date", "p_subject_code" "text", "p_slot_start" time without time zone, "p_slot_end" time without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_lecture_instance"("p_user_id" "uuid", "p_date" "date", "p_subject_code" "text", "p_slot_start" time without time zone, "p_slot_end" time without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_lecture_instance"("p_user_id" "uuid", "p_date" "date", "p_subject_code" "text", "p_slot_start" time without time zone, "p_slot_end" time without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."teacher_get_context"("p_teacher_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."teacher_get_context"("p_teacher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."teacher_get_context"("p_teacher_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_create_lecture_instance"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_create_lecture_instance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_create_lecture_instance"() TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";












GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";















GRANT ALL ON TABLE "public"."attendance_appeals" TO "anon";
GRANT ALL ON TABLE "public"."attendance_appeals" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_appeals" TO "service_role";



GRANT ALL ON TABLE "public"."attendance_registry" TO "anon";
GRANT ALL ON TABLE "public"."attendance_registry" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_registry" TO "service_role";



GRANT ALL ON TABLE "public"."class_students" TO "anon";
GRANT ALL ON TABLE "public"."class_students" TO "authenticated";
GRANT ALL ON TABLE "public"."class_students" TO "service_role";



GRANT ALL ON TABLE "public"."classes" TO "anon";
GRANT ALL ON TABLE "public"."classes" TO "authenticated";
GRANT ALL ON TABLE "public"."classes" TO "service_role";



GRANT ALL ON TABLE "public"."lecture_instances" TO "anon";
GRANT ALL ON TABLE "public"."lecture_instances" TO "authenticated";
GRANT ALL ON TABLE "public"."lecture_instances" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."submissions" TO "anon";
GRANT ALL ON TABLE "public"."submissions" TO "authenticated";
GRANT ALL ON TABLE "public"."submissions" TO "service_role";



GRANT ALL ON TABLE "public"."timetable_lectures" TO "anon";
GRANT ALL ON TABLE "public"."timetable_lectures" TO "authenticated";
GRANT ALL ON TABLE "public"."timetable_lectures" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































