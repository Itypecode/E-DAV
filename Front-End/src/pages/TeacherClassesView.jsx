import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getCurrentUser, getToken } from '../services/authService'
import { getTeacherClasses } from '../services/lectureService'
import Sidebar from '../components/Sidebar'
import LoadingScreen from '../components/LoadingScreen'
import './TeacherClassesView.css'

const TeacherClassesView = () => {
    const navigate = useNavigate()
    const [user, setUser] = useState(null)
    const [classes, setClasses] = useState([])
    const [selectedClass, setSelectedClass] = useState(null)
    const [loading, setLoading] = useState(true)
    const [error, setError] = useState(null)

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
                    navigate('/')
                    return
                }
                setUser(userData)

                const data = await getTeacherClasses(userData.user_id)
                setClasses(data.classes || [])
            } catch (err) {
                setError('Failed to load class data')
            } finally {
                setLoading(false)
            }
        }

        init()
    }, [navigate])

    if (loading) return <LoadingScreen message="Accessing class registries..." />

    return (
        <div className="teacher-dashboard">
            <Sidebar role="teacher" />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Manage Classes</h1>
                        <div className="header-right">
                            <span className="username">{user?.dept} Department</span>
                        </div>
                    </div>
                </header>

                <main className="dashboard-main teacher-classes-view">
                    <div className="teacher-classes-container">
                        <div className="classes-drilldown-wrapper">
                            {!selectedClass ? (
                                <div className="all-classes-view">
                                    <div className="classes-header">
                                        <h3>Your Assigned Classes ({classes.length})</h3>
                                    </div>
                                    <div className="class-cards-grid">
                                        {classes.map((cls) => (
                                            <div
                                                key={cls.class_id}
                                                className="class-detail-card"
                                                onClick={() => setSelectedClass(cls)}
                                            >
                                                <div className="class-code">{cls.class_code}</div>
                                                <h3>{cls.class_name}</h3>
                                                <div className="class-meta-info">
                                                    <div className="meta-row">
                                                        <span>📅 Semester {cls.semester}</span>
                                                    </div>
                                                    <div className="meta-row">
                                                        <span>🏢 {cls.department}</span>
                                                    </div>
                                                    <div className="meta-row">
                                                        <span>👥 {cls.students?.length || 0} Students enrolled</span>
                                                    </div>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            ) : (
                                <div className="class-drilldown-view">
                                    <div className="drilldown-header">
                                        <button className="back-btn" onClick={() => setSelectedClass(null)}>
                                            ← Return to Classes
                                        </button>
                                        <h2>{selectedClass.class_name}</h2>
                                    </div>

                                    <div className="drilldown-meta-bar">
                                        <div className="meta-stat">
                                            <label>Course Code</label>
                                            <span>{selectedClass.class_code}</span>
                                        </div>
                                        <div className="meta-stat">
                                            <label>Semester</label>
                                            <span>{selectedClass.semester}</span>
                                        </div>
                                        <div className="meta-stat">
                                            <label>Department</label>
                                            <span>{selectedClass.department}</span>
                                        </div>
                                        <div className="meta-stat">
                                            <label>Students</label>
                                            <span>{selectedClass.students?.length || 0}</span>
                                        </div>
                                    </div>

                                    <div className="students-table-container">
                                        <table className="students-table">
                                            <thead>
                                                <tr>
                                                    <th>Reg. Number</th>
                                                    <th>Student Name</th>
                                                    <th>Major/Dept</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {selectedClass.students?.length === 0 ? (
                                                    <tr>
                                                        <td colSpan="3" style={{ textAlign: 'center', padding: '2rem' }}>
                                                            No students enrolled in this class.
                                                        </td>
                                                    </tr>
                                                ) : (
                                                    selectedClass.students.map((student) => (
                                                        <tr key={student.student_id}>
                                                            <td>{student.username}</td>
                                                            <td style={{ fontWeight: 600 }}>{student.name}</td>
                                                            <td>
                                                                <span className="dept-badge">{student.dept}</span>
                                                            </td>
                                                        </tr>
                                                    ))
                                                )}
                                            </tbody>
                                        </table>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </main>
            </div>
        </div>
    )
}

export default TeacherClassesView
