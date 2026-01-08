import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import Login from './pages/Login'
import Student from './pages/Student'
import Teacher from './pages/Teacher'
import TeacherClassesView from './pages/TeacherClassesView'
import TeacherAttendanceView from './pages/TeacherAttendanceView'
import TeacherReport from './pages/TeacherReport'
import TeacherAppeals from './pages/TeacherAppeals'
import HelpCenter from './pages/HelpCenter'
import AttendanceView from './pages/AttendanceView'
import MySubmissions from './pages/MySubmissions'
import AppealPlaceholder from './pages/AppealPlaceholder'
import ProtectedRoute from './components/ProtectedRoute'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Login />} />
        <Route
          path="/student"
          element={
            <ProtectedRoute requiredRole="student">
              <Student />
            </ProtectedRoute>
          }
        />
        <Route
          path="/attendance"
          element={
            <ProtectedRoute requiredRole="student">
              <AttendanceView />
            </ProtectedRoute>
          }
        />
        <Route
          path="/submissions"
          element={
            <ProtectedRoute requiredRole="student">
              <MySubmissions />
            </ProtectedRoute>
          }
        />
        <Route
          path="/appeal"
          element={
            <ProtectedRoute requiredRole="student">
              <AppealPlaceholder />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher"
          element={
            <ProtectedRoute requiredRole="teacher">
              <Teacher />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher/attendance"
          element={
            <ProtectedRoute requiredRole="teacher">
              <TeacherAttendanceView />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher/classes"
          element={
            <ProtectedRoute requiredRole="teacher">
              <TeacherClassesView />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher/report/:lectureId"
          element={
            <ProtectedRoute requiredRole="teacher">
              <TeacherReport />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher/appeals"
          element={
            <ProtectedRoute requiredRole="teacher">
              <TeacherAppeals />
            </ProtectedRoute>
          }
        />
        <Route
          path="/help"
          element={
            <ProtectedRoute requiredRole="student">
              <HelpCenter role="student" />
            </ProtectedRoute>
          }
        />
        <Route
          path="/teacher/help"
          element={
            <ProtectedRoute requiredRole="teacher">
              <HelpCenter role="teacher" />
            </ProtectedRoute>
          }
        />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Router>
  )
}

export default App
