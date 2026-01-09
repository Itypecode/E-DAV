import { useState, useRef, useEffect } from 'react'
import { teacherChat } from '../services/lectureService'
import './Chatbot.css'

const Chatbot = ({ teacherId }) => {
    const [isOpen, setIsOpen] = useState(false)
    const [messages, setMessages] = useState([
        { role: 'assistant', content: 'Hello! I\'m your AI assistant. Ask me anything about your classes, students, or performance!' }
    ])
    const [input, setInput] = useState('')
    const [loading, setLoading] = useState(false)
    const messagesEndRef = useRef(null)

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
    }

    useEffect(() => {
        scrollToBottom()
    }, [messages])

    const handleSend = async () => {
        if (!input.trim() || loading) return

        const userMessage = input.trim()
        setInput('')

        // Add user message
        setMessages(prev => [...prev, { role: 'user', content: userMessage }])
        setLoading(true)

        try {
            const response = await teacherChat(teacherId, userMessage)
            setMessages(prev => [...prev, { role: 'assistant', content: response.reply }])
        } catch (err) {
            setMessages(prev => [...prev, {
                role: 'assistant',
                content: `Sorry, I encountered an error: ${err.response?.data?.detail || err.message || 'Unknown error'}`
            }])
        } finally {
            setLoading(false)
        }
    }

    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault()
            handleSend()
        }
    }

    return (
        <>
            {/* Chat Toggle Button */}
            <button
                className={`chat-toggle ${isOpen ? 'open' : ''}`}
                onClick={() => setIsOpen(!isOpen)}
                aria-label="Toggle chatbot"
            >
                {isOpen ? '✕' : '💬'}
            </button>

            {/* Chat Window */}
            <div className={`chatbot-window ${isOpen ? 'open' : ''}`}>
                <div className="chatbot-header">
                    <div className="chatbot-title">
                        <span className="ai-icon">🤖</span>
                        <div>
                            <h3>AI Assistant</h3>
                            <p className="status-indicator">
                                <span className="status-dot"></span>
                                Online
                            </p>
                        </div>
                    </div>
                    <button
                        className="minimize-btn"
                        onClick={() => setIsOpen(false)}
                        aria-label="Close chat"
                    >
                        ✕
                    </button>
                </div>

                <div className="chatbot-messages">
                    {messages.map((msg, idx) => (
                        <div key={idx} className={`message ${msg.role}`}>
                            <div className="message-avatar">
                                {msg.role === 'assistant' ? '🤖' : '👤'}
                            </div>
                            <div className="message-content">
                                {msg.content}
                            </div>
                        </div>
                    ))}
                    {loading && (
                        <div className="message assistant">
                            <div className="message-avatar">🤖</div>
                            <div className="message-content typing">
                                <span></span>
                                <span></span>
                                <span></span>
                            </div>
                        </div>
                    )}
                    <div ref={messagesEndRef} />
                </div>

                <div className="chatbot-input">
                    <textarea
                        value={input}
                        onChange={(e) => setInput(e.target.value)}
                        onKeyPress={handleKeyPress}
                        placeholder="Ask me anything..."
                        rows={1}
                        disabled={loading}
                    />
                    <button
                        onClick={handleSend}
                        disabled={!input.trim() || loading}
                        className="send-btn"
                    >
                        ➤
                    </button>
                </div>
            </div>
        </>
    )
}

export default Chatbot
