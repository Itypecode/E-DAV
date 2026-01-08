import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getToken, getCurrentUser } from '../services/authService';
import { getTeacherAttendanceOverview } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './TeacherAttendanceView.css';

const TeacherAttendanceView = () => {
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [lectures, setLectures] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Default to last 30 days
    const [dateRange, setDateRange] = useState({
        start: new Date(new Date().setDate(new Date().getDate() - 30)).toISOString().split('T')[0],
        end: new Date().toISOString().split('T')[0]
    });

    useEffect(() => {
        const init = async () => {
            const token = getToken();
            if (!token) {
                navigate('/');
                return;
            }

            try {
                const userData = await getCurrentUser();
                if (userData.role !== 'teacher') {
                    navigate('/');
                    return;
                }
                setUser(userData);
                await fetchOverview(userData.user_id);
            } catch (err) {
                setError('Failed to initialize session');
                setLoading(false);
            }
        };

        const fetchOverview = async (teacherId) => {
            try {
                setLoading(true);
                const data = await getTeacherAttendanceOverview(teacherId, dateRange.start, dateRange.end);
                setLectures(data.lectures || []);
            } catch (err) {
                setError('Failed to fetch attendance overview');
            } finally {
                setLoading(false);
            }
        };

        init();
    }, [navigate, dateRange]);

    if (loading && !user) return <LoadingScreen message="Loading attendance records..." />;

    return (
        <div className="teacher-dashboard">
            <Sidebar role="teacher" />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Lecture Summary</h1>
                        <div className="attendance-filter-controls">
                            <div className="filter-group">
                                <label>From:</label>
                                <input
                                    type="date"
                                    value={dateRange.start}
                                    onChange={(e) => setDateRange(prev => ({ ...prev, start: e.target.value }))}
                                    className="date-input"
                                />
                            </div>
                            <div className="filter-group">
                                <label>To:</label>
                                <input
                                    type="date"
                                    value={dateRange.end}
                                    onChange={(e) => setDateRange(prev => ({ ...prev, end: e.target.value }))}
                                    className="date-input"
                                />
                            </div>
                        </div>
                    </div>
                </header>

                <main className="dashboard-main attendance-view">
                    <div className="attendance-container">
                        <div className="calendar-section card">
                            <h3>Lecture Summary</h3>
                            <div className="table-responsive">
                                <table className="attendance-table teacher-overview-table">
                                    <thead>
                                        <tr>
                                            <th>Date</th>
                                            <th>Hour</th>
                                            <th>Subject</th>
                                            <th>Present</th>
                                            <th>Absent</th>
                                            <th>OD</th>
                                            <th>Pending</th>
                                            <th>Total</th>
                                            <th>Percentage</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {lectures.length === 0 ? (
                                            <tr>
                                                <td colSpan="9" style={{ textAlign: 'center', padding: '2rem' }}>
                                                    No lectures found for the selected range.
                                                </td>
                                            </tr>
                                        ) : (
                                            lectures.map((lecture) => {
                                                const attendancePercentage = lecture.total > 0
                                                    ? (((lecture.present + lecture.od) / lecture.total) * 100).toFixed(1)
                                                    : 0;

                                                return (
                                                    <tr
                                                        key={lecture.lecture_instance_id}
                                                        className="clickable-row"
                                                        onClick={() => navigate(`/teacher/report/${lecture.lecture_instance_id}`, { state: { lecture } })}
                                                        title="Click to view detailed attendance report"
                                                    >
                                                        <td>{lecture.date}</td>
                                                        <td>{lecture.hour_slot}</td>
                                                        <td className="subject-cell">{lecture.subject}</td>
                                                        <td className="count-cell present">{lecture.present}</td>
                                                        <td className="count-cell absent">{lecture.absent}</td>
                                                        <td className="count-cell od">{lecture.od}</td>
                                                        <td className="count-cell pending">{lecture.pending}</td>
                                                        <td className="count-cell total">{lecture.total}</td>
                                                        <td>
                                                            <div className="perc-display">
                                                                <div className="perc-bar-bg">
                                                                    <div
                                                                        className="perc-bar-fill"
                                                                        style={{ width: `${attendancePercentage}%`, background: attendancePercentage < 75 ? '#f56565' : '#48bb78' }}
                                                                    ></div>
                                                                </div>
                                                                <span>{attendancePercentage}%</span>
                                                            </div>
                                                        </td>
                                                    </tr>
                                                );
                                            })
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
};

export default TeacherAttendanceView;
