# Building

## Debug

```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Release

```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Physical Device Build

Debug (generic iOS device):
```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'generic/platform=iOS' build
```

Release (generic iOS device):
```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'generic/platform=iOS' build
```

## Verify Debug Features Are Absent In Release

- Run the Release build on a simulator.
- Open Settings and confirm there is no Debug section.
- Confirm HN Account, HN Diagnostics, Reader Preview, vote buttons, and reply actions are not reachable.
