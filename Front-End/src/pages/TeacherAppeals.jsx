import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getToken, getCurrentUser } from '../services/authService';
import { getTeacherAppeals, resolveAppeal, getStudentAppealData } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './TeacherAppeals.css';

const TeacherAppeals = () => {
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [appeals, setAppeals] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filterStatus, setFilterStatus] = useState('PENDING');
    const [error, setError] = useState(null);
    const [resolvingId, setResolvingId] = useState(null);
    const [comments, setComments] = useState({});
    const [showAnalysisModal, setShowAnalysisModal] = useState(false);
    const [analysisData, setAnalysisData] = useState(null);
    const [loadingAnalysis, setLoadingAnalysis] = useState(false);

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
                await fetchAppeals(userData.user_id, filterStatus);
            } catch (err) {
                setError('Failed to load appeals');
                setLoading(false);
            }
        };

        init();
    }, [navigate, filterStatus]);

    const fetchAppeals = async (teacherId, status) => {
        try {
            setLoading(true);
            const data = await getTeacherAppeals(teacherId, status);
            setAppeals(data.appeals || []);
        } catch (err) {
            setError('Failed to fetch appeals');
        } finally {
            setLoading(false);
        }
    };

    const handleCommentChange = (appealId, value) => {
        setComments(prev => ({
            ...prev,
            [appealId]: value
        }));
    };

    const handleResolve = async (appealId, decision) => {
        const actionText = decision === 'APPROVED' ? 'approve' : 'reject';
        if (!window.confirm(`Are you sure you want to ${actionText} this appeal?`)) return;

        setResolvingId(appealId);
        try {
            const comment = comments[appealId] || "";
            await resolveAppeal(appealId, user.user_id, decision, comment);

            // Optimistic update
            setAppeals(prev => prev.filter(a => a.appeal_id !== appealId));

            const newComments = { ...comments };
            delete newComments[appealId];
            setComments(newComments);
        } catch (err) {
            console.error("Resolution error:", err);
            alert(err.response?.data?.detail || `Failed to ${actionText} appeal`);
        } finally {
            setResolvingId(null);
        }
    };

    const handleViewAnalysis = async (lectureInstanceId, studentId) => {
        setLoadingAnalysis(true);
        try {
            const data = await getStudentAppealData(lectureInstanceId, studentId);
            setAnalysisData(data);
            setShowAnalysisModal(true);
        } catch (err) {
            console.error("Failed to fetch analysis:", err);
            alert(err.response?.data?.detail || "Failed to fetch student analysis data");
        } finally {
            setLoadingAnalysis(false);
        }
    };

    if (loading && !user) return <LoadingScreen message="Loading student appeals..." />;

    return (
        <div className="teacher-dashboard">
            <Sidebar role="teacher" />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Student Appeals</h1>
                        <div className="appeal-filter-tabs">
                            <button
                                className={`filter-tab ${filterStatus === 'PENDING' ? 'active' : ''}`}
                                onClick={() => setFilterStatus('PENDING')}
                            >
                                Pending
                            </button>
                            <button
                                className={`filter-tab ${filterStatus === 'APPROVED' ? 'active' : ''}`}
                                onClick={() => setFilterStatus('APPROVED')}
                            >
                                Approved
                            </button>
                            <button
                                className={`filter-tab ${filterStatus === 'REJECTED' ? 'active' : ''}`}
                                onClick={() => setFilterStatus('REJECTED')}
                            >
                                Rejected
                            </button>
                        </div>
                    </div>
                </header>

                <main className="dashboard-main appeals-view">
                    <div className="appeals-container">
                        {appeals.length === 0 ? (
                            <div className="empty-state-card card">
                                <div className="empty-icon">📂</div>
                                <h3>No {filterStatus.toLowerCase()} appeals found</h3>
                                <p>You have cleared all pending items in this category.</p>
                            </div>
                        ) : (
                            <div className="appeals-list">
                                {appeals.map((appeal) => (
                                    <div key={appeal.appeal_id} className="appeal-card-v2 card">
                                        <div className="appeal-card-header">
                                            <div className="student-info-mini">
                                                <span className="student-avatar">{appeal.student_name[0]}</span>
                                                <div className="student-details">
                                                    <span className="name">{appeal.student_name}</span>
                                                    <span className="id">{appeal.class_code} | {appeal.lecture_date}</span>
                                                </div>
                                            </div>
                                            <div className={`status-badge-compact ${appeal.appeal_status.toLowerCase()}`}>
                                                {appeal.appeal_status}
                                            </div>
                                        </div>

                                        <div className="appeal-card-body">
                                            <div className="lecture-context">
                                                <strong>Class:</strong> {appeal.class_name} ({appeal.class_code})<br />
                                                <strong>Current Attendance:</strong> <span className="decision-absent">{appeal.current_decision}</span>
                                            </div>
                                            <div className="reason-box">
                                                <strong>Reason for Appeal:</strong>
                                                <p>"{appeal.reason}"</p>
                                            </div>
                                            {appeal.evidence_url && (
                                                <div className="evidence-link">
                                                    <a href={appeal.evidence_url} target="_blank" rel="noopener noreferrer">
                                                        🔗 View Supporting Evidence
                                                    </a>
                                                </div>
                                            )}
                                        </div>

                                        <div className="appeal-actions-secondary" style={{ marginTop: '1rem' }}>
                                            <button
                                                className="analysis-btn"
                                                onClick={() => handleViewAnalysis(appeal.lecture_instance_id, appeal.student_id)}
                                                disabled={loadingAnalysis}
                                            >
                                                📊 View Analysis
                                            </button>
                                        </div>

                                        {appeal.appeal_status === 'PENDING' && (
                                            <div className="appeal-resolution-footer" style={{ marginTop: '1rem' }}>
                                                <textarea
                                                    className="teacher-comment-input"
                                                    placeholder="Add a comment for the student (optional)..."
                                                    value={comments[appeal.appeal_id] || ""}
                                                    onChange={(e) => handleCommentChange(appeal.appeal_id, e.target.value)}
                                                    disabled={resolvingId === appeal.appeal_id}
                                                    style={{ width: '100%', marginBottom: '1rem' }}
                                                />
                                                <div className="appeal-card-actions">
                                                    <button
                                                        className="approve-btn"
                                                        onClick={() => handleResolve(appeal.appeal_id, 'APPROVED')}
                                                        disabled={resolvingId === appeal.appeal_id}
                                                    >
                                                        {resolvingId === appeal.appeal_id ? 'Wait...' : 'Approve'}
                                                    </button>
                                                    <button
                                                        className="reject-btn"
                                                        onClick={() => handleResolve(appeal.appeal_id, 'REJECTED')}
                                                        disabled={resolvingId === appeal.appeal_id}
                                                    >
                                                        {resolvingId === appeal.appeal_id ? 'Wait...' : 'Reject'}
                                                    </button>
                                                </div>
                                            </div>
                                        )}
                                        {appeal.appeal_status !== 'PENDING' && (
                                            <div className="appeal-resolved-footer" style={{ marginTop: '1rem', borderTop: '1px solid #edf2f7', paddingTop: '1rem' }}>
                                                <strong style={{ fontSize: '0.85rem', color: '#1a202c' }}>Resolution Detail:</strong>
                                                <p className="resolution-comment" style={{ fontSize: '0.9rem', color: '#4a5568', fontStyle: 'italic', marginTop: '0.4rem' }}>
                                                    {appeal.teacher_comment || "No comment provided."}
                                                </p>
                                            </div>
                                        )}
                                    </div>

                                ))}
                            </div>
                        )}
                    </div>

                    {showAnalysisModal && analysisData && (
                        <div className="modal-overlay" onClick={() => setShowAnalysisModal(false)}>
                            <div className="modal-content" onClick={(e) => e.stopPropagation()}>
                                <div className="modal-header">
                                    <h3>Student Submission Analysis</h3>
                                    <button className="modal-close" onClick={() => setShowAnalysisModal(false)}>✕</button>
                                </div>
                                <div className="modal-body">
                                    <table className="analysis-table">
                                        <tbody>
                                            <tr>
                                                <td className="label-cell">Plagiarism Similarity</td>
                                                <td className="value-cell">
                                                    <span className={`similarity-badge ${analysisData.max_similarity > 0.9 ? 'high' : analysisData.max_similarity > 0.4 ? 'medium' : 'low'}`}>
                                                        {(analysisData.max_similarity * 100).toFixed(0)}%
                                                    </span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td className="label-cell">Copied From</td>
                                                <td className="value-cell">
                                                    {analysisData.copied_from_submission_id || 'N/A'}
                                                </td>
                                            </tr>
                                            <tr>
                                                <td className="label-cell">AI Score</td>
                                                <td className="value-cell">
                                                    <span className={`ai-score-badge ${analysisData.ai_score > 75 ? 'excellent' : analysisData.ai_score >= 50 ? 'good' : 'poor'}`}>
                                                        {analysisData.ai_score}/100
                                                    </span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td className="label-cell">AI Reasoning</td>
                                                <td className="value-cell">{analysisData.ai_reason || 'N/A'}</td>
                                            </tr>
                                            <tr>
                                                <td className="label-cell">AI Confidence</td>
                                                <td className="value-cell">
                                                    <span className={`confidence-badge ${analysisData.ai_confidence?.toLowerCase() || 'low'}`}>
                                                        {analysisData.ai_confidence || 'LOW'}
                                                    </span>
                                                </td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    )}

                </main>
            </div>
        </div>
    );
};

export default TeacherAppeals;
