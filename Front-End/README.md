# Front-End Application

React + Vite front-end application.

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file from `.env.example`:
```bash
cp .env.example .env
```

3. Update the `.env` file with your backend API URL (default: http://localhost:8000)

4. Start the development server:
```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## Project Structure

```
Front-End/
├── src/
│   ├── components/     # Reusable UI components
│   ├── pages/          # Page components
│   ├── services/       # API service layer
│   ├── utils/          # Utility functions
│   ├── hooks/          # Custom React hooks
│   ├── context/        # React context providers
│   ├── assets/         # Static assets (images, etc.)
│   ├── styles/         # Global styles
│   ├── App.jsx         # Main App component
│   └── main.jsx        # Entry point
├── public/             # Public static files
└── package.json
```

## Features

- React 18 with Vite for fast development
- Axios for API integration
- React Router for navigation
- Clean, organized folder structure

