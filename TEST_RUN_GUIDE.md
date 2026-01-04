# Test Run Guide

This guide will help you test run both the backend and frontend of your application.

## Prerequisites

- Python 3.8+ installed
- Node.js 16+ and npm installed
- Supabase credentials configured in your backend

## Step 1: Set Up Backend

### 1.1 Navigate to Backend Directory
```bash
cd Back-End
```

### 1.2 Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 1.3 Start the Backend Server
```bash

```

Or using uvicorn directly:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 3000
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:3000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

The backend will be running at: **http://localhost:3000**

### 1.4 Test Backend (Optional)
Open a new terminal and test the backend:
```bash
curl http://localhost:3000/test-supabase
```

Or visit in browser: http://localhost:3000/test-supabase

## Step 2: Set Up Frontend

### 2.1 Open a New Terminal Window
Keep the backend running and open a new terminal.

### 2.2 Navigate to Frontend Directory
```bash
cd Front-End
```

### 2.3 Install Node Dependencies
```bash
npm install
```

This will install all required packages (React, Vite, Axios, React Router, etc.)

### 2.4 Create Environment File (Optional)
Create a `.env` file in the `Front-End` directory:
```bash
# Windows PowerShell
New-Item -Path .env -ItemType File

# Or manually create .env file with:
VITE_API_BASE_URL=http://localhost:3000
```

**Note:** If you don't create `.env`, it will default to `http://localhost:3000`

### 2.5 Start the Frontend Development Server
```bash
npm run dev
```

**Expected Output:**
```
  VITE v5.0.8  ready in XXX ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

The frontend will be running at: **http://localhost:5173**

## Step 3: Test the Application

### 3.1 Open the Application
Open your browser and navigate to: **http://localhost:5173**

### 3.2 Test Backend Connection
1. Click on the **"Test Supabase Connection"** button on the Home page
2. You should see a success message if the backend is connected

### 3.3 Test File Upload
1. Navigate to the **Upload** page (click "Upload" in the navigation)
2. Fill in the form:
   - **User ID**: Enter any user ID (e.g., "user123")
   - **Class ID**: Enter any class ID (e.g., "class456")
   - **File**: Select an image file (JPG, PNG) or PDF
3. Click **"Upload Submission"**
4. You should see a success message with the submission ID and uploaded image preview

## Troubleshooting

### Backend Issues

**Problem: Port 3000 already in use**
```bash
# Change port in main.py or use:
uvicorn main:app --reload --port 8000
# Then update frontend .env to: VITE_API_BASE_URL=http://localhost:8000
```

**Problem: Module not found errors**
```bash
# Make sure all dependencies are installed:
pip install -r requirements.txt
```

**Problem: Supabase connection errors**
- Check your `supabase_client.py` configuration
- Verify your Supabase credentials are correct

### Frontend Issues

**Problem: npm install fails**
```bash
# Clear cache and try again:
npm cache clean --force
npm install
```

**Problem: Cannot connect to backend**
- Make sure backend is running on port 3000
- Check browser console for CORS errors
- Verify `.env` file has correct API URL

**Problem: CORS errors in browser**
- Make sure CORS middleware is configured in backend (already fixed in main.py)
- Check that backend is running

### Both Servers Running

You should have:
- **Backend**: Running on http://localhost:3000
- **Frontend**: Running on http://localhost:5173

Both terminals should be active. To stop:
- Press `Ctrl+C` in each terminal

## Quick Test Checklist

- [ ] Backend server starts without errors
- [ ] Frontend server starts without errors
- [ ] Can access http://localhost:5173 in browser
- [ ] Home page loads correctly
- [ ] "Test Supabase Connection" button works
- [ ] Upload page loads correctly
- [ ] File upload form works
- [ ] Success message appears after upload

## Next Steps

Once everything is working:
1. Customize the UI styling
2. Add more pages/features
3. Implement authentication if needed
4. Add error handling and loading states
5. Deploy to production

