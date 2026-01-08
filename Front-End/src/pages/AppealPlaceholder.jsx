import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { submitAppeal } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './Student.css';

const AppealPlaceholder = () => {
    const location = useLocation();
    const navigate = useNavigate();
    const { state } = location;

    const [reason, setReason] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [success, setSuccess] = useState(false);

    // If accessed directly without state, show instructions
    if (!state || !state.lectureInstanceId) {
        return (
            <div className="student-dashboard">
                <Sidebar />
                <div className="main-content-wrapper">
                    <header className="dashboard-header">
                        <div className="header-content">
                            <h1>Appeal Attendance</h1>
                        </div>
                    </header>
                    <main className="dashboard-main">
                        <div className="dashboard-container">
                            <div className="placeholder-content">
                                <h2>How to Appeal</h2>
                                <p>To submit an attendance appeal, please follow these steps:</p>
                                <ol className="instruction-list" style={{ textAlign: 'left', maxWidth: '600px', margin: '2rem auto' }}>
                                    <li>Go to the <strong>Attendance</strong> page.</li>
                                    <li>Find the specific lecture date and hour you want to appeal.</li>
                                    <li>Click on the cell (Present/Absent/OD) for that hour.</li>
                                    <li>You will be redirected here with the lecture details pre-filled.</li>
                                </ol>
                                <button className="login-btn" onClick={() => navigate('/attendance')} style={{ maxWidth: '200px' }}>
                                    Go to Attendance
                                </button>
                            </div>
                        </div>
                    </main>
                </div>
            </div>
        );
    }

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!reason.trim()) {
            setError('Please provide a reason for your appeal.');
            return;
        }

        try {
            setLoading(true);
            setError(null);
            await submitAppeal(state.userId, state.lectureInstanceId, reason);
            setSuccess(true);
        } catch (err) {
            console.error(err);
            setError(err.response?.data?.detail || err.message || 'Failed to submit appeal');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <LoadingScreen message="Submitting your appeal..." />;

    if (success) {
        return (
            <div className="student-dashboard">
                <Sidebar />
                <div className="main-content-wrapper">
                    <header className="dashboard-header">
                        <div className="header-content">
                            <h1>Appeal Submitted</h1>
                        </div>
                    </header>
                    <main className="dashboard-main">
                        <div className="dashboard-container">
                            <div className="success-card" style={{ textAlign: 'center', padding: '3rem' }}>
                                <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>✅</div>
                                <h2>Appeal Received</h2>
                                <p>Your appeal for <strong>{state.subject}</strong> on <strong>{state.date}</strong> has been submitted successfully.</p>
                                <div className="button-group" style={{ justifyContent: 'center', marginTop: '2rem' }}>
                                    <button className="login-btn" onClick={() => navigate('/attendance')}>
                                        Back to Attendance
                                    </button>
                                    <button className="login-btn secondary" onClick={() => navigate('/student')}>
                                        Dashboard
                                    </button>
                                </div>
                            </div>
                        </div>
                    </main>
                </div>
            </div>
        );
    }

    return (
        <div className="student-dashboard">
            <Sidebar />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Submit Appeal</h1>
                    </div>
                </header>
                <main className="dashboard-main">
                    <div className="dashboard-container">
                        <div className="card" style={{ maxWidth: '800px', margin: '0 auto' }}>
                            <h3>Appeal Details</h3>

                            <div className="info-grid" style={{ marginBottom: '2rem' }}>
                                <div className="info-item">
                                    <label>Subject</label>
                                    <span>{state.subject}</span>
                                </div>
                                <div className="info-item">
                                    <label>Date</label>
                                    <span>{state.date}</span>
                                </div>
                                <div className="info-item">
                                    <label>Hour Slot</label>
                                    <span>{state.slot}</span>
                                </div>
                            </div>

                            <form onSubmit={handleSubmit}>
                                <div className="form-group">
                                    <label htmlFor="reason" style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 'bold' }}>Reason for Appeal</label>
                                    <textarea
                                        id="reason"
                                        value={reason}
                                        onChange={(e) => setReason(e.target.value)}
                                        placeholder="Explain why you were absent or why this attendance record is incorrect..."
                                        rows="6"
                                        style={{
                                            width: '100%',
                                            padding: '1rem',
                                            borderRadius: '8px',
                                            border: '1px solid #ddd',
                                            fontFamily: 'inherit',
                                            resize: 'vertical'
                                        }}
                                        required
                                    />
                                </div>

                                {error && (
                                    <div className="error-message" style={{ margin: '1rem 0', color: '#e53e3e' }}>
                                        {error}
                                    </div>
                                )}

                                <div className="button-group" style={{ marginTop: '2rem', display: 'flex', gap: '1rem' }}>
                                    <button type="button" className="login-btn secondary" onClick={() => navigate('/attendance')} style={{ background: '#718096' }}>
                                        Cancel
                                    </button>
                                    <button type="submit" className="login-btn">
                                        Submit Appeal
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
};

export default AppealPlaceholder;
