# A Context-Aware Adaptive Indoor Navigation System Using QR Code Anchors and Machine Learning

A scanner-based adaptive indoor navigation system designed for guiding users inside buildings using QR-code location scanning, route calculation, and voice-based navigation instructions.

This project contains two main parts:

- Backend API and admin dashboard for managing rooms, routes, and pathway images
- Flutter mobile application for scanning QR codes, selecting destinations, and receiving turn-by-turn guidance

## Project overview

The system helps users navigate complex indoor spaces such as campuses, offices, hospitals, or large buildings. A user scans a QR code at their current location, selects a destination, and the app calculates the best route using a backend graph of connected rooms and pathways. The app then shows the route and can provide spoken instructions using text-to-speech.

## Features

- QR-code based location detection
- Real-time indoor route finding between rooms
- Pathway image support for navigation guidance
- Voice directions using Flutter TTS
- Admin panel for managing navigation data
- SQLite-backed backend for local data persistence
- Mobile-friendly API for Android/iOS apps

## Tech stack

- Backend: Node.js + Express + SQLite
- Mobile app: Flutter + Dart
- Frontend admin interface: HTML + JavaScript served by Express

## Project structure

```text
indoor_navigation/
├── backend/
│   ├── .env
│   ├── package.json
│   ├── data/
│   ├── public/
│   ├── src/
│   └── pathway-images/
├── mobile_app/
│   ├── lib/
│   ├── pubspec.yaml
│   └── android/
├── README.md
└── .gitignore
```

## Requirements

Before running the project, install the following:

- Node.js 18+ recommended
- npm
- Flutter SDK 3.x
- Android Studio / Android emulator or a physical Android device
- Optional: Xcode for iOS development

## Backend setup

1. Open a terminal in the backend folder:

   ```bash
   cd backend
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Configure the server URL if needed:
   - The backend uses the values in `backend/.env`
   - `BASE_URL` defaults to `http://localhost:5000` for local development
   - Pathway image URLs automatically use the address that made the request, including a LAN IP

   Example:

   ```env
   PORT=5000
   BASE_URL=http://192.168.1.100:5000
   NODE_ENV=development
   ```

4. Start the backend server:

   ```bash
   npm run dev
   ```

   Or use:

   ```bash
   npm start
   ```

5. Verify the server is running:
   - Health check: `http://localhost:5000/health`
   - Admin panel: `http://localhost:5000/admin.html`

## Mobile app setup

1. Open a terminal in the mobile app directory:

   ```bash
   cd mobile_app
   ```

2. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

3. Update the backend IP in the app if needed for a physical mobile device.

   Open:

   ```text
   mobile_app/lib/services/api_service.dart
   ```

   Replace:

   ```dart
   const String _mobileBaseUrl = 'http://10.121.205.25:5000';
   ```

   with your local machine IP, such as:

   ```dart
   const String _mobileBaseUrl = 'http://192.168.1.100:5000';
   ```

   Important: the phone and the backend computer must be on the same Wi-Fi network.
   Flutter Web automatically uses the host from the browser URL. The app tries
   the configured IP first and falls back to `http://localhost:5000`.

4. Run the app:

   ```bash
   flutter run
   ```

   To run on a specific connected device:

   ```bash
   flutter devices
   flutter run -d <device-id>
   ```

## Typical workflow

1. Start the backend server.
2. Open the admin panel and ensure the building, rooms, and routes are configured.
3. Launch the Flutter app on a device or emulator.
4. Scan the QR code at your current indoor location.
5. Select a destination.
6. Follow the generated route and voice guidance.

## Notes

- The backend is configured to listen on `0.0.0.0`, so it can be accessed from other devices on the local network.
- If you are using an Android device, ensure your device can access the machine running the backend over the same Wi-Fi network.
- If port 5000 is blocked, update firewall settings or change the port in `.env` and `api_service.dart`.

## License

This project is currently distributed without a specific external license declaration in the repository metadata. If needed, add an appropriate license before publishing or sharing the project publicly.
