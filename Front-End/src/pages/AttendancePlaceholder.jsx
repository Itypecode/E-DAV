import React from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import './Student.css'; // Reuse some styles

const AttendancePlaceholder = () => {
    const navigate = useNavigate();

    return (
        <div className="student-dashboard">
            <Sidebar />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Attendance View</h1>
                    </div>
                </header>
                <main className="dashboard-main">
                    <div className="dashboard-container">
                        <div className="placeholder-content">
                            <h2>My Attendance Status</h2>
                            <p>This page will display your detailed attendance records across all enrolled classes.</p>
                            <div className="coming-soon-card">
                                <h3>Coming Soon</h3>
                                <p>We are currently building this feature to provide you with a comprehensive view of your academic progress.</p>
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
};

export default AttendancePlaceholder;
