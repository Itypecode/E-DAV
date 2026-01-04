import { useState } from 'react'
import { uploadSubmission } from '../services/submissionService'
import './Upload.css'

const Upload = () => {
  const [userId, setUserId] = useState('')
  const [classId, setClassId] = useState('')
  const [file, setFile] = useState(null)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)
  const [error, setError] = useState(null)

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0]
    if (selectedFile) {
      setFile(selectedFile)
      setError(null)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    setMessage(null)

    if (!userId || !classId || !file) {
      setError('Please fill in all fields and select a file')
      return
    }

    setLoading(true)

    try {
      const result = await uploadSubmission(userId, classId, file)
      setMessage({
        type: 'success',
        text: `Upload successful! Submission ID: ${result.submission_id}`,
        data: result
      })
      // Reset form
      setUserId('')
      setClassId('')
      setFile(null)
      e.target.reset()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Upload failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="upload">
      <div className="upload-header">
        <h1>Upload Submission</h1>
        <p>Submit your assignment or document</p>
      </div>

      <form onSubmit={handleSubmit} className="upload-form">
        <div className="form-group">
          <label htmlFor="userId">User ID *</label>
          <input
            type="text"
            id="userId"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="Enter your user ID"
            required
            disabled={loading}
          />
        </div>

        <div className="form-group">
          <label htmlFor="classId">Class ID *</label>
          <input
            type="text"
            id="classId"
            value={classId}
            onChange={(e) => setClassId(e.target.value)}
            placeholder="Enter class ID"
            required
            disabled={loading}
          />
        </div>

        <div className="form-group">
          <label htmlFor="file">File *</label>
          <input
            type="file"
            id="file"
            onChange={handleFileChange}
            required
            disabled={loading}
            accept="image/*,.pdf"
          />
          {file && (
            <p className="file-info">
              Selected: {file.name} ({(file.size / 1024 / 1024).toFixed(2)} MB)
            </p>
          )}
        </div>

        {error && (
          <div className="alert alert-error">
            {error}
          </div>
        )}

        {message && (
          <div className={`alert alert-${message.type}`}>
            {message.text}
            {message.data?.image_url && (
              <div className="image-preview">
                <p>Uploaded Image:</p>
                <img src={message.data.image_url} alt="Uploaded" />
              </div>
            )}
          </div>
        )}

        <button 
          type="submit" 
          className="submit-button"
          disabled={loading}
        >
          {loading ? 'Uploading...' : 'Upload Submission'}
        </button>
      </form>
    </div>
  )
}

export default Upload

