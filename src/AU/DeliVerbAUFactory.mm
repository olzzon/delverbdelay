#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "DeliVerbAU.h"

// For AUv3 extensions, the NSExtensionPrincipalClass (DeliVerbAUViewController)
// implements AUAudioUnitFactory protocol and creates the AU via createAudioUnitWithComponentDescription:
// No separate factory function is needed for pure AUv3.

#pragma mark - Component Registration (Optional - for in-process loading)

// Register the AUAudioUnit subclass when the bundle loads
// This can help with in-process loading scenarios
__attribute__((constructor))
static void registerDeliVerbAU() {
    @autoreleasepool {
        AudioComponentDescription desc = {
            .componentType = kAudioUnitType_Effect,
            .componentSubType = 'dlvb',
            .componentManufacturer = 'DlVb',
            .componentFlags = kAudioComponentFlag_SandboxSafe,
            .componentFlagsMask = 0
        };

        [AUAudioUnit registerSubclass:[DeliVerbAU class]
               asComponentDescription:desc
                                 name:@"DeliVerb: DeliVerb"
                              version:0x00010000];

        NSLog(@"DeliVerb: Registered AUAudioUnit subclass for aufx/dlvb/DlVb");
    }
}
