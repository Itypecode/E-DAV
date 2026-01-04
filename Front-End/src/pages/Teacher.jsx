import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getCurrentUser, removeToken } from '../services/authService'
import LoadingScreen from '../components/LoadingScreen'
import './Teacher.css'

const Teacher = () => {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const user = await getCurrentUser()
        // Verify user is actually a teacher
        if (user.role !== 'teacher') {
          removeToken()
          navigate('/')
          return
        }
        setName(user.name || user.username)
      } catch (error) {
        removeToken()
        navigate('/')
      } finally {
        setLoading(false)
      }
    }

    fetchUser()
  }, [navigate])

  const handleLogout = () => {
    removeToken()
    navigate('/')
  }

  if (loading) {
    return <LoadingScreen message="Initialising Instructor Console..." />
  }

  return (
    <div className="teacher-dashboard">
      <header className="dashboard-header">
        <div className="header-content">
          <h1>Teacher Dashboard</h1>
          <button onClick={handleLogout} className="logout-btn">
            Logout
          </button>
        </div>
      </header>

      <main className="dashboard-main">
        <div className="dashboard-container">
          <div className="welcome-section">
            <h2>Welcome, {name}!</h2>
            <p>This is your teacher dashboard. Manage classes, view submissions, and grade assignments here.</p>
          </div>

          <div className="dashboard-content">
            <div className="content-card">
              <h3>Submissions</h3>
              <p>Review and grade student submissions.</p>
            </div>

            <div className="content-card">
              <h3>Classes</h3>
              <p>Manage your classes and students.</p>
            </div>

            <div className="content-card">
              <h3>Analytics</h3>
              <p>View class performance and statistics.</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

export default Teacher
