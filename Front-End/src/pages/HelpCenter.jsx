import React from 'react';
import Sidebar from '../components/Sidebar';
import './HelpCenter.css';

const HelpCenter = ({ role = 'student' }) => {
    const studentFaqs = [
        {
            q: "How is my attendance actually marked?",
            a: "Attendance is automatically captured during live lectures. The system uses your device's camera for periodic presence verification and checks your location to ensure you are attending from a valid zone."
        },
        {
            q: "What does 'OD' status mean?",
            a: "OD stands for 'On Duty'. This status is granted when you are representing the college in sports, cultural events, or official duties. Once your OD request is processed by the admin, your attendance for those slots will be updated."
        },
        {
            q: "I was present but marked absent. What should I do?",
            a: "Technical glitches can happen. Navigate to the 'Appeal' section, select the specific lecture instance, and provide a valid reason or evidence (like a screenshot or medical certificate) for review by your teacher."
        },
        {
            q: "How can I see my overall semester percentage?",
            a: "Your 'Attendance View' page provides a subject-wise breakdown. Your main dashboard also shows a total percentage gauge to help you keep track of the 75% requirement."
        },
        {
            q: "Where do I submit my class assignments?",
            a: "Use the 'My Submissions' tab. You can upload files directly linked to specific lecture instances taught by your instructors."
        }
    ];

    const teacherFaqs = [
        {
            q: "How do I start capturing attendance for a lecture?",
            a: "Go to your 'Teacher Hub' and find today's scheduled lecture. Click 'Start Lecture', enter the core concept being taught, and the system will begin tracking student engagement automatically."
        },
        {
            q: "Can I manually close or lock a session early?",
            a: "Yes. Every live lecture card has a 'Close Lecture' button. Once clicked, no further attendance entries or submissions will be accepted for that session."
        },
        {
            q: "How do I review student attendance appeals?",
            a: "Access the 'Appeals' section from your sidebar. You can filter by 'Pending' to see new requests, view student evidence, and provide a comment before approving or rejecting."
        },
        {
            q: "Where can I find detailed student performance reports?",
            a: "Visit the 'Lecture Summary' page and click on any specific lecture row. This will transition you to a detailed report showing student responses, conceptual understanding levels, and timestamps."
        },
        {
            q: "What happens if I forget to end a lecture?",
            a: "While it's best to manualy close sessions, the system has safety timeouts. However, manually closing ensures your 'Lecture Summary' stats are immediately and accurately updated."
        }
    ];

    const faqs = role === 'teacher' ? teacherFaqs : studentFaqs;

    return (
        <div className={role === 'teacher' ? "teacher-dashboard" : "student-dashboard"}>
            <Sidebar role={role} />

            <div className="main-content-wrapper">
                <header className="dashboard-header">
                    <div className="header-content">
                        <h1>Help Center</h1>
                    </div>
                </header>

                <main className="dashboard-main help-center-view">
                    <div className="help-container">
                        <div className="help-header">
                            <h2>Frequently Asked Questions</h2>
                            <p>Everything you need to know about the E-DAV {role === 'teacher' ? 'Instructor' : 'Student'} platform.</p>
                        </div>

                        <div className="faq-section">
                            {faqs.map((faq, index) => (
                                <div key={index} className="faq-item">
                                    <div className="faq-question">
                                        <span className="q-badge">Q</span>
                                        <h3>{faq.q}</h3>
                                    </div>
                                    <div className="faq-answer">
                                        <p>{faq.a}</p>
                                    </div>
                                </div>
                            ))}
                        </div>

                        <div className="contact-support">
                            <h4>Still need help?</h4>
                            <p>Our technical support team is available for platform-related issues.</p>
                            <a href="mailto:21sharan2007@gmail.com" className="support-btn">Contact IT Support</a>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
};

export default HelpCenter;
