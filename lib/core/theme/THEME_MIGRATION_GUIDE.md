# Theme Migration Guide: Light/Dark Mode Support

## Overview

Your app now supports both light and dark themes with automatic system brightness detection. The theme system uses:
- **Dark Mode**: Dark backgrounds with light text (original design)
- **Light Mode**: Light backgrounds with dark text

The theme automatically adapts when the user changes their device system preference or when you toggle the theme in settings.

---

## How It Works

### 1. Color System Architecture

```
colors.dart
├── Dark Colors (darkBgPrimary, darkTextPrimary, etc.)
├── Light Colors (lightBgPrimary, lightTextPrimary, etc.)
└── Backwards Compatibility aliases (bgPrimary → darkBgPrimary)

brightness_colors.dart
└── Helper functions to get colors by brightness
    ├── bgPrimary(Brightness) → returns dark or light color
    ├── textPrimary(Brightness) → returns appropriate text color
    └── gold(Brightness) → returns accent color for current theme

theme.dart
└── buildTheme(Brightness) → generates full ThemeData for light or dark
```

### 2. How Brightness is Determined

Your `app.dart` gets the theme mode from `SettingsCubit`:
- If set to **Dark** → uses `Brightness.dark`
- If set to **Light** → uses `Brightness.light`
- The system UI (status bar, nav bar) automatically updates to match

---

## Updating Your Screens

### Option 1: Using Theme.of(context) (RECOMMENDED for simple cases)

The Material Design theme system automatically provides colors. Most widgets work without changes:

```dart
// ✅ NO CHANGES NEEDED - Material widgets read theme automatically
Text('Hello', style: Theme.of(context).textTheme.bodyMedium)
Icon(Icons.favorite, color: Theme.of(context).primaryColor)
Container(
  color: Theme.of(context).scaffoldBackgroundColor,
  child: child,
)
```

### Option 2: Using BrightnessColors Helper (for custom colors)

For custom widgets or when you need specific colors from the theme:

```dart
import 'package:ekklisia/core/theme/brightness_colors.dart';

class MyCustomWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    return Container(
      color: BrightnessColors.bgPrimary(brightness),
      child: Text(
        'Hello',
        style: TextStyle(color: BrightnessColors.textPrimary(brightness)),
      ),
    );
  }
}
```

### Option 3: Using EkklisiaColors Directly (for backwards compatibility)

If you prefer direct color access (defaults to dark theme):

```dart
import 'package:ekklisia/core/theme/colors.dart';

Container(
  color: EkklisiaColors.bgPrimary,  // Uses dark color
  child: Text('Hello', style: TextStyle(color: EkklisiaColors.textPrimary)),
)
```

---

## Common Patterns

### 1. Container with Dynamic Color

**Before (hard-coded dark):**
```dart
Container(
  color: Color(0xFF162535),  // ❌ Hard-coded dark color
  child: child,
)
```

**After (brightness-aware):**
```dart
Container(
  color: Theme.of(context).scaffoldBackgroundColor,  // ✅ Adapts to theme
  child: child,
)
```

### 2. Custom Text Style

**Before:**
```dart
Text(
  'Title',
  style: TextStyle(color: Color(0xFFF0E6C8)),  // ❌ Hard-coded light text
)
```

**After:**
```dart
Text(
  'Title',
  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),  // ✅ Adapts
)
// Or use EkklisiaTheme helper:
Text(
  'Title',
  style: EkklisiaTheme.bodyMediumStatic,  // Uses dark by default
)
```

### 3. Card with Dynamic Styling

**Before:**
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFF162535),  // ❌ Hard-coded
    border: Border.all(color: Color(0x59C8A84B)),
  ),
  child: child,
)
```

**After (using theme):**
```dart
Card(
  color: Theme.of(context).cardTheme.color,  // ✅ Adapts
  shape: RoundedRectangleBorder(
    side: BorderSide(color: Theme.of(context).dividerColor),
  ),
  child: child,
)
// Or using helper:
Container(
  decoration: EkklisiaTheme.byzantineCard(Theme.of(context).brightness),
  child: child,
)
```

### 4. Gradient Decorations

**Before:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: EkklisiaColors.headerGradient,  // ❌ Always dark
  ),
)
```

**After:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: BrightnessColors.headerGradient(Theme.of(context).brightness),
  ),
)
```

### 5. Building Responsive Buttons

**Before:**
```dart
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFC8A84B),  // ❌ Hard-coded gold
  ),
  child: Text('Click me'),
)
```

**After (theme automatically handles it):**
```dart
ElevatedButton(
  onPressed: () {},
  // ✅ Uses theme.primaryColor automatically
  child: Text('Click me'),
)
```

---

## Quick Reference: Color Functions

```dart
// Import this for brightness-aware colors:
import 'package:ekklisia/core/theme/brightness_colors.dart';

final brightness = Theme.of(context).brightness;

// Backgrounds
BrightnessColors.bgPrimary(brightness)      // Main background
BrightnessColors.bgDeep(brightness)         // Deep/dark background
BrightnessColors.bgMid(brightness)          // Mid-tone background
BrightnessColors.bgElevated(brightness)     // Elevated surface

// Text Colors
BrightnessColors.textPrimary(brightness)    // Main text
BrightnessColors.textSecondary(brightness)  // Secondary/muted text
BrightnessColors.textCream(brightness)      // Cream/warm text

// Accents
BrightnessColors.gold(brightness)           // Primary accent
BrightnessColors.goldLight(brightness)      // Light accent
BrightnessColors.goldDim(brightness)        // Dimmed accent
BrightnessColors.goldBorder(brightness)     // Border color

// Category Colors
BrightnessColors.maroon(brightness)
BrightnessColors.plum(brightness)
BrightnessColors.tealMid(brightness)

// Gradients
BrightnessColors.headerGradient(brightness)
BrightnessColors.bottomNavGradient(brightness)
BrightnessColors.maroonCardGradient(brightness)
BrightnessColors.plumCardGradient(brightness)
```

---

## Updating Screens: Step-by-Step

### Example: Update a BookCard Widget

**Original (dark-only):**
```dart
class BookCard extends StatelessWidget {
  final Book book;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF162535),  // Hard-coded dark
        border: Border.all(color: Color(0x59C8A84B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            book.title,
            style: TextStyle(color: Color(0xFFF0E6C8)),  // Hard-coded light
          ),
          Text(
            book.author,
            style: TextStyle(color: Color(0xFFA89060)),  // Hard-coded secondary
          ),
        ],
      ),
    );
  }
}
```

**Updated (brightness-aware):**
```dart
class BookCard extends StatelessWidget {
  final Book book;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      // ✅ Theme automatically provides cardTheme colors
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              book.title,
              // ✅ Uses theme's titleLarge which adapts to brightness
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              book.author,
              // ✅ Uses theme's bodySmall which adapts to brightness
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Common Colors to Replace

| Hard-coded Color | Replacement |
|---|---|
| `0xFF08111C` (bgDeep) | `BrightnessColors.bgDeep(brightness)` |
| `0xFF0D1B2A` (bgPrimary) | `Theme.of(context).scaffoldBackgroundColor` |
| `0xFF162535` (bgMid) | `BrightnessColors.bgMid(brightness)` |
| `0xFFF0E6C8` (textPrimary) | `Theme.of(context).textTheme.bodyMedium?.color` |
| `0xFFC8A84B` (gold) | `Theme.of(context).primaryColor` |
| `0xFFA89060` (textSecondary) | `Theme.of(context).disabledColor` |

---

## Testing Both Themes

### In Flutter:

1. **Edit app.dart and toggle themeMode manually:**
   ```dart
   themeMode: ThemeMode.light,  // Change to test light theme
   ```

2. **Use the Settings screen** to toggle between light/dark

3. **Check system settings** - if your settings cubit reads system preference, test by changing device theme

### Visual Checks:
- ✅ Text is readable on background
- ✅ Buttons are visible and clickable
- ✅ Icons match text color
- ✅ Cards have proper contrast
- ✅ Status bar matches theme (handled automatically)

---

## Troubleshooting

### Theme Not Updating?
1. Make sure you're using `Theme.of(context)` or `BrightnessColors` helpers
2. Check that `SettingsCubit` is properly updating
3. Rebuild widgets with `context.watch()` if using Provider pattern

### Colors Look Wrong?
1. Check if you're using `EkklisiaColors.bgPrimary` (always dark) vs `BrightnessColors.bgPrimary(brightness)` (adapts)
2. Ensure brightness is coming from `Theme.of(context).brightness`
3. Test with both light and dark modes enabled

### Status Bar Not Updating?
- It's automatically updated in `app.dart`'s `_updateSystemUIOverlay()` method
- Make sure this method is being called (it is, in the builder)

---

## Need to Update Screens?

1. **Audit your codebase** for hardcoded colors:
   ```bash
   grep -r "Color(0xFF" lib/features/  # Find hardcoded colors
   ```

2. **Replace with theme colors** using the patterns above

3. **Test in both modes** - light and dark

4. **Use Material widgets** where possible - they adapt automatically

Good luck! 🎨
