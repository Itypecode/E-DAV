import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getToken, getCurrentUser } from '../services/authService';
import { getAttendanceOverview, resolveLectureInstance } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './AttendanceView.css';

const AttendanceView = () => {
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [attendanceData, setAttendanceData] = useState({ calendar: [], summary: [] });
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
                if (userData.role !== 'student') {
                    navigate('/');
                    return;
                }
                setUser(userData);
                await fetchAttendance(userData.user_id);
            } catch (err) {
                setError('Failed to initialize session');
                setLoading(false);
            }
        };

        const fetchAttendance = async (userId) => {
            try {
                setLoading(true);
                const data = await getAttendanceOverview(userId, dateRange.start, dateRange.end);
                setAttendanceData(data);
            } catch (err) {
                setError('Failed to fetch attendance data');
            } finally {
                setLoading(false);
            }
        };

        init();
    }, [navigate, dateRange]);


    const handleCellClick = async (date, slot, cellData) => {
        if (!cellData || !cellData.subject) return;

        // Extract subject code from "CS101 - Intro to CS" format
        const subjectCode = cellData.subject.split(' - ')[0];

        try {
            setLoading(true);
            const result = await resolveLectureInstance(user.user_id, date, parseInt(slot), subjectCode);

            navigate('/appeal', {
                state: {
                    lectureInstanceId: result.lecture_instance_id,
                    userId: user.user_id,
                    subject: cellData.subject,
                    date: date,
                    slot: slot
                }
            });
        } catch (err) {
            console.error(err);
            alert('Could not resolve lecture instance details. ' + (err.response?.data?.detail || err.message));
        } finally {
            setLoading(false);
        }
    };

    const getStatusClass = (status) => {
        if (!status) return 'status-none';
        switch (status.toUpperCase()) {
            case 'PRESENT': return 'status-present';
            case 'ABSENT': return 'status-absent';
            case 'OD': return 'status-od';
            default: return 'status-none';
        }
    };

    if (loading && !user) return <LoadingScreen message="Aggregating attendance records and performing analytics..." />;

    return (
        <div className="student-dashboard">
            <Sidebar />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Attendance Analytics</h1>
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

                        {/* Legend Section */}
                        <div className="attendance-legend card">
                            <div className="legend-item">
                                <span className="legend-box status-present"></span>
                                <span>Present</span>
                            </div>
                            <div className="legend-item">
                                <span className="legend-box status-absent"></span>
                                <span>Absent</span>
                            </div>
                            <div className="legend-item">
                                <span className="legend-box status-none"></span>
                                <span>No Lecture / Not Submited</span>
                            </div>
                            <div className="legend-item">
                                <span className="legend-box status-od"></span>
                                <span>OD (On Duty)</span>
                            </div>
                        </div>

                        {/* Calendar Grid */}
                        <div className="calendar-section card">
                            <h3>Attendance Grid</h3>
                            <div className="table-responsive">
                                <table className="attendance-table">
                                    <thead>
                                        <tr>
                                            <th>S.No</th>
                                            <th>Date</th>
                                            <th>Day</th>
                                            <th>Day Order</th>
                                            <th>1st Hour</th>
                                            <th>2nd Hour</th>
                                            <th>3rd Hour</th>
                                            <th>4th Hour</th>
                                            <th>5th Hour</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {attendanceData.calendar.map((row, index) => (
                                            <tr key={row.date}>
                                                <td>{index + 1}</td>
                                                <td>{row.date}</td>
                                                <td>{row.day}</td>
                                                <td>{row.day_order}</td>
                                                {[1, 2, 3, 4, 5].map(hour => {
                                                    const cell = row.hours[hour];
                                                    return (
                                                        <td
                                                            key={hour}
                                                            className={`hour-cell ${getStatusClass(cell?.status)} ${cell ? 'clickable-cell' : ''}`}
                                                            onClick={() => cell && handleCellClick(row.date, hour, cell)}
                                                            title={cell ? "Click to appeal attendance" : ""}
                                                        >
                                                            {cell && (
                                                                <div className="cell-content">
                                                                    <span className="cell-status">[{cell.status?.[0]}]</span>
                                                                    <span className="cell-subject">{cell.subject.split(' - ')[0]}</span>
                                                                </div>
                                                            )}
                                                        </td>
                                                    );
                                                })}
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        {/* Summary Section */}
                        <div className="summary-section card">
                            <h3>Subject-wise Summary</h3>
                            <div className="table-responsive">
                                <table className="summary-table">
                                    <thead>
                                        <tr>
                                            <th>Subject Code</th>
                                            <th>Present</th>
                                            <th>OD</th>
                                            <th>Absent</th>
                                            <th>Total hours</th>
                                            <th>Percentage</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {attendanceData.summary.map((item) => (
                                            <tr key={item.subject}>
                                                <td className="subject-name-cell">{item.subject}</td>
                                                <td>{item.present}</td>
                                                <td>{item.od}</td>
                                                <td>{item.absent}</td>
                                                <td>{item.total}</td>
                                                <td className="percentage-cell">
                                                    <div className="percentage-bar-bg">
                                                        <div
                                                            className={`percentage-bar-fill ${item.percentage < 75 ? 'low' : ''}`}
                                                            style={{ width: `${item.percentage}%` }}
                                                        ></div>
                                                    </div>
                                                    <span className="percentage-text">{item.percentage}%</span>
                                                </td>
                                            </tr>
                                        ))}
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

export default AttendanceView;
