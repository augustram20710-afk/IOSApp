Context-Aware Alarm (iOS Prototype)

Overview

This prototype demonstrates a context-aware alarm approach: it reads calendar events, geocodes event locations, computes travel times using MapKit, and schedules local notifications for wake/leave times.

What is included

- `ContextAwareAlarmApp.swift`: SwiftUI `@main` app entry.
- `ContentView.swift`: Simple UI showing today's events and a map placeholder.
- `CalendarManager.swift`: Fetches events for today from EventKit.
- `LocationManager.swift`: Wraps `CLLocationManager` and geofencing helpers.
- `MapManager.swift`: Geocoding and route/travel-time estimation using MapKit.
- `AlarmManager.swift`: Computes wake/leave times and schedules local notifications.
- `Models.swift`: Small model types used by the prototype.

How to use this prototype

1. Open Xcode and create a new iOS project using "App" (SwiftUI + Swift).
2. Copy the Swift files from this folder into the new project.
3. In "Signing & Capabilities": enable `Background Modes` → check `Location updates` and enable `Uses GPS`.
4. Add the `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `NSCalendarsUsageDescription` and `NSUserTrackingUsageDescription` keys to `Info.plist` with user-facing text.
5. To enable periodic ETA refresh in the background using `BGAppRefreshTask`:
	- Add `BGTaskSchedulerPermittedIdentifiers` to `Info.plist` and include the identifier `com.example.contextalarm.refresh` (or change the identifier in `AlarmManager.swift` to match your bundle/company id).
	- Enable Background Modes → `Background fetch` in Xcode Signing & Capabilities.
	- Note: iOS decides scheduling; AppRefresh is best-effort. For stricter updates consider significant location changes or server-driven silent pushes.
	- To trigger ETA refreshes when the user moves:
		- Enable Background Modes → `Location updates` in Xcode Signing & Capabilities.
		- Ensure you request `Always` location permission (`NSLocationAlwaysAndWhenInUseUsageDescription` in `Info.plist`).
		- The app will start significant location change monitoring and trigger ETA recalculations when movement exceeds a threshold.
	 - Settings: The app now has a `Settings` screen (Preferences) to configure:
		 - `Prep time` (minutes) — how long the morning routine/buffer is before travel time is added.
		 - `Refresh distance` (meters) — how far the device must move before triggering an ETA refresh.
		 - `Transport mode` — choose between Drive/Walk/Transit; this affects route ETA calculations.
		 Settings persist via `UserDefaults` and are applied immediately.
	 - UI Theme: The prototype uses a red/black visual theme. To tweak colors change the accent color and UINavigationBar appearance in `ContextAwareAlarmApp.swift`.
5. Build & run on a real device (MapKit and background location work best on-device).

Notes & next steps

- This is a focused prototype to bootstrap development; production apps should handle more edge cases, privacy flows, and background delivery reliability.
- To turn this into a released product, create a polished UI, add robust background handling, and integrate with Apple/Google accounts as needed.

