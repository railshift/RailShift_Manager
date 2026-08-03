# RailShift Manager

**"Keeping Railways on Track, One Shift at a Time"**

A comprehensive Flutter application for railway crew management and duty assignment tracking. RailShift Manager streamlines the complex process of managing train crew schedules, monitoring duty hours, and ensuring compliance with railway safety regulations.

## Features

- **Crew Management**: Track guards, loco pilots, and assistants with their roles and availability status
- **Duty Assignment**: Create and manage train duty assignments with real-time tracking
- **Safety Compliance**: Monitor duty hours with alerts for approaching and exceeded limits (8-9 hour thresholds)
- **Smart Notifications**: Automated duty reminders at 7, 8, 9, 11, and 14 hours with clickable navigation to duty details
- **Real-time Dashboard**: Live overview of active duties, crew status, and operational statistics
- **Quick Search**: Fast search across crew members, trains, and duty assignments
- **Dark/Light Theme**: Modern UI with theme switching support
- **Offline Storage**: Local data persistence using shared preferences

## Our Motto

*"Keeping Railways on Track, One Shift at a Time"* - We believe in the power of organized crew management to ensure safe, efficient, and reliable railway operations. Every shift matters, every crew member counts, and every duty assignment contributes to keeping the trains running on time.

## Technology Stack

- **Framework**: Flutter 3.7.2+
- **Language**: Dart
- **Storage**: SharedPreferences for local data persistence
- **Architecture**: Clean architecture with services, models, and screens separation
- **UI**: Material Design with custom theming

## Getting Started

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd railshift_manager
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── models/                # Data models
│   ├── crew_member.dart   # Crew member model with roles and status
│   └── duty_assignment.dart # Duty assignment model with tracking
├── screens/               # UI screens
│   ├── dashboard_screen.dart # Main dashboard with active duties
│   ├── profile_screen.dart   # User profile management
│   └── settings_screen.dart  # Application settings
├── services/              # Business logic and data services
│   └── database_service.dart # Local data management
└── theme/                 # UI theming
    └── app_theme.dart     # Custom theme definitions
```

## Key Models

### CrewMember
- Roles: Guard, Loco Pilot, Assistant
- Status: Available, On Duty, Off Duty, Sick, Leave
- Duty hour tracking with safety limits

### DutyAssignment
- Train number and route information
- Crew assignment (Guard + Loco Pilot + Optional Assistant)
- Real-time duration tracking
- Status management (Active, Completed, Overdue, Cancelled)

## Safety Features

- **8-hour Alert**: Warning when crew approaches duty time limits
- **9-hour Limit**: Critical alert for exceeded duty hours
- **Real-time Monitoring**: Continuous tracking of active duty durations
- **Status Management**: Clear visibility of crew availability and assignments

## Notification System

RailShift Manager includes a comprehensive notification system to keep crew members informed about their duty status:

### Notification Schedule
- **7 hours**: Regular duty update notification
- **8 hours**: Approaching limit warning (high priority)
- **9 hours**: Overtime alert (critical priority)
- **11 hours**: Extended duty notification
- **14 hours**: Maximum duty alert

### Features
- **Smart Timing**: Notifications sent automatically at specified duty hour milestones
- **Clickable Navigation**: Tap any notification to open the specific train duty detail page
- **Priority Levels**: Different notification priorities based on duty duration
- **Test Notifications**: Send test notifications to verify system functionality
- **Settings Control**: Configure notification preferences and timing

### Usage
1. **Automatic**: Notifications are sent automatically for all active duties
2. **Manual Testing**: Use the notification button in duty details to send test notifications
3. **Settings**: Access notification settings from the duty detail screen or main settings
4. **Navigation**: Tap any notification to instantly view the relevant duty details

### Notification Types
- 🚂 **Regular Updates**: Standard duty time notifications
- ⏰ **Approaching Limit**: Warning notifications when nearing 9-hour limit
- ⚠️ **Overtime Alerts**: High-priority alerts for duties exceeding 9 hours

## Contributing

We welcome contributions to improve RailShift Manager. Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Built with ❤️ for railway operations teams everywhere*
