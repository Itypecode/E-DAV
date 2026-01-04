import api from './api'

/**
 * Login user
 * @param {string} username - Username
 * @param {string} password - Password
 * @param {string} userType - 'student' or 'teacher'
 * @returns {Promise} API response with token
 */
export const login = async (username, password, userType) => {
  const formData = new FormData()
  formData.append('username', username)
  formData.append('password', password)
  formData.append('user_type', userType)

  try {
    const response = await api.post('/auth/login', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    })

    console.log('Login API response:', response) // Debug log
    return response.data
  } catch (error) {
    console.error('Login error:', error) // Debug log
    throw error
  }
}

/**
 * Get current user info from backend
 * @returns {Promise} User info (username, role, user_id)
 */
export const getCurrentUser = async () => {
  try {
    const response = await api.get('/auth/me')
    return response.data
  } catch (error) {
    // Token is invalid or expired
    removeToken()
    throw error
  }
}

/**
 * Verify token is valid by calling /auth/me
 * @returns {Promise<boolean>} True if token is valid
 */
export const verifyToken = async () => {
  try {
    await getCurrentUser()
    return true
  } catch (error) {
    return false
  }
}

/**
 * Store token in localStorage
 * @param {string} token - JWT token
 */
export const setToken = (token) => {
  localStorage.setItem('Token', token)
}

/**
 * Get token from localStorage
 * @returns {string|null} Token or null
 */
export const getToken = () => {
  return localStorage.getItem('Token')
}

/**
 * Remove token from localStorage
 */
export const removeToken = () => {
  localStorage.removeItem('Token')
}

/**
 * Check if user is authenticated (has token)
 * @returns {boolean} True if token exists
 */
export const isAuthenticated = () => {
  return !!getToken()
}
