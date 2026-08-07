<div align="center">

  # 🎓 Student Attendance Tracking System
  **An advanced, location-verified attendance solution built with Flutter, Firebase, and Provider.**

  [![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
  [![Material 3](https://img.shields.io/badge/Design-Material--3-7B1FA2?style=for-the-badge&logo=materialdesign&logoColor=white)](https://m3.material.io)
  [![Release](https://img.shields.io/badge/Release-v1.0.1-brightgreen?style=for-the-badge&logo=android)](https://github.com/ahmadamin5112004-ship-it/attendance-system/releases/tag/v1.0.1)

</div>

---

## 📌 Overview

**TrackAttendance** is a production-ready mobile application designed to streamline student attendance logging for university courses. By combining **real-time QR code recognition** with **GPS location geofencing**, the system ensures that attendance can only be logged by physically present students during active session windows.

Built with **Clean Architecture**, **State Management via Provider**, and a **Hybrid Firebase / Local Fallback Database Engine**, the app runs out-of-the-box on any mobile device.

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🔐 Role-Based Auth** | Authenticates students via Firebase Auth and verifies `users/{uid}` database records to reject non-student roles. |
| **📷 Camera QR Scanner** | Scans and extracts active attendance session tokens in real time using `mobile_scanner`. |
| **📍 GPS Geofencing** | Computes the physical distance (in meters) between student and instructor coordinates using `Geolocator.distanceBetween()`. |
| **🚫 Duplicate Prevention** | Checks prior submissions for `sessionId` and `studentId` to prevent duplicate attendance entries. |
| **📊 Attendance Logs** | Provides student history displaying course names, formatted timestamps, status badges (**Present**), and distance metrics. |
| **⚡ Hybrid Database Engine** | Seamlessly connects to Firebase Cloud Firestore when online, with automated fallback to local state storage when unconfigured. |

---

## 📐 System Architecture & UML Diagrams

### 1. High-Level Architecture Diagram
```mermaid
graph TD
    subgraph Client ["Flutter Mobile Client (Presentation Layer)"]
        UI["UI Screens (Login, Home, Scanner, History)"]
        Widgets["Reusable Widgets (CustomButton, InfoCard)"]
    end

    subgraph State ["State Management Layer"]
        AuthProvider["AuthProvider (Auth & User Role State)"]
        AttendanceProvider["AttendanceProvider (Scan & Verification Logic)"]
    end

    subgraph Services ["Service Layer"]
        FirebaseService["AttendanceService (Firebase & Local Store)"]
        LocationService["LocationService (GPS Permissions & Coordinates)"]
    end

    subgraph Hardware ["Hardware & External Backend"]
        Camera["Device Camera (mobile_scanner)"]
        GPS["GPS Sensor (geolocator)"]
        FirebaseAuth["Firebase Auth"]
        Firestore["Cloud Firestore / Local DB"]
    end

    UI --> AuthProvider
    UI --> AttendanceProvider
    AuthProvider --> FirebaseService
    AttendanceProvider --> FirebaseService
    AttendanceProvider --> LocationService
    LocationService --> GPS
    UI --> Camera
    FirebaseService --> FirebaseAuth
    FirebaseService --> Firestore
```

---

### 2. UML Attendance Verification Sequence Diagram
```mermaid
sequenceDiagram
    autonumber
    actor Student as Student (User)
    participant App as QRScannerScreen / UI
    participant Provider as AttendanceProvider
    participant Location as LocationService
    participant Backend as AttendanceService (Firestore)

    Student->>App: Scans QR Code
    App->>Provider: scanAndSubmitAttendance(qrToken, student)
    Provider->>Location: getCurrentLocation()
    Location-->>Provider: Returns (Latitude, Longitude)
    Provider->>Backend: getActiveSessionByToken(qrToken)
    Backend-->>Provider: Returns AttendanceSessionModel
    
    alt Session Invalid or Expired
        Provider-->>App: Throw "Invalid QR" Error
        App-->>Student: Display "Invalid QR" Dialog
    else Session Valid
        Provider->>Backend: checkDuplicateAttendance(sessionId, studentId)
        alt Attendance Already Submitted
            Backend-->>Provider: Returns true (Duplicate Found)
            Provider-->>App: Throw "Attendance already submitted" Error
            App-->>Student: Display "Attendance already submitted" Dialog
        else First-Time Submission
            Provider->>Location: calculateDistance(adminCoords, studentCoords)
            Location-->>Provider: Returns Distance (Meters)
            Provider->>Backend: submitAttendance(AttendanceRecordModel)
            Backend-->>Provider: Record Saved Successfully
            Provider-->>App: Success Confirmation
            App-->>Student: Display "Attendance Marked" & Present Badge
        end
    end
```

---

### 3. Entity-Relationship (ER) Diagram
```mermaid
erDiagram
    USERS {
        string uid PK
        string name
        string studentId
        string role
    }

    ATTENDANCE_SESSIONS {
        string sessionId PK
        string adminId FK
        string qrToken
        timestamp createdAt
        timestamp expiresAt
        double latitude
        double longitude
        boolean active
        string courseName
    }

    ATTENDANCE {
        string attendanceId PK
        string sessionId FK
        string studentId FK
        string studentName
        timestamp timestamp
        double distance
        string courseName
    }

    USERS ||--o{ ATTENDANCE : submits
    ATTENDANCE_SESSIONS ||--o{ ATTENDANCE : contains
```

---

## 🗄️ Firestore Database Structure

```
users/{uid}
├── name: string
├── studentId: string
└── role: "student"

attendance_sessions/{sessionId}
├── adminId: string
├── qrToken: string
├── createdAt: timestamp
├── expiresAt: timestamp
├── latitude: number
├── longitude: number
├── active: boolean
└── courseName: string (optional)

attendance/{attendanceId}
├── sessionId: string
├── studentId: string
├── studentName: string
├── timestamp: timestamp
├── distance: number
└── courseName: string (optional)
```

---

## 📁 Project Architecture

```
lib/
  ├── main.dart             # App initialization, Material 3 theme, and Providers
  ├── models/               # Strongly-typed data models & serialization
  │     ├── user_model.dart
  │     ├── attendance_session_model.dart
  │     └── attendance_record_model.dart
  ├── services/             # Firebase Firestore, Auth, and GPS Geolocator services
  │     ├── firebase_service.dart
  │     └── location_service.dart
  ├── providers/            # State management & reactive business logic
  │     ├── auth_provider.dart
  │     └── attendance_provider.dart
  ├── widgets/              # Reusable UI components
  │     ├── custom_button.dart
  │     └── info_card.dart
  └── screens/              # Application views
        ├── login_screen.dart
        ├── home_screen.dart
        ├── qr_scanner_screen.dart
        └── history_screen.dart
```

---

## 🚀 Getting Started & Installation

### Option 1: Direct APK Installation (Recommended)
Download and install the compiled Android release binary:
👉 **[Download APK Release (v1.0.1)](https://github.com/ahmadamin5112004-ship-it/attendance-system/releases/tag/v1.0.1)**

### Option 2: Running from Source
1. **Clone the repository:**
   ```bash
   git clone https://github.com/ahmadamin5112004-ship-it/attendance-system.git
   cd attendance-system
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run on a device or emulator:**
   ```bash
   flutter run
   ```

---

## 👥 Contributors

| Contributor Name | Student ID |
| :--- | :--- |
| **Ahmad Amin** | `2022831044` |
| **Akash Talukder** | `2023831016` |
| **Shakhawat Hossain Saikat** | `2023831008` |

---

