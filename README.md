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
	 - Theme toggle: The Settings screen now includes an "Appearance" control (System / Dark). Choosing "System" will follow the device appearance; choosing "Dark" forces the app into dark mode with the red/black styling.
	 - Design assets: I added simple mockups you can use or replace:
		 - `Design/app_icon.svg` — 1024×1024 red/black app icon mockup (SVG).
		 - `Design/launch_screen.svg` — simple launch image (1200×627 SVG).
		 - `LaunchScreen.storyboard` — minimal black launch storyboard with red title.

	How to import into Xcode

	1. Open your project in Xcode.
	2. To add the app icon: open `Assets.xcassets`, create a new App Icon set (if missing), and import PNGs generated from `Design/app_icon.svg` at the required sizes (or export PNGs from the SVG in Preview/Sketch/Illustrator). Xcode requires specific sizes; exporting from the SVG at 1024, 512, 180, 120, 76, etc., is typical.
	3. For the launch screen: replace the project's Launch Screen with the provided `LaunchScreen.storyboard` (Project Settings -> General -> Launch Screen File) or import `Design/launch_screen.svg` as an image and reference it inside the storyboard.
	4. Replace these mockups with polished assets when ready. The provided SVGs are editable and intended as placeholders to match the red/black theme.
5. Build & run on a real device (MapKit and background location work best on-device).

Notes & next steps

- This is a focused prototype to bootstrap development; production apps should handle more edge cases, privacy flows, and background delivery reliability.
- To turn this into a released product, create a polished UI, add robust background handling, and integrate with Apple/Google accounts as needed.

