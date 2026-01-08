import React from 'react';
import { NavLink } from 'react-router-dom';
import './Sidebar.css';

const Sidebar = ({ role = 'student' }) => {
    return (
        <div className="sidebar">
            <div className="sidebar-logo">
                <span className="logo-text">E - DAV</span>
            </div>
            <nav className="sidebar-nav">
                {role === 'student' && (
                    <>
                        <NavLink to="/student" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')} end>
                            <span className="nav-icon">📊</span>
                            <span className="nav-text">Dashboard</span>
                        </NavLink>
                        <NavLink to="/attendance" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">📅</span>
                            <span className="nav-text">Attendance View</span>
                        </NavLink>
                        <NavLink to="/submissions" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">📚</span>
                            <span className="nav-text">My Submissions</span>
                        </NavLink>
                        <NavLink to="/appeal" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">⚖️</span>
                            <span className="nav-text">Appeal</span>
                        </NavLink>
                    </>
                )}

                {role === 'teacher' && (
                    <>
                        <NavLink to="/teacher" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')} end>
                            <span className="nav-icon">🎓</span>
                            <span className="nav-text">Teacher Hub</span>
                        </NavLink>
                        {/* Add more teacher links as features are built */}
                        <NavLink to="/teacher/classes" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">👥</span>
                            <span className="nav-text">My Classes</span>
                        </NavLink>
                        <NavLink to="/teacher/attendance" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">📅</span>
                            <span className="nav-text">Lecture Summary</span>
                        </NavLink>
                        <NavLink to="/teacher/appeals" className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                            <span className="nav-icon">⚖️</span>
                            <span className="nav-text">Appeals</span>
                        </NavLink>


                    </>
                )}
            </nav>
            <div className="sidebar-footer">
                <NavLink to={role === 'teacher' ? "/teacher/help" : "/help"} className="sidebar-help-link">
                    <div className="sidebar-help">
                        <span className="help-icon">❓</span>
                        <span>Help Center</span>
                    </div>
                </NavLink>
            </div>

        </div>
    );
};

export default Sidebar;
