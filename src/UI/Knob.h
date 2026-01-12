#pragma once

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SSKnob : NSView

@property (nonatomic, assign) float value;           // 0-1 normalized
@property (nonatomic, assign) float minValue;
@property (nonatomic, assign) float maxValue;
@property (nonatomic, assign) float defaultValue;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) NSColor *accentColor;
@property (nonatomic, assign) CGFloat knobSize;
@property (nonatomic, assign) BOOL showValue;
@property (nonatomic, copy) NSString *valueFormat;   // e.g., "%.1f" or "%.0f Hz"

@property (nonatomic, weak) AUParameter *parameter;
@property (nonatomic, weak) AUParameterTree *parameterTree;

- (instancetype)initWithFrame:(NSRect)frame label:(NSString *)label;
- (void)setNormalizedValue:(float)normalized;
- (float)normalizedValue;
- (void)bindToParameter:(AUParameter *)parameter tree:(AUParameterTree *)tree;

@end
