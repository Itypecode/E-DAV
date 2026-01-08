import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { login, setToken } from '../services/authService'
import './Login.css'

const Login = () => {
  const navigate = useNavigate()
  const [userType, setUserType] = useState('student') // 'student' or 'teacher'
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    setLoading(true)

    try {
      const response = await login(username, password, userType)

      console.log('Login response:', response) // Debug log

      // Store token in localStorage
      if (response && response.access_token) {
        setToken(response.access_token)
        console.log('Token stored:', localStorage.getItem('Token')) // Debug log

        // Small delay to ensure token is stored before navigation
        setTimeout(() => {
          // Navigate to appropriate dashboard
          if (response.role === 'student') {
            navigate('/student')
          } else if (response.role === 'teacher') {
            navigate('/teacher')
          }
        }, 100)
      } else {
        setError('Login failed: No token received from server')
      }
    } catch (err) {
      // Better error handling
      if (err.message && err.message.includes('Network Error')) {
        setError('Cannot connect to server. Please make sure the backend is running on http://localhost:3000')
      } else if (err.response?.data?.detail) {
        setError(err.response.data.detail)
      } else if (err.message) {
        setError(err.message)
      } else {
        setError('Login failed. Please check your credentials and try again.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-container">
      <div className="login-card">
        {/* Logo */}
        <div className="logo-container">
          <div className="logo-circle">
            <div className="logo-design">
              <span className="logo-icon">🏛️</span>
            </div>
          </div>
          <div className="college-identity">
            <h2 className="college-name">The American College</h2>
            <div className="college-sub">
              <span className="college-location">Madurai</span>
              <span className="separator">•</span>
              <span className="college-est">Since 1881</span>
            </div>
          </div>
        </div>

        {/* Login Heading */}
        <h1 className="login-heading">LOGIN</h1>

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="login-form">
          {/* Student/Teacher Toggle Buttons */}
          <div className="user-type-buttons">
            <button
              type="button"
              className={`user-type-btn ${userType === 'student' ? 'active' : ''}`}
              onClick={() => setUserType('student')}
            >
              Student
            </button>
            <button
              type="button"
              className={`user-type-btn ${userType === 'teacher' ? 'active' : ''}`}
              onClick={() => setUserType('teacher')}
            >
              Teacher
            </button>
          </div>

          {/* Username Field */}
          <div className="input-group">
            <div className="input-icon">
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M10 10C12.7614 10 15 7.76142 15 5C15 2.23858 12.7614 0 10 0C7.23858 0 5 2.23858 5 5C5 7.76142 7.23858 10 10 10Z" fill="currentColor" />
                <path d="M10 12C5.58172 12 2 15.5817 2 20H18C18 15.5817 14.4183 12 10 12Z" fill="currentColor" />
              </svg>
            </div>
            <input
              type="text"
              placeholder="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
          </div>

          {/* Password Field */}
          <div className="input-group">
            <div className="input-icon">
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M10 0C6.68629 0 4 2.68629 4 6V8H2C0.895431 8 0 8.89543 0 10V18C0 19.1046 0.895431 20 2 20H18C19.1046 20 20 19.1046 20 18V10C20 8.89543 19.1046 8 18 8H16V6C16 2.68629 13.3137 0 10 0ZM10 2C12.2091 2 14 3.79086 14 6V8H6V6C6 3.79086 7.79086 2 10 2ZM2 10H18V18H2V10Z" fill="currentColor" />
              </svg>
            </div>
            <input
              type={showPassword ? 'text' : 'password'}
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <button
              type="button"
              className="password-toggle"
              onClick={() => setShowPassword(!showPassword)}
            >
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                {showPassword ? (
                  <path d="M10 4C5.58172 4 2 7.58172 2 12C2 16.4183 5.58172 20 10 20C14.4183 20 18 16.4183 18 12C18 7.58172 14.4183 4 10 4ZM10 6C13.3137 6 16 8.68629 16 12C16 15.3137 13.3137 18 10 18C6.68629 18 4 15.3137 4 12C4 8.68629 6.68629 6 10 6ZM10 8C8.89543 8 8 8.89543 8 10C8 11.1046 8.89543 12 10 12C11.1046 12 12 11.1046 12 10C12 8.89543 11.1046 8 10 8ZM10 9C10.5523 9 11 9.44772 11 10C11 10.5523 10.5523 11 10 11C9.44772 11 9 10.5523 9 10C9 9.44772 9.44772 9 10 9Z" fill="currentColor" />
                ) : (
                  <path d="M10 4C5.58172 4 2 7.58172 2 12C2 16.4183 5.58172 20 10 20C14.4183 20 18 16.4183 18 12C18 7.58172 14.4183 4 10 4ZM10 6C13.3137 6 16 8.68629 16 12C16 15.3137 13.3137 18 10 18C6.68629 18 4 15.3137 4 12C4 8.68629 6.68629 6 10 6Z" fill="currentColor" />
                )}
              </svg>
            </button>
          </div>

          {/* Error Message */}
          {error && (
            <div className="error-message">
              {error}
            </div>
          )}

          {/* Login Button */}
          <button
            type="submit"
            className="login-btn"
            disabled={loading}
          >
            {loading ? 'Logging in...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  )
}

export default Login


