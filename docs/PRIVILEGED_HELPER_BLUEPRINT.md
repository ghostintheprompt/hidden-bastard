# Hidden Bastard: Privileged Helper Tool Blueprint

To clean system-level caches and perform operations requiring root permissions without repeated password prompts, you need a `launchd` Privileged Helper Tool.

## 1. Project Structure
- **Main App:** `com.hiddenbastard.app`
- **Helper Tool:** `com.hiddenbastard.helper`

## 2. Implementation Steps

### A. Create the Helper Tool
1. Add a new "Command Line Tool" target to your Xcode project.
2. Embed the helper tool in the main app's `Contents/Library/LaunchServices` directory.

### B. SMJobBless
Use the `ServiceManagement` framework to install the helper tool:
```swift
let authRef = AuthorizationRef(...)
var error: Unmanaged<CFError>?
let success = SMJobBless(kSMDomainSystemLaunchd, "com.hiddenbastard.helper" as CFString, authRef, &error)
```

### C. XPC Communication
Implement an XPC listener in the helper tool to receive commands from the main app.
```swift
// Helper Tool main.swift
let listener = NSXPCListener(machServiceName: "com.hiddenbastard.helper")
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
```

### D. Security Requirements
Both the main app and the helper tool must be signed with the same Team ID. The `Info.plist` of the helper tool must contain:
- `SMAuthorizedClients`: An array of code signing requirements for the main app.
- `SMPrivilegedExecutables`: (In main app's Info.plist) the helper tool's identifier.

## 3. Functionality
The helper tool will perform:
- `rm -rf /Library/Caches/*`
- `rm -rf /Library/Logs/*`
- System-wide temporary file cleanup.

## 4. App Store Compliance
**Warning:** Privileged helper tools are NOT allowed in the Mac App Store. If you plan to distribute via the App Store, you must stick to the App Sandbox and user-selected folders. This blueprint is for **Direct Distribution** (Developer ID signed) versions only.
