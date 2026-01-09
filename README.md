# E-DAV: Electronic Digital Attendance Verification

E-DAV is a state-of-the-art, AI-powered attendance management and verification system designed to streamline lecture tracking and ensure the integrity of student presence through advanced digital analysis.

## 🚀 Key Features

### 👨‍🎓 For Students
- **Smart Attendance**: Upload proof of presence (lecture notes/assignments) during live lectures.
- **Attendance Overview**: Interactive calendar and subject-wise attendance analytics.
- **Digital Appeals**: Submit appeals for attendance corrections with attached evidence.


### 👩‍🏫 For Teachers
- **Live Lecture Control**: Start, close, and manage lecture instances in real-time.
- **Bulk Absence Management**: Quickly mark students as absent using their usernames.
- **AI-Powered Verification**: 
  - **OCR Integration**: Automatically extract text from student submissions.
  - **Plagiarism Detection**: Vector-based similarity search to identify copied content.
  - **AI Detection**: Identifies AI-generated content in student submissions.
- **In-depth Analysis**: Detailed dashboards for viewing attendance trends and resolving appeals with AI-backed data.
- **Teacher AI Assistant**: Dedicated chatbot to help teachers analyze class performance and attendance data.
- **Attendance Management**: Manually mark attendance or override AI decisions.

## 🛠️ Tech Stack

- **Frontend**: React.js, Vite, Axios, React Router, CSS Modules.
- **Backend**: FastAPI (Python), Uvicorn.
- **Database & Storage**: Supabase (PostgreSQL with Vector extensions, Supabase Auth, Supabase Storage).
- **AI Engines**: 
  - **Google Gemini API**: For intelligent reasoning and tutoring.
  - **Groq Cloud API**: For high-speed AI content analysis.
  - **Embeddings**: Vector embeddings for high-precision similarity searches.

## ⚙️ Getting Started

### Prerequisites
- Python 3.8+
- Node.js 16+
- Supabase Account

### 1. Project Setup
Clone the repository and install dependencies:

**Backend:**
```bash
cd Back-End
pip install -r requirements.txt
```

**Frontend:**
```bash
cd Front-End
npm install
```

### 2. Environment Configuration
Create a `.env` file in the `Back-End` directory and add the following:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_JWT_SECRET=your_jwt_secret
GEMINI_API_KEY=your_gemini_api_key
GROQ_API_KEY=your_groq_api_key
```

### 3. Running the Application

**Start Backend:**
```bash
cd Back-End
uvicorn main:app --reload --port 8000
```

**Start Frontend:**
```bash
cd Front-End
npm run dev
```

The application will be available at `http://localhost:5173`.

## 📂 Project Structure
- `/Back-End`: Python FastAPI server, AI processors, and database logic.
- `/Front-End`: React application with modern UI/UX for students and teachers.
- `/Back-End/processors`: Core AI logic for OCR, embeddings, and similarity checking.

## 🛡️ License
Distributed under the MIT License.

---
*Developed with ❤️ for educational excellence.*
