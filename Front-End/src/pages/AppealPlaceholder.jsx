import React from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import './Student.css'; // Reuse some styles

const AppealPlaceholder = () => {
    return (
        <div className="student-dashboard">
            <Sidebar />
            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Appeal Submission</h1>
                    </div>
                </header>
                <main className="dashboard-main">
                    <div className="dashboard-container">
                        <div className="placeholder-content">
                            <h2>Submit an Appeal</h2>
                            <p>Marked absent incorrectly? You can submit an appeal for attendance correction here.</p>
                            <div className="coming-soon-card">
                                <h3>Coming Soon</h3>
                                <p>The appeal system is being integrated. You will soon be able to upload supporting documents and track your appeal status.</p>
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
};

export default AppealPlaceholder;
