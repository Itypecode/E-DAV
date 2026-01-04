import { useState, useEffect } from 'react'
import { testSupabase } from '../services/submissionService'
import './Home.css'

const Home = () => {
  const [supabaseStatus, setSupabaseStatus] = useState(null)
  const [loading, setLoading] = useState(false)

  const handleTestConnection = async () => {
    setLoading(true)
    try {
      const result = await testSupabase()
      setSupabaseStatus(result)
    } catch (error) {
      setSupabaseStatus({
        connected: false,
        error: error.message || 'Failed to connect to backend'
      })
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    // Optionally test connection on mount
    // handleTestConnection()
  }, [])

  return (
    <div className="home">
      <div className="hero">
        <h1>Welcome to Application</h1>
        <p>Your submission management system</p>
      </div>

      <div className="content-section">
        <h2>Backend Connection Test</h2>
        <button 
          onClick={handleTestConnection} 
          disabled={loading}
          className="test-button"
        >
          {loading ? 'Testing...' : 'Test Supabase Connection'}
        </button>

        {supabaseStatus && (
          <div className={`status-card ${supabaseStatus.connected ? 'success' : 'error'}`}>
            <h3>Connection Status</h3>
            <p>
              <strong>Status:</strong> {supabaseStatus.connected ? 'Connected ✓' : 'Disconnected ✗'}
            </p>
            {supabaseStatus.message && (
              <p><strong>Message:</strong> {supabaseStatus.message}</p>
            )}
            {supabaseStatus.error && (
              <p><strong>Error:</strong> {supabaseStatus.error}</p>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default Home

