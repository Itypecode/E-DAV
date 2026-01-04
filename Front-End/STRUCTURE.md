# Front-End Project Structure

```
Front-End/
├── public/                    # Static public files
│   └── vite.svg              # Vite logo
│
├── src/                       # Source code
│   ├── assets/               # Static assets (images, fonts, etc.)
│   │   └── .gitkeep
│   │
│   ├── components/           # Reusable UI components
│   │   ├── Layout.jsx        # Main layout wrapper with header/nav/footer
│   │   └── Layout.css        # Layout styles
│   │
│   ├── pages/                # Page components (routes)
│   │   ├── Home.jsx          # Home page with connection test
│   │   ├── Home.css
│   │   ├── Upload.jsx        # File upload page
│   │   └── Upload.css
│   │
│   ├── services/             # API service layer
│   │   ├── api.js            # Axios instance configuration
│   │   └── submissionService.js  # Submission API calls
│   │
│   ├── utils/                # Utility functions
│   │   ├── constants.js      # App constants
│   │   └── helpers.js        # Helper functions
│   │
│   ├── hooks/                # Custom React hooks
│   │   └── .gitkeep
│   │
│   ├── context/              # React context providers
│   │   └── .gitkeep
│   │
│   ├── styles/               # Global styles
│   │   └── index.css        # Global CSS reset and base styles
│   │
│   ├── App.jsx               # Main App component with routing
│   └── main.jsx              # Application entry point
│
├── .eslintrc.cjs             # ESLint configuration
├── .gitignore                # Git ignore rules
├── index.html                # HTML template
├── package.json              # Dependencies and scripts
├── vite.config.js           # Vite configuration
└── README.md                 # Project documentation
```

## Key Features

### 1. **Services Layer** (`src/services/`)
   - `api.js`: Centralized Axios instance with interceptors
   - `submissionService.js`: API functions for backend communication

### 2. **Components** (`src/components/`)
   - Reusable UI components
   - Layout component with navigation

### 3. **Pages** (`src/pages/`)
   - Route-level components
   - Home: Connection testing
   - Upload: File upload functionality

### 4. **Utils** (`src/utils/`)
   - Helper functions
   - Constants and configuration

### 5. **Routing**
   - React Router DOM for navigation
   - Configured in `App.jsx`

## API Integration

The frontend is configured to connect to your FastAPI backend:
- Default API URL: `http://localhost:3000`
- Configurable via `.env` file: `VITE_API_BASE_URL`

## Next Steps

1. Install dependencies: `npm install`
2. Create `.env` file from `.env.example`
3. Start dev server: `npm run dev`
4. Make sure your FastAPI backend has CORS middleware configured!





