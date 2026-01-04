import React from 'react';
import { NavLink } from 'react-router-dom';
import './Sidebar.css';

const Sidebar = () => {
    return (
        <div className="sidebar">
            <div className="sidebar-logo">
                <span className="logo-text">E - DAV</span>
            </div>
            <nav className="sidebar-nav">
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
            </nav>
            <div className="sidebar-footer">
                <div className="sidebar-help">
                    <span className="help-icon">❓</span>
                    <span>Help Center</span>
                </div>
            </div>
        </div>
    );
};

export default Sidebar;
