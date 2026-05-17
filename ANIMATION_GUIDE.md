# Minaret Premium Animation Guide

This guide provides comprehensive documentation for all premium animation components and utilities added to enhance the Minaret app with smooth, professional animations and micro-interactions.

## 📦 Dependencies Added

The following animation packages have been added to `pubspec.yaml`:

```yaml
# Premium Animations & Interactions
animations: ^2.0.11
lottie: ^3.1.2
flutter_staggered_animations: ^1.1.1
flutter_animate: ^4.5.0
rive: ^0.13.13
simple_animations: ^5.0.2
supercharged: ^2.1.1
```

## 🎨 Animation Constants & Utilities

### File: `lib/core/animation_constants.dart`

#### AppAnimations Class
Centralized animation constants and helper methods for consistent animations throughout the app.

**Duration Constants:**
- `fast` - 150ms (quick interactions)
- `medium` - 280ms (standard transitions)
- `slow` - 450ms (deliberate animations)
- `slower` - 650ms (emphasis animations)
- `extraSlow` - 900ms (loading/hero animations)

**Curve Constants:**
- `easeOut`, `easeInOut`, `easeOutCubic`, `easeInOutCubic`
- `easeOutBack`, `easeInOutBack`, `easeOutQuart`
- `bounceOut`, `elasticOut`

**Common Animation Methods:**
```dart
// Create animation controller
AnimationController controller = AppAnimations.createController(vsync);

// Common animations
Animation<double> fadeIn = AppAnimations.fadeIn(controller);
Animation<double> scaleIn = AppAnimations.scaleIn(controller);
Animation<Offset> slideIn = AppAnimations.slideInFromLeft(controller);

// Staggered delays
Duration delay = AppAnimations.staggeredDelay(index);
```

#### MicroInteractions Class
Pre-built micro-interaction widgets for buttons and cards.

#### PageTransitions Class
Custom page transition builders for consistent navigation animations.

#### LoadingAnimations Class
Skeleton loading and pulsing indicators.

## 🎯 Premium Components

### 1. PremiumButton
**File:** `lib/widgets/premium_button.dart`

A premium animated button with multiple styles, loading states, and micro-interactions.

**Usage:**
```dart
PremiumButton(
  text: 'Continue',
  onPressed: () => print('Button pressed'),
  type: ButtonType.primary,
  isLoading: false,
  icon: Icons.arrow_forward,
)
```

**Button Types:**
- `primary` - Emerald gradient with white text
- `secondary` - Transparent with colored border
- `gold` - Gold gradient with dark text

**Features:**
- Shimmer effect on press
- Scale animation feedback
- Loading spinner state
- Haptic feedback
- Custom colors and sizing

### 2. PremiumCard
**File:** `lib/widgets/premium_card.dart`

An animated card component with hover effects, glow animations, and multiple styles.

**Usage:**
```dart
PremiumCard(
  onTap: () => print('Card tapped'),
  type: CardType.glass,
  enableGlow: true,
  child: Text('Card content'),
)
```

**Card Types:**
- `glass` - Semi-transparent with glass effect
- `solid` - Opaque with solid background
- `gradient` - Gradient background

**Features:**
- Hover scale animation
- Press feedback
- Glow effects
- Glass morphism support

### 3. AnimatedListTile
**File:** `lib/widgets/premium_card.dart`

Premium list tile with animations and custom styling.

**Usage:**
```dart
AnimatedListTile(
  leadingIcon: Icons.home,
  title: 'Home',
  subtitle: 'Return to home screen',
  onTap: () => navigateToHome(),
  showDivider: true,
)
```

### 4. Premium Loading Components
**File:** `lib/widgets/premium_loading.dart`

#### PremiumLoadingScreen
Full-screen loading with multiple animation types.

**Usage:**
```dart
PremiumLoadingScreen(
  message: 'Loading your data...',
  type: LoadingType.pulse,
)
```

**Loading Types:**
- `pulse` - Pulsing circle animation
- `rotation` - Rotating square animation
- `shimmer` - Shimmer effect
- `dots` - Animated dots

#### SkeletonCard & SkeletonList
Skeleton loading placeholders for content.

**Usage:**
```dart
SkeletonCard(
  width: double.infinity,
  height: 80.h,
  borderRadius: 12,
)

SkeletonList(
  itemCount: 5,
  itemHeight: 80.h,
)
```

### 5. Swipeable Components
**File:** `lib/widgets/swipeable_card.dart`

#### SwipeableCard
Card with swipe gesture support and visual feedback.

**Usage:**
```dart
SwipeableCard(
  onSwipeLeft: () => deleteItem(),
  onSwipeRight: () => archiveItem(),
  onTap: () => openItem(),
  child: CardContent(),
)
```

**Features:**
- Swipe detection with configurable threshold
- Visual feedback during swipe
- Haptic feedback
- Custom swipe directions

#### SwipeableListTile
List tile with swipe gestures and hints.

**Usage:**
```dart
SwipeableListTile(
  title: 'Email Item',
  subtitle: 'Swipe to actions',
  onSwipeLeft: () => delete(),
  onSwipeRight: () => archive(),
  showSwipeHint: true,
)
```

#### PullToRefreshContainer
Pull-to-refresh functionality with custom animations.

**Usage:**
```dart
PullToRefreshContainer(
  onRefresh: () => refreshData(),
  refreshThreshold: 80.0,
  child: ListView(...),
)
```

### 6. Hero Animations & Transitions
**File:** `lib/widgets/hero_animations.dart`

#### HeroContainer
Hero widget with custom flight animations and effects.

**Usage:**
```dart
HeroContainer(
  tag: 'profile_image',
  child: Image.asset('profile.jpg'),
  borderRadius: BorderRadius.circular(50),
)
```

#### AnimatedPageRoute
Custom page route with multiple transition types.

**Usage:**
```dart
Navigator.of(context).push(
  AnimatedPageRoute(
    child: NextPage(),
    transitionType: TransitionType.slideAndFade,
    transitionDuration: AppAnimations.medium,
  ),
)
```

**Transition Types:**
- `slideAndFade` - Combined slide and fade
- `fade` - Simple fade transition
- `scale` - Scale in/out transition
- `slideFromBottom` - Slide up from bottom

#### AnimatedBottomSheet
Bottom sheet with smooth animations and gestures.

**Usage:**
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => AnimatedBottomSheet(
    child: SheetContent(),
    isDraggable: true,
    maxHeight: 400.h,
  ),
)
```

#### StaggeredAnimationList
List with staggered entrance animations.

**Usage:**
```dart
StaggeredAnimationList(
  children: [
    ItemWidget1(),
    ItemWidget2(),
    ItemWidget3(),
  ],
  staggerDelay: Duration(milliseconds: 100),
  direction: Axis.vertical,
)
```

#### PremiumDialog
Custom dialog with animations and type-based styling.

**Usage:**
```dart
showDialog(
  context: context,
  builder: (context) => PremiumDialog(
    title: 'Success!',
    subtitle: 'Operation completed successfully',
    type: DialogType.success,
    content: Text('Your changes have been saved.'),
    actions: [
      PremiumButton(text: 'OK', onPressed: () => Navigator.pop(context)),
    ],
  ),
)
```

**Dialog Types:**
- `info` - Gold theme with info icon
- `success` - Green theme with check icon
- `warning` - Orange theme with warning icon
- `error` - Red theme with error icon

## 🔄 Enhanced Existing Components

### Prayer Tracker Card
Enhanced with premium animations including:
- Staggered entrance animations for prayer items
- Smooth scale and fade transitions
- Haptic feedback on interactions
- Animated state changes with spring physics

### Main Navigation
Improved navigation with:
- Smooth page transitions
- Animated navigation bar entrance
- Scale feedback on tab selection
- Animated icon and text transitions

## 🎯 Best Practices

### 1. Consistent Timing
Use the predefined duration constants for consistent animation timing:
```dart
// Good
duration: AppAnimations.medium

// Avoid
duration: Duration(milliseconds: 283)
```

### 2. Appropriate Curves
Choose curves that match the animation purpose:
- `easeOutCubic` for natural motion
- `easeOutBack` for emphasis
- `bounceOut` for playful interactions

### 3. Haptic Feedback
Add haptic feedback for user interactions:
```dart
HapticFeedback.lightClick();  // Light interactions
HapticFeedback.mediumClick(); // Medium interactions
HapticFeedback.heavyClick();  // Heavy interactions
```

### 4. Performance Considerations
- Use `SingleTickerProviderStateMixin` for single animations
- Dispose animation controllers properly
- Avoid complex animations on large lists

### 5. Accessibility
- Respect user's motion preferences
- Provide alternative feedback for reduced motion
- Maintain appropriate contrast ratios

## 🚀 Quick Start Examples

### Basic Premium Button
```dart
PremiumButton(
  text: 'Get Started',
  onPressed: () => navigateToNextScreen(),
  type: ButtonType.primary,
)
```

### Animated List
```dart
StaggeredAnimationList(
  children: items.map((item) => 
    PremiumCard(
      onTap: () => selectItem(item),
      child: ListTile(title: Text(item.name)),
    )
  ).toList(),
)
```

### Loading State
```dart
PremiumLoadingOverlay(
  isLoading: _isLoading,
  loadingMessage: 'Fetching data...',
  child: YourContent(),
)
```

### Swipe Actions
```dart
SwipeableListTile(
  title: notification.title,
  subtitle: notification.body,
  onSwipeRight: () => markAsRead(notification),
  onSwipeLeft: () => deleteNotification(notification),
)
```

## 🎨 Theming Integration

All components automatically integrate with the existing Minaret theme system:
- Respect light/dark mode
- Use theme colors (emerald, gold, onyx)
- Maintain consistent typography
- Support RTL languages

## 📱 Platform Considerations

### iOS
- Use `easeOutCubic` curves for natural motion
- Implement haptic feedback appropriately
- Follow iOS animation guidelines

### Android
- Use material motion principles
- Respect animation performance settings
- Implement proper ripple effects

### Web
- Optimize for mouse interactions
- Implement hover states
- Consider reduced motion preferences

## 🔧 Customization

### Custom Animation Curves
```dart
static const Curve customCurve = Cubic(0.4, 0.0, 0.2, 1.0);
```

### Custom Button Styles
Extend `ButtonType` enum and update `_getButtonColors` method.

### Custom Card Effects
Modify `_getCardStyle` method for new visual styles.

## 🐛 Troubleshooting

### Animation Not Playing
- Check controller initialization
- Verify `forward()` is called
- Ensure widget is still mounted

### Performance Issues
- Reduce animation complexity
- Use `RepaintBoundary` for expensive widgets
- Profile with Flutter DevTools

### Haptic Feedback Not Working
- Check device capabilities
- Ensure proper imports
- Test on physical devices

## 📚 Additional Resources

- [Flutter Animation Documentation](https://flutter.dev/docs/development/ui/animations)
- [Material Motion Guidelines](https://material.io/design/motion/)
- [iOS Human Interface Guidelines - Animations](https://developer.apple.com/design/human-interface-guidelines/ios/app-architecture/anatomy-and-key-phases/)

---

This animation system provides a solid foundation for premium, professional animations throughout the Minaret app. All components are designed to be reusable, performant, and accessible while maintaining the app's elegant aesthetic.
