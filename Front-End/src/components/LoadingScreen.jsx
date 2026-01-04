import React from 'react';
import './LoadingScreen.css';

const LoadingScreen = ({ message = "Initialising E-DAV Secure Session..." }) => {
    return (
        <div className="loading-screen">
            <div className="loader-container">
                <div className="logo-pulse">
                    <span className="logo-text-loader">E - DAV</span>
                </div>
                <div className="spinner-orbital">
                    <div className="orbit-dot"></div>
                </div>
                <p className="loading-message">{message}</p>
            </div>
            <div className="loading-background">
                <div className="blob"></div>
                <div className="blob second"></div>
            </div>
        </div>
    );
};

export default LoadingScreen;
