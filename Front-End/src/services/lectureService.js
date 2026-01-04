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

