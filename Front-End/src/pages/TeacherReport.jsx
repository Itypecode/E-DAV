import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import { getLectureAttendanceDetail } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './TeacherReport.css';

const TeacherReport = () => {
    const { lectureId } = useParams();
    const navigate = useNavigate();
    const location = useLocation();
    const [students, setStudents] = useState([]);
    const [filteredStudents, setFilteredStudents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Metadata from navigation state if available
    const lectureMeta = location.state?.lecture || {};

    // Filters
    const [filters, setFilters] = useState({
        decision: 'ALL',
        understanding: 'ALL'
    });

    useEffect(() => {
        const fetchDetails = async () => {
            try {
                setLoading(true);
                const data = await getLectureAttendanceDetail(lectureId);
                setStudents(data.students || []);
                setFilteredStudents(data.students || []);
            } catch (err) {
                setError('Failed to load attendance details');
            } finally {
                setLoading(false);
            }
        };

        if (lectureId) {
            fetchDetails();
        }
    }, [lectureId]);

    useEffect(() => {
        let result = students;

        if (filters.decision !== 'ALL') {
            result = result.filter(s => (s.decision || '').toUpperCase() === filters.decision);
        }

        if (filters.understanding !== 'ALL') {
            result = result.filter(s => (s.conceptual_understanding || '').toUpperCase() === filters.understanding);
        }

        setFilteredStudents(result);
    }, [filters, students]);

    const getDecisionClass = (decision) => {
        const d = (decision || '').toUpperCase();
        if (d === 'PRESENT') return 'val-present';
        if (d === 'ABSENT') return 'val-absent';
        if (d === 'OD') return 'val-od';
        if (d === 'PENDING') return 'val-pending';
        return '';
    };

    const getUnderstandingClass = (understanding) => {
        const u = (understanding || '').toUpperCase();
        if (u === 'HIGH') return 'val-high';
        if (u === 'MEDIUM') return 'val-medium';
        if (u === 'POOR') return 'val-poor';
        return '';
    };

    if (loading) return <LoadingScreen message="Generating detailed attendance report..." />;

    return (
        <div className="teacher-dashboard">
            <Sidebar role="teacher" />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <div className="header-left-group">
                            <button className="back-btn" onClick={() => navigate('/teacher/attendance')}>← Back</button>
                            <h1>Lecture Report</h1>
                        </div>
                        {lectureMeta.subject && (
                            <div className="lecture-meta-header">
                                <span className="meta-tag">{lectureMeta.subject}</span>
                                <span className="meta-tag">{lectureMeta.date} | Hour {lectureMeta.hour_slot}</span>
                            </div>
                        )}
                    </div>
                </header>

                <main className="dashboard-main report-view">
                    <div className="report-container">
                        <div className="report-card card">
                            <div className="report-filters">
                                <div className="filter-item">
                                    <label>Attendance Status:</label>
                                    <select
                                        value={filters.decision}
                                        onChange={(e) => setFilters(f => ({ ...f, decision: e.target.value }))}
                                    >
                                        <option value="ALL">All Decisions</option>
                                        <option value="PRESENT">Present</option>
                                        <option value="ABSENT">Absent</option>
                                        <option value="OD">OD</option>
                                        <option value="PENDING">Pending</option>
                                    </select>
                                </div>
                                <div className="filter-item">
                                    <label>Conceptual Understanding:</label>
                                    <select
                                        value={filters.understanding}
                                        onChange={(e) => setFilters(f => ({ ...f, understanding: e.target.value }))}
                                    >
                                        <option value="ALL">All Levels</option>
                                        <option value="HIGH">High</option>
                                        <option value="MEDIUM">Medium</option>
                                        <option value="POOR">Poor</option>
                                    </select>
                                </div>
                                <div className="report-stats">
                                    <span>Showing {filteredStudents.length} of {students.length} students</span>
                                </div>
                            </div>

                            <div className="table-responsive">
                                <table className="report-table">
                                    <thead>
                                        <tr>
                                            <th>Reg. Number</th>
                                            <th>Student Name</th>
                                            <th>Decision</th>
                                            <th>Conceptual understanding</th>
                                            <th>Response / Reason</th>
                                            <th>Submitted At</th>
                                            <th>Artifact</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {filteredStudents.length === 0 ? (
                                            <tr>
                                                <td colSpan="7" className="empty-row">No records match the selected filters.</td>
                                            </tr>
                                        ) : (
                                            filteredStudents.map((student) => (
                                                <tr key={student.student_id}>
                                                    <td>{student.username}</td>
                                                    <td className="student-name">{student.name}</td>
                                                    <td className={`status-cell ${getDecisionClass(student.decision)}`}>
                                                        {student.decision || 'N/A'}
                                                    </td>
                                                    <td className={`understanding-cell ${getUnderstandingClass(student.conceptual_understanding)}`}>
                                                        {student.conceptual_understanding || 'N/A'}
                                                    </td>
                                                    <td className="reason-cell" title={student.reason}>
                                                        {student.reason || '-'}
                                                    </td>
                                                    <td>{new Date(student.created_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}</td>
                                                    <td>
                                                        {student.upload_url ? (
                                                            <a href={student.upload_url} target="_blank" rel="noopener noreferrer" className="view-link">View File</a>
                                                        ) : '-'}
                                                    </td>
                                                </tr>
                                            ))
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

export default TeacherReport;
