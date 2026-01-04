import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getToken, getCurrentUser } from '../services/authService';
import { getStudentSubmissions } from '../services/lectureService';
import Sidebar from '../components/Sidebar';
import LoadingScreen from '../components/LoadingScreen';
import './MySubmissions.css';

const MySubmissions = () => {
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [submissions, setSubmissions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

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
                await fetchSubmissions();
            } catch (err) {
                setError('Failed to initialize session');
                setLoading(false);
            }
        };

        const fetchSubmissions = async () => {
            try {
                setLoading(true);
                const data = await getStudentSubmissions();
                setSubmissions(data);
            } catch (err) {
                setError('Failed to fetch your submissions');
            } finally {
                setLoading(false);
            }
        };

        init();
    }, [navigate]);

    const formatDate = (dateStr) => {
        if (!dateStr) return 'Date Pending';
        const date = new Date(dateStr);
        if (isNaN(date.getTime())) return 'Invalid Date';

        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    if (loading && !user) return <LoadingScreen message="Retrieving your submitted engagement proofs and notes..." />;

    return (
        <div className="student-dashboard">
            <Sidebar />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>My Submissions & Notes</h1>
                        <p className="header-subtitle">Your engagement history and uploaded validation proofs</p>
                    </div>
                </header>

                <main className="dashboard-main submissions-view">
                    <div className="submissions-container">
                        {loading ? (
                            <div className="loading-state">
                                <div className="spinner-modern"></div>
                                <p>Refreshing your gallery...</p>
                            </div>
                        ) : submissions.length === 0 ? (
                            <div className="empty-state-card">
                                <div className="empty-icon">📂</div>
                                <h3>No Submissions Yet</h3>
                                <p>Start uploading your validation proofs during class sessions to see them here.</p>
                            </div>
                        ) : (
                            <div className="submissions-grid">
                                {submissions.map((sub, index) => (
                                    <div key={index} className="submission-card">
                                        <div className="card-header">
                                            <div className="subject-badge">{sub.subject_code}</div>
                                            <span className="upload-date">{formatDate(sub.date)}</span>
                                        </div>
                                        <div className="card-body">
                                            <h3>{sub.subject_name}</h3>
                                            <div
                                                className="image-preview-container"
                                                onClick={() => window.open(sub.image_url, '_blank')}
                                            >
                                                <img
                                                    src={sub.image_url}
                                                    alt={`Submission for ${sub.subject_name}`}
                                                    className="submission-image"
                                                />
                                                <div className="image-overlay">
                                                    <span>Tap to enlarge</span>
                                                </div>
                                            </div>
                                        </div>
                                        <div className="card-footer">
                                            <button
                                                className="view-btn"
                                                onClick={() => window.open(sub.image_url, '_blank')}
                                            >
                                                <span>🔍</span> View Full Resolution
                                            </button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </main>
            </div>
        </div>
    );
};

export default MySubmissions;
