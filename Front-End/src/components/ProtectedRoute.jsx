import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { verifyToken, getCurrentUser } from '../services/authService'
import LoadingScreen from './LoadingScreen'

const ProtectedRoute = ({ children, requiredRole }) => {
  const [isValid, setIsValid] = useState(null)
  const [userRole, setUserRole] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('Token')
      if (!token) {
        setIsValid(false)
        setLoading(false)
        return
      }

      const tokenValid = await verifyToken()
      if (!tokenValid) {
        setIsValid(false)
        setLoading(false)
        return
      }

      try {
        const user = await getCurrentUser()
        setUserRole(user.role)
        if (requiredRole && user.role !== requiredRole) {
          setIsValid(false)
        } else {
          setIsValid(true)
        }
      } catch (error) {
        setIsValid(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()
  }, [requiredRole])

  if (loading) {
    return <LoadingScreen message="Verifying authentication credentials..." />
  }

  if (!isValid) {
    return <Navigate to="/" replace />
  }

  return children
}

export default ProtectedRoute
