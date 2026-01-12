#pragma once

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

@class SSKnob;

@interface DeliVerbView : NSView

- (void)setParameterTree:(AUParameterTree *)parameterTree;

@end
