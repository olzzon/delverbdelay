#pragma once

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

namespace DeliVerb {
namespace Theme {

// Plugin dimensions
constexpr CGFloat kPluginWidth = 400.0;
constexpr CGFloat kPluginHeight = 640.0;

// Knob sizes
constexpr CGFloat kLargeKnobSize = 60.0;
constexpr CGFloat kSmallKnobSize = 40.0;

// Spacing
constexpr CGFloat kPadding = 20.0;
constexpr CGFloat kKnobSpacing = 80.0;

// Colors - Deep blue/teal pedal style for DeliVerb
inline NSColor* backgroundColor() {
    return [NSColor colorWithRed:0.10 green:0.14 blue:0.18 alpha:1.0];
}

// Metallic gradient with deep blue tint
inline NSColor* metalGradientTop() {
    return [NSColor colorWithRed:0.25 green:0.40 blue:0.50 alpha:1.0];
}

inline NSColor* metalGradientBottom() {
    return [NSColor colorWithRed:0.15 green:0.25 blue:0.35 alpha:1.0];
}

inline NSColor* knobColor() {
    return [NSColor colorWithRed:0.14 green:0.18 blue:0.22 alpha:1.0];
}

inline NSColor* knobIndicatorColor() {
    return [NSColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}

inline NSColor* labelColor() {
    return [NSColor colorWithRed:0.88 green:0.92 blue:0.95 alpha:1.0];
}

inline NSColor* valueColor() {
    return [NSColor colorWithRed:0.60 green:0.80 blue:0.90 alpha:1.0];
}

// Primary teal/cyan accent
inline NSColor* accentColor() {
    return [NSColor colorWithRed:0.30 green:0.70 blue:0.80 alpha:1.0];
}

// Secondary accent for reverb section (warmer)
inline NSColor* reverbAccentColor() {
    return [NSColor colorWithRed:0.50 green:0.65 blue:0.75 alpha:1.0];
}

inline NSColor* shadowColor() {
    return [NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
}

inline NSColor* highlightColor() {
    return [NSColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1];
}

// Version color - discrete grey
inline NSColor* versionColor() {
    return [NSColor colorWithWhite:0.6 alpha:0.6];
}

// Fonts
inline NSFont* labelFont() {
    return [NSFont systemFontOfSize:10.0 weight:NSFontWeightMedium];
}

inline NSFont* versionFont() {
    return [NSFont systemFontOfSize:9.0 weight:NSFontWeightLight];
}

inline NSFont* valueFont() {
    return [NSFont monospacedDigitSystemFontOfSize:9.0 weight:NSFontWeightRegular];
}

inline NSFont* titleFont() {
    return [NSFont systemFontOfSize:18.0 weight:NSFontWeightBold];
}

inline NSFont* bandFont() {
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
}

} // namespace Theme
} // namespace DeliVerb
