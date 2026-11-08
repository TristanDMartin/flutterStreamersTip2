# Cross-Platform Design System (iOS + Android)

This design system provides adaptive components that automatically use the appropriate platform conventions:
- **iOS**: Cupertino widgets with SF Pro typography and Apple HIG standards
- **Android**: Material Design 3 widgets with Roboto typography

## Core Files

### `apple_material_design_system.dart`
Central design tokens and constants:
- **Spacing**: 8pt grid system (4, 8, 12, 16, 24, 32, 48)
- **Typography**: iOS (SF Pro) and Android (Roboto) text styles
- **Touch Targets**: 44pt (iOS) / 48dp (Android)
- **Corner Radius**: Platform-specific values
- **Elevation/Shadows**: Subtle for iOS, defined for Android

### `adaptive_widgets.dart`
Reusable adaptive components:
- `AdaptiveButton` - Buttons with 5 types (filled, tinted, gray, text, destructive)
- `AdaptiveActivityIndicator` - Loading spinners
- `AdaptiveCard` - Container with platform shadows
- `AdaptiveListTile` - List items
- `AdaptiveDivider` - Separators
- `AdaptiveSearchBar` - Search fields

### `adaptive_scaffold.dart`
Page-level layouts:
- `AdaptiveScaffold` - Basic page structure
- `AdaptivePage` - Large title (iOS) / Standard (Android)
- `AdaptiveSliverAppBar` - Collapsible app bars

## Usage Examples

### Buttons

```dart
// Primary filled button
AdaptiveButton(
  onPressed: () {},
  type: AdaptiveButtonType.filled,
  child: Text('Submit'),
)

// Secondary tinted button
AdaptiveButton(
  onPressed: () {},
  type: AdaptiveButtonType.tinted,
  child: Text('Cancel'),
)

// Destructive button
AdaptiveButton(
  onPressed: () {},
  type: AdaptiveButtonType.destructive,
  child: Text('Delete'),
)
```

### Cards

```dart
AdaptiveCard(
  onTap: () {},
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Title', style: AppleMaterialDesign.headlineStyle(context)),
      SizedBox(height: AppleMaterialDesign.space8),
      Text('Description', style: AppleMaterialDesign.bodyStyle(context)),
    ],
  ),
)
```

### Scaffolds

```dart
// With large title (iOS) / standard app bar (Android)
AdaptivePage(
  title: 'Settings',
  child: ListView(
    children: [
      // Content here
    ],
  ),
)
```

### Lists

```dart
AdaptiveListTile(
  leading: Icon(Icons.person),
  title: Text('Profile'),
  subtitle: Text('Edit your profile'),
  trailing: Icon(Icons.chevron_right),
  onTap: () {},
  showChevron: true,
)
```

### Loading & Empty States

```dart
// Loading indicator
AdaptiveLoadingIndicator(
  message: 'Loading...',
)

// Empty state
AdaptiveEmptyState(
  icon: Icons.inbox,
  title: 'No Messages',
  message: 'Start a conversation with someone',
  actionLabel: 'New Message',
  onActionTap: () {},
)

// Error state
AdaptiveErrorState(
  error: 'Failed to load data',
  onRetry: () {},
)
```

### Chat/Messages

```dart
// Message bubble
AdaptiveMessageBubble(
  message: 'Hello!',
  isMe: true,
  timestamp: '2:45 PM',
  showAvatar: true,
  avatarUrl: 'https://...',
)

// Chat input
AdaptiveChatInput(
  controller: _controller,
  onSend: () {},
  placeholder: 'Message',
)
```

## Spacing System

Use the 8-point grid for all spacing:

```dart
// Small spacing
padding: EdgeInsets.all(AppleMaterialDesign.space8)

// Standard padding
padding: EdgeInsets.all(AppleMaterialDesign.paddingMedium) // 16

// Between items
SizedBox(height: AppleMaterialDesign.space12)

// Section breaks
SizedBox(height: AppleMaterialDesign.space24)
```

## Typography

Use adaptive text styles:

```dart
Text('Large Title', style: AppleMaterialDesign.largeTitleStyle(context))
Text('Title', style: AppleMaterialDesign.title2Style(context))
Text('Headline', style: AppleMaterialDesign.headlineStyle(context))
Text('Body', style: AppleMaterialDesign.bodyStyle(context))
Text('Caption', style: AppleMaterialDesign.captionStyle(context))
```

## Platform Detection

```dart
if (AppleMaterialDesign.isIOS) {
  // iOS-specific code
} else {
  // Android-specific code
}
```

## Touch Targets

Always ensure minimum touch target sizes:

```dart
// Adaptive touch target (44pt iOS / 48dp Android)
minimumSize: Size(0, AppleMaterialDesign.touchTarget)
```

## Safe Areas

Respect platform safe areas:

```dart
// Get safe area insets
final safeArea = AppleMaterialDesign.safeAreaPadding(context);

// Just bottom
final bottomInset = AppleMaterialDesign.safeAreaBottom(context);
```

## Design Principles

1. **Platform Native**: Each platform gets its native look and feel
2. **Consistent Spacing**: 8pt grid system on both platforms
3. **Appropriate Feedback**: Haptics on both platforms
4. **Accessibility**: Minimum touch targets and Dynamic Type support
5. **Performance**: Optimized for 60fps on both platforms

## Components to Avoid Changing

The following components use custom designs and should not be modified:
- `ProfileViewOptimized`
- `StreamerCardView`
- `ProfileBackView`
- `StreamerCardSections`
