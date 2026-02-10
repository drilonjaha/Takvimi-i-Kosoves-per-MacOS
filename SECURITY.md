# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |

## Security Features

This app implements the following security measures:

- **App Sandbox**: The app runs in a sandboxed environment with minimal permissions
- **No Network Data Collection**: Prayer times are embedded locally, no user data is sent to servers
- **No Analytics**: The app does not collect or transmit any usage data
- **Local Storage Only**: All user preferences and voice recordings are stored locally on your device
- **Minimal Entitlements**: Only requests necessary permissions:
  - Audio input (for voice reminders)
  - Network client (for potential future API features)

## Data Privacy

- **City Selection**: Stored locally in UserDefaults
- **Voice Recordings**: Stored in app's sandboxed Documents folder
- **Preferences**: Stored locally in UserDefaults
- **No Cloud Sync**: Nothing is uploaded to any server

## Reporting a Vulnerability

If you discover a security vulnerability, please report it by:

1. **Email**: Open an issue on GitHub with the label "security"
2. **Do not** disclose the vulnerability publicly until it has been addressed

We take security seriously and will respond to reports within 48 hours.

## Code Signing

The distributed app is currently unsigned (ad-hoc signed). This means:
- macOS Gatekeeper will show a warning on first launch
- Users need to right-click → Open to bypass Gatekeeper
- The app has not been notarized by Apple

For maximum security, users can build the app from source using Xcode.
