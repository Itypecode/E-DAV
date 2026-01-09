import { useEffect, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { getCurrentUser, removeToken, getToken } from '../services/authService'
import { getTeacherSchedule, getTeacherClasses, toggleLectureLock, controlLecture, markStudentsAbsent } from '../services/lectureService'
import Sidebar from '../components/Sidebar'
import LoadingScreen from '../components/LoadingScreen'
import Chatbot from '../components/Chatbot'
import './Teacher.css'

const Teacher = () => {
  const navigate = useNavigate()
  const [user, setUser] = useState(null)
  const [lectures, setLectures] = useState([])
  const [scheduleDate, setScheduleDate] = useState(null)
  const [classes, setClasses] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [actionLoading, setActionLoading] = useState({})

  useEffect(() => {
    const init = async () => {
      const token = getToken()
      if (!token) {
        navigate('/')
        return
      }

      try {
        const userData = await getCurrentUser()
        if (userData.role !== 'teacher') {
          removeToken()
          navigate('/')
          return
        }
        setUser(userData)

        // Independent fetches
        try {
          const lecturesData = await getTeacherSchedule(userData.user_id)
          setLectures(lecturesData?.lectures || [])
          setScheduleDate(lecturesData?.date)
        } catch (err) {
          console.warn("Failed to fetch teacher schedule", err)
        }

        try {
          const classesData = await getTeacherClasses(userData.user_id)
          setClasses(classesData?.classes || [])
        } catch (err) {
          console.warn("Failed to fetch teacher classes", err)
        }

      } catch (err) {
        if (err.response?.status === 401) {
          removeToken()
          navigate('/')
        } else {
          setError(err.message || 'Failed to authenticate')
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

  const handleToggleLock = async (lectureId, currentStatus) => {
    setActionLoading(prev => ({ ...prev, [lectureId]: true }))
    try {
      const newStatus = !currentStatus
      await toggleLectureLock(lectureId, newStatus)

      // Optimistic update
      setLectures(prev => prev.map(lec =>
        lec.id === lectureId
          ? { ...lec, attendance_locked: newStatus }
          : lec
      ))
    } catch (err) {
      console.error("Failed to toggle lock", err)
      alert("Failed to update lecture status")
    } finally {
      setActionLoading(prev => ({ ...prev, [lectureId]: false }))
    }
  }

  const handleControlLecture = async (lectureId, action, concept = null) => {
    const actionText = action === 'START' ? 'start' : 'close';
    const confirmMessage = `Are you sure you want to ${actionText} this lecture? This action cannot be undone.`;

    if (!window.confirm(confirmMessage)) return;

    setActionLoading(prev => ({ ...prev, [lectureId]: true }))
    try {
      const response = await controlLecture(lectureId, user.user_id, action, concept)
      const newStatus = response.new_status

      setLectures(prev => prev.map(lec =>
        (lec.lecture_instance_id === lectureId || lec.id === lectureId)
          ? { ...lec, status: newStatus, attendance_locked: action === 'CLOSE' ? true : lec.attendance_locked, concept: concept || lec.concept }
          : lec
      ))
      return true;
    } catch (err) {
      console.error(`Failed to ${actionText} lecture`, err)
      alert(err.response?.data?.detail || `Failed to ${actionText} lecture`)
      return false;
    } finally {
      setActionLoading(prev => ({ ...prev, [lectureId]: false }))
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading Teacher Dashboard..." />
  }

  if (error && !user) {
    return (
      <div className="error-container">
        <p>{error}</p>
        <button onClick={() => navigate('/')}>Return to Login</button>
      </div>
    )
  }

  return (
    <div className="teacher-dashboard">
      <Sidebar role="teacher" />
      <div className="main-content-wrapper">
        <header className="dashboard-header">
          <div className="header-content">
            <h1>Teacher Dashboard</h1>
            <div className="header-right">
              <span className="username">Welcome, {user?.name} ({user?.dept})</span>
              <button onClick={handleLogout} className="logout-btn">
                Logout
              </button>
            </div>
          </div>
        </header>

        <main className="dashboard-main">
          <div className="dashboard-container">
            <div className="top-row">
              <TeacherInfo user={user} />
              <TeachingClasses classes={classes} />
            </div>

            <TeacherSchedule
              lectures={lectures}
              date={scheduleDate}
              onToggleLock={handleToggleLock}
              onControlLecture={handleControlLecture}
              actionLoading={actionLoading}
            />
          </div>
        </main>
      </div>

      {/* AI Chatbot Assistant */}
      <Chatbot teacherId={user?.user_id} />
    </div>
  )
}

const TeacherInfo = ({ user }) => {
  return (
    <div className="info-section">
      <h2>Profile</h2>
      <div className="info-grid">
        <div className="info-item">
          <label>Name</label>
          <span>{user?.name || 'N/A'}</span>
        </div>
        <div className="info-item">
          <label>Role</label>
          <span>Teacher</span>
        </div>
        <div className="info-item">
          <label>Department</label>
          <span>{user?.dept || 'N/A'}</span>
        </div>
      </div>
    </div>
  )
}

const TeachingClasses = ({ classes }) => {
  return (
    <div className="classes-section">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h2 style={{ marginBottom: 0 }}>Your Classes</h2>
        <Link to="/teacher/classes" className="view-all-link" style={{ fontSize: '0.9rem', color: '#2a5298', fontWeight: 600, textDecoration: 'none' }}>
          View Details →
        </Link>
      </div>
      {classes.length === 0 ? (
        <p className="no-classes">No active classes assigned.</p>
      ) : (
        <div className="classes-list">
          {classes.map((cls) => (
            <div key={cls.class_id} className="class-mini-card teacher-card">
              <div className="class-badge">{cls.class_code}</div>
              <div className="class-info">
                <span className="class-name-small">{cls.class_name}</span>
                <span className="class-meta-small">Sem {cls.semester} • {cls.students?.length || 0} Students</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

const TeacherSchedule = ({ lectures, date, onToggleLock, onControlLecture, actionLoading }) => {
  if (lectures.length === 0) {
    return (
      <div className="lectures-section">
        <h2>Today's Teaching Schedule {date && <span style={{ fontSize: '0.9em', color: '#666' }}>({date})</span>}</h2>
        <div className="empty-state">
          <p>No lectures scheduled for today.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="lectures-section">
      <h2>Today's Teaching Schedule {date && <span style={{ fontSize: '0.9em', color: '#666' }}>({date})</span>}</h2>
      <div className="lectures-grid">
        {lectures.map((lecture) => (
          <TeacherLectureCard
            key={lecture.lecture_instance_id || lecture.id}
            lecture={lecture}
            onToggleLock={onToggleLock}
            onControlLecture={onControlLecture}
            loading={actionLoading[lecture.lecture_instance_id || lecture.id]}
          />
        ))}
      </div>
    </div>
  )
}

const TeacherLectureCard = ({ lecture, onToggleLock, onControlLecture, loading }) => {
  const status = lecture.status ? lecture.status.toUpperCase() : '';
  const [showConceptDialog, setShowConceptDialog] = useState(false);
  const [concept, setConcept] = useState('');
  const [showAbsentModal, setShowAbsentModal] = useState(false);
  const [absentUsernames, setAbsentUsernames] = useState('');
  const [markingAbsent, setMarkingAbsent] = useState(false);

  const handleStartWithConcept = async () => {
    if (!concept.trim()) {
      alert("Please enter a concept for this lecture");
      return;
    }
    const success = await onControlLecture(lecture.lecture_instance_id || lecture.id, 'START', concept);
    if (success) {
      setShowConceptDialog(false);
    }
  }

  const handleMarkAbsent = async () => {
    const usernames = absentUsernames
      .split(/[\n,]/)
      .map(u => u.trim())
      .filter(u => u.length > 0);

    if (usernames.length === 0) {
      alert("Please enter at least one username");
      return;
    }

    setMarkingAbsent(true);
    try {
      const result = await markStudentsAbsent(lecture.lecture_instance_id || lecture.id, usernames);
      alert(`Success! Marked ${result.marked_absent.length} student(s) as absent.${result.usernames_not_found.length > 0 ? `\n\nNot found: ${result.usernames_not_found.join(', ')}` : ''}`);
      setAbsentUsernames('');
      setShowAbsentModal(false);
    } catch (err) {
      alert(`Error: ${err.response?.data?.detail || err.message || 'Failed to mark absent'}`);
    } finally {
      setMarkingAbsent(false);
    }
  }

  return (
    <div className={`lecture-card-v2 teacher-view ${status === 'LIVE' ? 'active' : status === 'CLOSED' ? 'locked' : ''}`}>
      <div className="card-top">
        <div className="subject-info">
          <h3>{lecture.subject_name || lecture.class_name || lecture.subject_code}</h3>
          <span className="class-code-tag">{lecture.class_code}</span>
        </div>
        {(() => {
          let statusClass = 'status-absent';
          let statusText = 'Closed';

          if (status === 'LIVE') {
            statusClass = 'status-present';
            statusText = 'Live';
          } else if (status === 'SCHEDULED') {
            statusClass = 'status-pending';
            statusText = 'Scheduled';
          }

          return (
            <div className={`status-pill ${statusClass}`}>
              <span className="status-dot"></span>
              <span className="status-text">{statusText}</span>
            </div>
          );
        })()}
      </div>

      <div className="card-middle">
        <div className="time-info">
          <span className="icon">🕒</span>
          <span className="text">
            {lecture.start_time} - {lecture.end_time}
          </span>
        </div>
        {(lecture.concept || concept) && (status === 'LIVE' || status === 'CLOSED') && (
          <div className="concept-info">
            <strong>Today's Concept:</strong><br />
            {lecture.concept || concept}
          </div>
        )}
      </div>

      <div className="card-bottom" style={{ flexDirection: 'column', alignItems: 'flex-start' }}>
        <div className="stats-mini">
          <span>👥 {lecture.total_students || 0} Students</span>
        </div>

        {showConceptDialog ? (
          <div className="concept-dialog" style={{ width: '100%', marginTop: '1rem' }}>
            <textarea
              className="concept-input"
              placeholder="Enter the concept being taught (e.g., Introduction to Neural Networks)"
              value={concept}
              onChange={(e) => setConcept(e.target.value)}
            />
            <div className="button-group" style={{ display: 'flex', gap: '10px', marginTop: '1rem' }}>
              <button
                className="action-btn start-btn"
                onClick={handleStartWithConcept}
                disabled={loading}
              >
                {loading ? 'Starting...' : 'Go Live'}
              </button>
              <button
                className="action-btn unlock-btn"
                onClick={() => setShowConceptDialog(false)}
                disabled={loading}
              >
                Cancel
              </button>
            </div>
          </div>
        ) : showAbsentModal ? (
          <div className="concept-dialog" style={{ width: '100%', marginTop: '1rem' }}>
            <label style={{ fontSize: '0.9rem', color: '#4a5568', marginBottom: '0.5rem', display: 'block' }}>
              Enter usernames (one per line or comma-separated):
            </label>
            <textarea
              className="concept-input"
              placeholder="student1, student2&#10;student3"
              value={absentUsernames}
              onChange={(e) => setAbsentUsernames(e.target.value)}
              rows={4}
            />
            <div className="button-group" style={{ display: 'flex', gap: '10px', marginTop: '1rem' }}>
              <button
                className="action-btn lock-btn"
                onClick={handleMarkAbsent}
                disabled={markingAbsent}
              >
                {markingAbsent ? 'Marking...' : 'Mark Absent'}
              </button>
              <button
                className="action-btn unlock-btn"
                onClick={() => { setShowAbsentModal(false); setAbsentUsernames(''); }}
                disabled={markingAbsent}
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="action-buttons" style={{ display: 'flex', gap: '10px', marginTop: '1.5rem', width: '100%', flexWrap: 'wrap' }}>
            {status === 'SCHEDULED' && (
              <>
                <button
                  className="action-btn start-btn"
                  onClick={() => setShowConceptDialog(true)}
                  disabled={loading}
                >
                  Start Lecture
                </button>
                <button
                  className="action-btn lock-btn"
                  onClick={() => onControlLecture(lecture.lecture_instance_id || lecture.id, 'CLOSE')}
                  disabled={loading}
                >
                  {loading ? 'Closing...' : 'Close Lecture'}
                </button>
              </>
            )}
            {status === 'LIVE' && (
              <>
                <button
                  className="action-btn unlock-btn"
                  style={{ fontSize: '0.85rem', padding: '0.6rem 1rem' }}
                  onClick={() => setShowAbsentModal(true)}
                  disabled={loading}
                >
                  Mark Absent
                </button>
                <button
                  className="action-btn lock-btn"
                  onClick={() => onControlLecture(lecture.lecture_instance_id || lecture.id, 'CLOSE')}
                  disabled={loading}
                >
                  {loading ? 'Closing...' : 'Close Lecture'}
                </button>
              </>
            )}
            {status === 'CLOSED' && (
              <span className="session-tag" style={{ fontSize: '0.85rem', color: '#666', fontStyle: 'italic', background: '#f8f9fa', padding: '4px 12px', borderRadius: '4px' }}>Session concluded</span>
            )}
          </div>
        )}
      </div>

    </div>

  )
}

export default Teacher
