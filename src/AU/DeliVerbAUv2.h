#pragma once

#include <AudioUnitSDK/AUEffectBase.h>
#include "DeliVerbDSP.h"

namespace DeliVerb {

class DeliVerbAUv2 : public ausdk::AUEffectBase {
public:
    explicit DeliVerbAUv2(AudioComponentInstance inComponentInstance);
    ~DeliVerbAUv2() override = default;

    // AUBase overrides
    OSStatus Initialize() override;
    void Cleanup() override;
    OSStatus Reset(AudioUnitScope inScope, AudioUnitElement inElement) override;

    OSStatus GetParameterInfo(AudioUnitScope inScope,
                              AudioUnitParameterID inParameterID,
                              AudioUnitParameterInfo& outParameterInfo) override;

    OSStatus GetPropertyInfo(AudioUnitPropertyID inID,
                             AudioUnitScope inScope,
                             AudioUnitElement inElement,
                             UInt32& outDataSize,
                             bool& outWritable) override;

    OSStatus GetProperty(AudioUnitPropertyID inID,
                         AudioUnitScope inScope,
                         AudioUnitElement inElement,
                         void* outData) override;

    // Processing
    OSStatus ProcessBufferLists(AudioUnitRenderActionFlags& ioActionFlags,
                                const AudioBufferList& inBuffer,
                                AudioBufferList& outBuffer,
                                UInt32 inFramesToProcess) override;

private:
    DeliVerbDSP mDSP;
};

} // namespace DeliVerb
