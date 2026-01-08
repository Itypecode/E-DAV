import api from './api'

export const getTodaysLectures = async (userId) => {
  const response = await api.get('/lectures/today', {
    params: {
      user_id: userId
    }
  })
  return response.data
}

export const getMyClasses = async (userId) => {
  const response = await api.get('/classes', {
    params: {
      user_id: userId
    }
  })
  return response.data
}

export const getAttendanceOverview = async (userId, startDate, endDate) => {
  const response = await api.get('/attendance/student/overview', {
    params: {
      user_id: userId,
      start_date: startDate,
      end_date: endDate
    }
  })
  return response.data
}

export const getStudentSubmissions = async () => {
  const response = await api.get('/student/submissions')
  return response.data
}

export const uploadSubmission = async (userId, lectureInstanceId, file) => {
  const formData = new FormData()
  formData.append('user_id', userId)
  formData.append('lecture_instance_id', lectureInstanceId)
  formData.append('file', file)

  const response = await api.post('/upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })

  return response.data
}


export const getSubmissionStatus = async (submissionId) => {
  const response = await api.get(`/submissions/${submissionId}`)
  return response.data
}

export const resolveLectureInstance = async (userId, date, hourSlot, subjectCode) => {
  const response = await api.post('/lectures/resolve', null, {
    params: {
      user_id: userId,
      date: date,
      hour_slot: hourSlot,
      subject_code: subjectCode
    }
  })
  return response.data
}

export const submitAppeal = async (userId, lectureInstanceId, reason) => {
  const response = await api.post('/attendance/appeal', null, {
    params: {
      user_id: userId,
      lecture_instance_id: lectureInstanceId,
      reason: reason
    }
  })
  return response.data
}


export const getTeacherSchedule = async (userId) => {
  const response = await api.get('/teacher/lectures/today', {
    params: { teacher_id: userId }
  })
  return response.data
}

export const getTeacherClasses = async (teacherId) => {
  const response = await api.get('/teacher/classes', {
    params: { teacher_id: teacherId }
  })
  return response.data
}

export const toggleLectureLock = async (lectureInstanceId, locked) => {
  const response = await api.post('/teacher/lecture/lock', null, {
    params: {
      lecture_instance_id: lectureInstanceId,
      locked: locked
    }
  })
  return response.data
}
export const controlLecture = async (lectureInstanceId, teacherId, action, concept = null) => {
  const response = await api.post(`/teacher/lectures/${lectureInstanceId}`, null, {
    params: {
      teacher_id: teacherId,
      action: action,
      concept: concept
    }
  })
  return response.data
}
export const getTeacherAttendanceOverview = async (teacherId, startDate, endDate) => {
  const response = await api.get('/attendance/teacher/overview', {
    params: {
      teacher_id: teacherId,
      start_date: startDate,
      end_date: endDate
    }
  })
  return response.data
}
export const getLectureAttendanceDetail = async (lectureInstanceId) => {
  const response = await api.get(`/teacher/lectures/${lectureInstanceId}/attendance`)
  return response.data
}

export const getTeacherAppeals = async (teacherId, status = "PENDING") => {
  const response = await api.get('/teacher/appeals', {
    params: {
      teacher_id: teacherId,
      status: status
    }
  })
  return response.data
}

export const resolveAppeal = async (appealId, teacherId, decision, comment = null) => {
  const response = await api.post(`/teacher/appeals/${appealId}/resolve`, null, {
    params: {
      teacher_id: teacherId,
      decision: decision,
      teacher_comment: comment
    }
  })
  return response.data
}

export const getStudentAppealData = async (lectureInstanceId, studentId) => {
  const response = await api.get('/teacher/appeals/studata', {
    params: {
      lecture_instance_id: lectureInstanceId,
      student_id: studentId
    }
  })
  return response.data
}



