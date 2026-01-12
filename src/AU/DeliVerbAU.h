#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/CoreAudioKit.h>
#include "DeliVerbDSP.h"

@interface DeliVerbAU : AUAudioUnit
@end

@interface DeliVerbAUViewController : AUViewController <AUAudioUnitFactory>
@end
