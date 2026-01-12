#pragma once

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface SSButton : NSView

@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSColor *onColor;
@property (nonatomic, strong) NSColor *offColor;
@property (nonatomic, copy) void (^onToggle)(BOOL isOn);

- (instancetype)initWithFrame:(NSRect)frame title:(NSString *)title;

@end
