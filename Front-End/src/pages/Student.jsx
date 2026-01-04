import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getCurrentUser, removeToken, getToken } from '../services/authService'
import { getTodaysLectures, uploadSubmission, getMyClasses } from '../services/lectureService'
import Sidebar from '../components/Sidebar'
import LoadingScreen from '../components/LoadingScreen'
import './Student.css'

const Student = () => {
  const navigate = useNavigate()
  const [user, setUser] = useState(null)
  const [lectures, setLectures] = useState([])
  const [classes, setClasses] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [uploading, setUploading] = useState({})

  useEffect(() => {
    const init = async () => {
      const token = getToken()
      if (!token) {
        navigate('/')
        return
      }

      try {
        const userData = await getCurrentUser()
        if (userData.role !== 'student') {
          removeToken()
          navigate('/')
          return
        }
        setUser(userData)

        // Fetch both lectures and classes
        const [lecturesData, classesData] = await Promise.all([
          getTodaysLectures(userData.user_id),
          getMyClasses(userData.user_id)
        ])

        // Map backend response for lectures
        let mappedLectures = []
        if (lecturesData?.lectures && Array.isArray(lecturesData.lectures)) {
          mappedLectures = lecturesData.lectures.map(lecture => ({
            id: lecture.lecture_instance_id,
            class_id: null,
            class_name: lecture.class_code || 'Unknown',
            subject_name: lecture.subject_name || 'Unknown',
            lecture_time: lecture.start_time && lecture.end_time
              ? `${lecture.start_time} - ${lecture.end_time}`
              : 'Time TBD',
            attendance_status: lecture.attendance_status || 'PENDING',
            finalized: lecture.attendance_locked || false,
            submission_id: null,
            submission: null
          }))
        }

        setLectures(mappedLectures)
        setClasses(classesData?.classes || [])
      } catch (err) {
        if (err.response?.status === 401) {
          removeToken()
          navigate('/')
        } else {
          setError(err.message || 'Failed to load data')
        }
      } finally {
        setLoading(false)
      }
    }

    init()
  }, [navigate])

  const handleLogout = () => {
    removeToken()
    navigate('/')
  }

  const handleFileUpload = async (lectureId, event) => {
    const file = event.target.files[0]
    if (!file) return

    setUploading({ ...uploading, [lectureId]: true })
    try {
      await uploadSubmission(user.user_id, lectureId, file)
      const updatedLectures = await getTodaysLectures(user.user_id)

      // Map again or just refresh the whole state
      let mappedLectures = []
      if (updatedLectures?.lectures && Array.isArray(updatedLectures.lectures)) {
        mappedLectures = updatedLectures.lectures.map(lecture => ({
          id: lecture.lecture_instance_id,
          class_id: null,
          class_name: lecture.class_code || 'Unknown',
          subject_name: lecture.subject_name || 'Unknown',
          lecture_time: lecture.start_time && lecture.end_time
            ? `${lecture.start_time} - ${lecture.end_time}`
            : 'Time TBD',
          attendance_status: lecture.attendance_status || 'PENDING',
          finalized: lecture.attendance_locked || false,
          submission_id: null,
          submission: null
        }))
      }
      setLectures(mappedLectures)
      setError(null)
    } catch (err) {
      setError(err.response?.data?.detail || err.response?.data?.message || 'Upload failed')
    } finally {
      setUploading({ ...uploading, [lectureId]: false })
      event.target.value = ''
    }
  }

  if (loading) {
    return <LoadingScreen message="Syncing your academic records and dashboard..." />
  }

  if (error && !user) {
    return (
      <div className="error-container">
        <p>{error}</p>
        <button onClick={() => navigate('/')}>Go to Login</button>
      </div>
    )
  }

  return (
    <div className="student-dashboard">
      <Sidebar />
      <div className="main-content-wrapper">
        <header className="dashboard-header">
          <div className="header-content">
            <h1>Student Dashboard</h1>
            <div className="header-right">
              <span className="username">Welcome, {user?.name || user?.username}</span>
              <button onClick={handleLogout} className="logout-btn">
                Logout
              </button>
            </div>
          </div>
        </header>

        <main className="dashboard-main">
          <div className="dashboard-container">
            <div className="top-row">
              <StudentInfo user={user} />
              <EnrolledClasses classes={classes} />
            </div>

            <TodaysLectures
              lectures={lectures}
              userId={user?.user_id}
              onUpload={handleFileUpload}
              uploading={uploading}
              error={error}
            />
          </div>
        </main>
      </div>
    </div>
  )
}

const StudentInfo = ({ user }) => {
  return (
    <div className="student-info-section">
      <h2>Profile</h2>
      <div className="info-grid">
        <div className="info-item">
          <label>Name</label>
          <span>{user?.name || user?.username || 'N/A'}</span>
        </div>
        <div className="info-item">
          <label>Student ID</label>
          <span>{user?.user_id || 'N/A'}</span>
        </div>
        <div className="info-item">
          <label>Username</label>
          <span>{user?.username || 'N/A'}</span>
        </div>
      </div>
    </div>
  )
}

const EnrolledClasses = ({ classes }) => {
  return (
    <div className="classes-section">
      <h2>Enrolled Classes</h2>
      {classes.length === 0 ? (
        <p className="no-classes">Not enrolled in any classes.</p>
      ) : (
        <div className="classes-list">
          {classes.map((cls) => (
            <div key={cls.class_id} className="class-mini-card">
              <div className="class-badge">{cls.class_code}</div>
              <div className="class-info">
                <span className="class-name-small">{cls.class_name}</span>
                <span className="class-meta-small">Sem {cls.semester} • {cls.department}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

const TodaysLectures = ({ lectures, userId, onUpload, uploading, error }) => {
  if (lectures.length === 0) {
    return (
      <div className="lectures-section">
        <h2>Today's Lectures</h2>
        <div className="empty-state">
          <p>No lectures scheduled for today.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="lectures-section">
      <h2>Today's Lectures</h2>
      {error && <div className="error-message">{error}</div>}
      <div className="lectures-grid">
        {lectures.map((lecture) => (
          <LectureCard
            key={lecture.id}
            lecture={lecture}
            userId={userId}
            onUpload={onUpload}
            uploading={uploading[lecture.id]}
          />
        ))}
      </div>
    </div>
  )
}

const LectureCard = ({ lecture, userId, onUpload, uploading }) => {
  const getStatusBadge = (status) => {
    const statusMap = {
      PRESENT: { class: 'status-present', text: 'Present', icon: '✅' },
      ABSENT: { class: 'status-absent', text: 'Absent', icon: '❌' },
      PENDING: { class: 'status-pending', text: 'Pending', icon: '⏳' },
    }
    const statusInfo = statusMap[status] || { class: 'status-pending', text: 'Pending', icon: '⏳' }
    return (
      <div className={`status-pill ${statusInfo.class}`}>
        <span className="status-dot"></span>
        <span className="status-text">{statusInfo.text}</span>
      </div>
    )
  }

  const canUpload = !lecture.finalized && !lecture.submission_id && !uploading
  const hasSubmission = lecture.submission_id

  return (
    <div className={`lecture-card-v2 ${lecture.finalized ? 'finalized' : ''}`}>
      <div className="card-top">
        <div className="subject-info">
          <h3>{lecture.subject_name}</h3>
          <span className="class-code-tag">{lecture.class_name}</span>
        </div>
        {getStatusBadge(lecture.attendance_status)}
      </div>

      <div className="card-middle">
        <div className="time-info">
          <span className="icon">🕒</span>
          <span className="text">{lecture.lecture_time}</span>
        </div>
      </div>

      <div className="card-bottom">
        {hasSubmission && (
          <SubmissionStatus submission={lecture.submission} />
        )}

        {canUpload && (
          <UploadBox
            lectureId={lecture.id}
            onUpload={onUpload}
            uploading={uploading}
          />
        )}

        {lecture.finalized && !hasSubmission && (
          <div className="status-notice warning">
            <span className="icon">⚠️</span>
            <p>Session ended. No submission possible.</p>
          </div>
        )}
      </div>
    </div>
  )
}

const UploadBox = ({ lectureId, onUpload, uploading }) => {
  const [isDragOver, setIsDragOver] = useState(false)

  const handleFileChange = (event) => {
    onUpload(lectureId, event)
  }

  return (
    <div className={`upload-zone ${uploading ? 'loading' : ''} ${isDragOver ? 'drag-over' : ''}`}
      onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
      onDragLeave={() => setIsDragOver(false)}
      onDrop={() => setIsDragOver(false)}>
      <label className="upload-label">
        <input
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          disabled={uploading}
          style={{ display: 'none' }}
        />
        {uploading ? (
          <div className="upload-loader">
            <div className="spinner-modern"></div>
            <span>Processing Submission...</span>
          </div>
        ) : (
          <div className="upload-cta">
            <div className="upload-icon-circle">
              <span className="icon">📤</span>
            </div>
            <div className="upload-text">
              <span className="main-text">Submit Validation</span>
              <span className="sub-text">Tap to upload your engagement proof</span>
            </div>
          </div>
        )}
      </label>
    </div>
  )
}

const SubmissionStatus = ({ submission }) => {
  if (!submission) return null

  const getStatusIcon = (status) => {
    if (status === 'done' || status === 'completed') return '✅'
    if (status === 'pending' || status === 'processing') return '⏳'
    return '❌'
  }

  return (
    <div className="submission-status">
      <h4>Submission Status</h4>
      <div className="status-grid">
        <div className="status-item">
          <span>{getStatusIcon(submission.ocr_status)}</span>
          <div>
            <strong>OCR:</strong> {submission.ocr_status || 'Pending'}
          </div>
        </div>
        <div className="status-item">
          <span>{getStatusIcon(submission.ai_status)}</span>
          <div>
            <strong>AI Check:</strong> {submission.ai_status || 'Pending'}
          </div>
        </div>
        <div className="status-item">
          <span>{getStatusIcon(submission.similarity_status)}</span>
          <div>
            <strong>Similarity:</strong> {submission.similarity_status || 'Pending'}
          </div>
        </div>
        {submission.final_decision && (
          <div className="status-item decision">
            <strong>Decision:</strong> {submission.final_decision}
          </div>
        )}
      </div>
    </div>
  )
}

export default Student
