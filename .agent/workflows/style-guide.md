---
description: Apply the E-DAV Premium UI and Loading Screen to a React page
---

Follow these steps to upgrade any React component to the "E-DAV Premium" standard:

### 1. Integration of LoadingScreen
Every page that fetches data MUST use the `LoadingScreen` component for its initial state.
- **Import**: `import LoadingScreen from '../components/LoadingScreen';`
- **Usage**:
```jsx
if (loading && !user) {
    return <LoadingScreen message="[Context Specific Message]..." />;
}
```

### 2. Standard Layout Structure
All student pages must follow this nested structure to ensure the Sidebar and Header are correctly positioned:
```jsx
<div className="student-dashboard">
    <Sidebar />
    <div className="main-content-wrapper">
        <header className="dashboard-header">
            <div className="header-content">
                <h1>[Page Title]</h1>
                {/* Optional filters or controls */}
            </div>
        </header>
        <main className="dashboard-main">
            {/* Page Content Here */}
        </main>
    </div>
</div>
```

### 3. Visual Styling (CSS)
Use these variables and patterns in the page's `.css` file:
- **Card Background**: `background: white;`
- **Border Radius**: `border-radius: 20px;`
- **Primary Color**: `#667eea` (Indigo)
- **Primary Shadow**: `0 10px 30px rgba(0, 0, 0, 0.05)`
- **Hover Lift**: 
```css
.card:hover {
    transform: translateY(-8px);
    box-shadow: 0 20px 40px rgba(102, 126, 234, 0.15);
}
```

### 4. Color Palette
- **Text Primary**: `#1e293b`
- **Text Secondary**: `#64748b`
- **Background Main**: `#f8fafc`
- **Brand Gradient**: `linear-gradient(135deg, #667eea 0%, #764ba2 100%)`

### How to trigger this:
User can say: *"Apply the Style Guide workflow to the [Component Name] page"*
