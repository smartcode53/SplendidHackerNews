# UI/UX Designer Memory

## Design System Patterns

### Color Palette
- `Color("BackgroundColor")` — main background color
- `Color("CardColor")` — card and panel backgrounds
- `.accentColor` — teal/green primary accent color
- `Color.primary.opacity(0.06)` — subtle background pills for emphasis
- `Color.primary.opacity(0.08)` — subtle borders and dividers
- `.secondary` — secondary text color
- `.ultraThinMaterial` — glass-like backgrounds for floating UI

### Component Patterns
- **Cards**: `RoundedRectangle(cornerRadius: 12, style: .continuous)` for all card shapes
- **Pills**: `Capsule()` for tag-like elements and buttons
- **Borders**: 1px stroke with `Color.primary.opacity(0.08)`
- **Spacing**: 16px base unit for indentation, 8px for vertical spacing between siblings
- **Typography Hierarchy**:
  - `.title3.weight(.semibold)` for section headers
  - `.callout.weight(.semibold)` for meta info (author names)
  - `.subheadline` for body text
  - `.caption` for secondary/tertiary info

### Animation Standards
- **Duration**: 0.2s for micro-interactions (collapse/expand), 0.25s for transitions
- **Easing**: `.easeOut` for UI state changes, `.easeInOut` for transitions
- **Properties**: Animate `opacity`, `rotationEffect`, and SwiftUI state changes; avoid animating layout properties directly

### Comments Thread Design
- **Thread indicators**: Tappable colored vertical lines (3px width, 16px touch target) on left side of nested comments
- **Thread colors**: Cycle through blue, purple, green, orange, pink, cyan (60% opacity) based on nesting depth
- **Indentation**: 16px per nesting level
- **Collapsed state**: Shows author name in pill + reply count + chevron
- **Expanded state**: Shows meta row (author pill, time, actions) + comment text + child comments
- **Author display**: Name in `.primary.opacity(0.06)` capsule background for visual hierarchy

## UX Patterns

### Affordances & Feedback
- Always provide visual feedback for interactive elements
- Use subtle background changes on hover/press states
- Chevron rotation indicates collapsed/expanded state
- Thread lines are tappable throughout their entire height

### Visual Hierarchy
- Primary actions use solid backgrounds or accent colors
- Secondary actions use `.secondary` text color
- Tertiary information uses smaller font sizes and reduced opacity

### Accessibility Considerations
- All interactive elements have minimum 44x44pt tap targets (thread lines use 16px width but full height)
- Color is not the only indicator (chevrons, text labels also convey state)
- `.accessibilityIdentifier` preserved for testing

## File Organization
- `/HackerNewsApp/Views/TabView/ContentView/Subviews/` — view components
- `/HackerNewsApp/ViewModels/` — view models and business logic
- `/HackerNewsApp/Models/` — data models
- `/HackerNewsApp/Other/Assets.xcassets/` — color assets and design tokens

## Known Issues & Solutions
- **Recursive comment trees**: Use recursive `SingleCommentView` with `indentLevel + 1` pattern — works correctly for unlimited nesting
- **LazyVStack performance**: Always use `LazyVStack` with `.id()` for scroll position restoration in long comment threads
- **Search visibility**: Use `isVisible()` check from ViewModel to filter comments without breaking tree structure
