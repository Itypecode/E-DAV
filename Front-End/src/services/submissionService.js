import api from './api'

/**
 * Upload a submission file
 * @param {string} userId - User ID
 * @param {string} classId - Class ID
 * @param {File} file - File to upload
 * @returns {Promise} API response
 */
export const uploadSubmission = async (userId, classId, file) => {
  const formData = new FormData()
  formData.append('user_id', userId)
  formData.append('class_id', classId)
  formData.append('file', file)

  const response = await api.post('/upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })

  return response.data
}

/**
 * Test Supabase connection
 * @returns {Promise} API response
 */
export const testSupabase = async () => {
  const response = await api.get('/test-supabase')
  return response.data
}

