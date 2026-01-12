#import <Cocoa/Cocoa.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "DeliVerbView.h"
#import "Parameters.h"

using namespace DeliVerb;

// Bridge class that wraps AUv2 AudioUnit to work with our view's parameter binding
@interface AUv2ParameterBridge : NSObject
@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, strong) AUParameterTree *parameterTree;
@property (nonatomic, strong) NSTimer *syncTimer;
- (instancetype)initWithAudioUnit:(AudioUnit)au;
- (void)startSync;
- (void)stopSync;
@end

@implementation AUv2ParameterBridge

- (instancetype)initWithAudioUnit:(AudioUnit)au {
    self = [super init];
    if (self) {
        _audioUnit = au;
        [self createParameterTree];
    }
    return self;
}

- (void)dealloc {
    [self stopSync];
}

- (void)createParameterTree {
    NSMutableArray<AUParameter *> *parameters = [NSMutableArray array];

    for (int i = 0; i < kNumParameters; ++i) {
        const ParameterInfo& info = kParameterInfos[i];

        AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable;
        if (!info.isAdvanced) {
            flags |= kAudioUnitParameterFlag_IsHighResolution;
        }

        AUParameter *param = [AUParameterTree createParameterWithIdentifier:[NSString stringWithUTF8String:info.identifier]
                                                                       name:[NSString stringWithUTF8String:info.name]
                                                                    address:i
                                                                        min:info.minValue
                                                                        max:info.maxValue
                                                                       unit:info.unit
                                                                   unitName:nil
                                                                      flags:flags
                                                               valueStrings:nil
                                                        dependentParameters:nil];

        // Get current value from AUv2
        Float32 value = info.defaultValue;
        AudioUnitGetParameter(_audioUnit, i, kAudioUnitScope_Global, 0, &value);
        param.value = value;

        [parameters addObject:param];
    }

    // Create groups for organization
    AUParameterGroup *delayGroup = [AUParameterTree createGroupWithIdentifier:@"delay"
                                                                         name:@"Delay"
                                                                     children:@[parameters[kParamDelayTime],
                                                                                parameters[kParamDelayRepeat],
                                                                                parameters[kParamDelayMix]]];

    AUParameterGroup *reverbGroup = [AUParameterTree createGroupWithIdentifier:@"reverb"
                                                                          name:@"Reverb"
                                                                      children:@[parameters[kParamReverbSize],
                                                                                 parameters[kParamReverbStyle],
                                                                                 parameters[kParamReverbMix]]];

    AUParameterGroup *advancedGroup = [AUParameterTree createGroupWithIdentifier:@"advanced"
                                                                            name:@"Advanced"
                                                                        children:@[parameters[kParamDelayLowCut],
                                                                                   parameters[kParamDelayHighCut],
                                                                                   parameters[kParamReverbLowCut],
                                                                                   parameters[kParamReverbHighCut],
                                                                                   parameters[kParamDuckDelayAmount],
                                                                                   parameters[kParamDuckReverbAmount],
                                                                                   parameters[kParamDuckBehaviour],
                                                                                   parameters[kParamAdvanced]]];

    _parameterTree = [AUParameterTree createTreeWithChildren:@[delayGroup, reverbGroup, advancedGroup]];

    // Set up observer to forward parameter changes to AUv2
    __weak AUv2ParameterBridge *weakSelf = self;
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        AUv2ParameterBridge *strongSelf = weakSelf;
        if (strongSelf && strongSelf.audioUnit) {
            AudioUnitSetParameter(strongSelf.audioUnit,
                                  (AudioUnitParameterID)param.address,
                                  kAudioUnitScope_Global,
                                  0,
                                  value,
                                  0);
        }
    };

    _parameterTree.implementorValueProvider = ^AUValue(AUParameter *param) {
        AUv2ParameterBridge *strongSelf = weakSelf;
        if (strongSelf && strongSelf.audioUnit) {
            Float32 value = 0;
            AudioUnitGetParameter(strongSelf.audioUnit,
                                  (AudioUnitParameterID)param.address,
                                  kAudioUnitScope_Global,
                                  0,
                                  &value);
            return value;
        }
        return param.value;
    };
}

- (void)startSync {
    // Periodically sync parameter values from AUv2 to our tree
    // This handles automation and host-side changes
    __weak AUv2ParameterBridge *weakSelf = self;
    _syncTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
        AUv2ParameterBridge *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.audioUnit) {
            [timer invalidate];
            return;
        }

        for (AUParameter *param in strongSelf.parameterTree.allParameters) {
            Float32 value = 0;
            OSStatus status = AudioUnitGetParameter(strongSelf.audioUnit,
                                                    (AudioUnitParameterID)param.address,
                                                    kAudioUnitScope_Global,
                                                    0,
                                                    &value);
            if (status == noErr && param.value != value) {
                // Update without triggering observer (to avoid feedback loop)
                [param setValue:value originator:nil];
            }
        }
    }];
}

- (void)stopSync {
    [_syncTimer invalidate];
    _syncTimer = nil;
}

@end

// Cocoa UI Factory for AUv2 - provides custom view for hosts that use kAudioUnitProperty_CocoaUI
@interface DeliVerbCocoaViewFactory : NSObject <AUCocoaUIBase>
@end

@implementation DeliVerbCocoaViewFactory

- (unsigned)interfaceVersion {
    return 0;
}

- (NSString *)description {
    return @"DeliVerb View Factory";
}

- (NSView *)uiViewForAudioUnit:(AudioUnit)inAU withSize:(NSSize)inPreferredSize {
    // Create bridge to connect AUv2 parameters with our AUParameter-based view
    AUv2ParameterBridge *bridge = [[AUv2ParameterBridge alloc] initWithAudioUnit:inAU];

    // Create our custom view
    DeliVerbView *view = [[DeliVerbView alloc] initWithFrame:NSMakeRect(0, 0, 400, 640)];

    // Bind the view to our bridged parameter tree
    [view setParameterTree:bridge.parameterTree];

    // Start syncing parameter values
    [bridge startSync];

    // Store bridge reference so it stays alive with the view
    objc_setAssociatedObject(view, "parameterBridge", bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return view;
}

@end
