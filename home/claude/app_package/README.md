# Flutter WebView Manager

A complete Flutter Android app with:
- **Login screen** with JWT authentication
- **Full-screen WebView** with JavaScript enabled and a Flutter↔JS bridge
- **File manager** to list, open, and delete uploaded HTML files
- **Node.js backend** with file upload, JWT auth, and static file serving

---

## Project Structure

```
flutter_webview_app/
├── flutter_app/          # Flutter Android app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart       # Login + server URL config
│   │   │   ├── home_screen.dart        # File list + upload
│   │   │   └── webview_screen.dart     # Full-screen WebView
│   │   ├── services/
│   │   │   └── api_service.dart        # All API calls + local storage
│   │   └── utils/
│   │       └── app_theme.dart          # App-wide theme
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml
│   └── pubspec.yaml
└── backend/              # Node.js Express API
    ├── server.js
    ├── routes/
    │   ├── auth.js       # Login + JWT verify
    │   └── files.js      # Upload / list / delete HTML files
    ├── uploads/          # Uploaded HTML files stored here
    └── package.json
```

---

## Backend Setup

### Requirements
- Node.js 18+

### Install & Run

```bash
cd backend
npm install

# (Optional) Copy and edit .env
cp .env.example .env

node server.js
```

The server starts at `http://0.0.0.0:3000`.

### Default Credentials

| Username | Password   | Role   |
|----------|-----------|--------|
| admin    | admin123  | admin  |
| viewer   | viewer123 | viewer |

**Admins** can upload and delete files.  
**Viewers** can only browse and view files.

### To change a password

```bash
node -e "const b=require('bcryptjs'); b.hash('newpassword',10).then(h=>console.log(h))"
```
Paste the output into `routes/auth.js` → `USERS` array.

### API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/login` | None | Login, get JWT |
| POST | `/api/auth/verify` | None | Verify JWT |
| GET | `/api/files` | User | List all HTML files |
| POST | `/api/files/upload` | Admin | Upload HTML file |
| DELETE | `/api/files/:filename` | Admin | Delete file |
| GET | `/api/files/:filename/content` | User | Get raw HTML |
| GET | `/html/:filename` | None | Serve HTML file |
| GET | `/api/health` | None | Health check |

---

## Flutter App Setup

### Requirements
- Flutter 3.10+
- Android SDK
- Android device or emulator

### Install

```bash
cd flutter_app
flutter pub get
flutter run
```

### Configuration

1. On the **login screen**, tap the ⚙️ icon (top-right)
2. Enter your backend server URL, e.g.:
   - Same machine: `http://10.0.2.2:3000` (Android emulator)
   - LAN device: `http://192.168.1.XX:3000`
   - Cloud server: `https://yourserver.com`
3. Tap **Test** to verify connection, then **Save**

### Build APK

```bash
cd flutter_app
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

---

## Features

### Login Screen
- Username + password form with validation
- Persistent session (JWT stored locally)
- Server URL configuration with connection test
- Animated UI

### Home Screen
- Lists all uploaded HTML files from the backend
- Pull-to-refresh
- File size and upload date
- Upload button (admin only) — picks `.html` files from device storage
- Delete button (admin only) with confirmation
- Logout + server settings in menu

### WebView Screen
- Full-screen WebView with JavaScript enabled
- Progress indicator during page load
- Fullscreen toggle (hide/show app bar)
- Back/Forward navigation
- Reload button
- Error state with retry
- **Flutter↔JS Bridge**: HTML pages can call  
  `window.FlutterBridge.postMessage('{"action":"close"}')` to send messages to the app

### JS Bridge Example

In your HTML file, add:
```html
<button onclick="window.FlutterBridge.postMessage('Hello from HTML!')">
  Send to Flutter
</button>
```

---

## Production Checklist

- [ ] Change `JWT_SECRET` in `.env`
- [ ] Replace in-memory users with a real database (PostgreSQL / MongoDB)
- [ ] Add HTTPS (use nginx + Let's Encrypt)
- [ ] Remove `android:usesCleartextTraffic="true"` from AndroidManifest.xml
- [ ] Set `flutter build apk --release` signing config
- [ ] Restrict CORS origins in `server.js`
