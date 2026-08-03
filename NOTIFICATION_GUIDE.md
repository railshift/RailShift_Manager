# RailShift Manager - Notification System Guide

## Overview
The RailShift Manager notification system provides automated duty reminders to help railway crew members stay informed about their duty status and comply with safety regulations.

## Features

### Automatic Notifications
- **7 hours**: Regular duty update
- **8 hours**: Approaching limit warning (high priority)
- **9 hours**: Overtime alert (critical priority)  
- **11 hours**: Extended duty notification
- **14 hours**: Maximum duty alert

### Smart Features
- **Clickable Navigation**: Tap any notification to open the specific duty detail page
- **Priority Levels**: Different notification priorities based on duty duration
- **Duplicate Prevention**: Avoids sending multiple notifications for the same hour
- **Test Functionality**: Send test notifications to verify system works

## How It Works

### Automatic Monitoring
1. Notifications are automatically enabled when the app starts
2. The system checks every minute for notification opportunities
3. Notifications are sent only at the specified hours (7, 8, 9, 11, 14)
4. Each notification includes current duty duration and relevant alerts

### Notification Types

#### 🚂 Regular Updates (< 8 hours)
- **Title**: "🚂 Duty Update - Train [Number]"
- **Message**: Current duty time with tap-to-view prompt
- **Priority**: Normal

#### ⏰ Approaching Limit (8-9 hours)
- **Title**: "⏰ Duty Reminder - Train [Number]"
- **Message**: Warning about approaching 9-hour limit
- **Priority**: High

#### ⚠️ Overtime Alert (9+ hours)
- **Title**: "⚠️ Overtime Alert - Train [Number]"
- **Message**: Alert about exceeding duty limits with relief suggestion
- **Priority**: Critical

## Usage Instructions

### For Crew Members

1. **Start a Duty**:
   - Notifications automatically begin monitoring when duty starts
   - You'll receive a confirmation notification

2. **Receive Notifications**:
   - Check your notification panel at the specified hours
   - Tap any notification to view detailed duty information

3. **Test Notifications**:
   - Open any duty detail screen
   - Tap the notification icon in the app bar
   - Or use the "Test" button in the notification status card

### For Administrators

1. **Notification Settings**:
   - Access via duty detail screen → menu → "Notification Settings"
   - View notification status and system information
   - Send test notifications to verify functionality

2. **Monitoring**:
   - All active duties are automatically monitored
   - No manual setup required
   - System handles multiple duties simultaneously

## Technical Details

### Permissions Required
- **POST_NOTIFICATIONS**: Required for Android 13+ devices
- **VIBRATE**: For notification vibration
- **WAKE_LOCK**: To ensure notifications work when device is sleeping

### Notification Channels
- **duty_notifications**: Main channel for duty updates
- **scheduled_duty_notifications**: For future scheduled notifications

### Data Storage
- Notification tracking is handled in memory
- No persistent storage of notification history
- Resets when app is restarted (prevents spam)

## Troubleshooting

### Notifications Not Appearing
1. **Check Permissions**:
   - Go to device Settings → Apps → RailShift Manager → Notifications
   - Ensure notifications are enabled

2. **Test Functionality**:
   - Use the test notification feature in the app
   - Check if test notifications appear

3. **Battery Optimization**:
   - Some devices may limit background activity
   - Add RailShift Manager to battery optimization whitelist

### Notifications Not Clickable
1. **Ensure App is Running**:
   - The app should be running in background for navigation to work
   - If app is closed, notification will still appear but won't navigate

2. **Check Navigation Service**:
   - The app uses a global navigation key for routing
   - Restart the app if navigation issues persist

## Best Practices

### For Crew Members
- Keep the app running in the background during duties
- Respond to overtime alerts promptly
- Use test notifications to verify system works before important duties

### For System Administrators
- Regularly test the notification system
- Monitor notification delivery during peak hours
- Ensure all devices have proper permissions configured

## Future Enhancements

### Planned Features
- **Custom Notification Hours**: Allow users to set custom reminder times
- **Scheduled Notifications**: Pre-schedule notifications for future duties
- **Notification History**: Track and display notification history
- **Sound Customization**: Custom notification sounds for different alert types

### Integration Possibilities
- **SMS Backup**: Send SMS for critical alerts when app notifications fail
- **Email Notifications**: Send email summaries for duty completion
- **Push Notifications**: Server-side push notifications for reliability

## Support

If you experience issues with notifications:
1. Try the test notification feature first
2. Check device notification settings
3. Restart the app if problems persist
4. Contact system administrator for persistent issues

---

*This notification system is designed to enhance safety and compliance in railway operations. Always follow your organization's safety protocols and procedures.*