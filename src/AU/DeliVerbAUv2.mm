#include "DeliVerbAUv2.h"
#include <cstring>
#import <Cocoa/Cocoa.h>
#import <AudioUnit/AUCocoaUIView.h>

// Forward declaration of Cocoa view factory class name
static NSString * const kCocoaViewFactoryClassName = @"DeliVerbCocoaViewFactory";

namespace DeliVerb {

// Parameter info structure for AUv2
struct ParamInfo {
    const char* name;
    AudioUnitParameterUnit unit;
    float minValue;
    float maxValue;
    float defaultValue;
};

// Parameter definitions matching DeliVerbDSP::ParamID
static const ParamInfo kParamInfos[] = {
    // Main delay parameters
    {"Delay Time",   kAudioUnitParameterUnit_Milliseconds, 50.0f, 2000.0f, 300.0f},
    {"Delay Repeat", kAudioUnitParameterUnit_Generic, 0.0f, 0.95f, 0.3f},
    {"Delay Mix",    kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.3f},
    // Main reverb parameters
    {"Reverb Size",  kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.5f},
    {"Reverb Style", kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.0f},
    {"Reverb Mix",   kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.3f},
    // Advanced delay parameters
    {"Delay Low Cut",  kAudioUnitParameterUnit_Hertz, 20.0f, 2000.0f, 80.0f},
    {"Delay High Cut", kAudioUnitParameterUnit_Hertz, 1000.0f, 20000.0f, 8000.0f},
    // Advanced reverb parameters
    {"Reverb Low Cut",  kAudioUnitParameterUnit_Hertz, 20.0f, 2000.0f, 100.0f},
    {"Reverb High Cut", kAudioUnitParameterUnit_Hertz, 1000.0f, 20000.0f, 10000.0f},
    // Ducking parameters
    {"Duck Delay",     kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.0f},
    {"Duck Reverb",    kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.0f},
    {"Duck Behaviour", kAudioUnitParameterUnit_Generic, 0.0f, 1.0f, 0.5f},
    // UI toggle
    {"Advanced",  kAudioUnitParameterUnit_Boolean, 0.0f, 1.0f, 0.0f},
};

static const int kNumParameters = sizeof(kParamInfos) / sizeof(kParamInfos[0]);

DeliVerbAUv2::DeliVerbAUv2(AudioComponentInstance inComponentInstance)
    : ausdk::AUEffectBase(inComponentInstance, true /* processes in place */)
{
    // Tell the SDK how many parameters we have (must be called before SetParameter)
    Globals()->UseIndexedParameters(kNumParameters);

    // Set default parameter values
    for (int i = 0; i < kNumParameters; ++i) {
        Globals()->SetParameter(i, kParamInfos[i].defaultValue);
    }
}

OSStatus DeliVerbAUv2::Initialize()
{
    OSStatus result = AUEffectBase::Initialize();
    if (result != noErr) return result;

    mDSP.setSampleRate(GetSampleRate());
    mDSP.reset();

    return noErr;
}

void DeliVerbAUv2::Cleanup()
{
    mDSP.reset();
    AUEffectBase::Cleanup();
}

OSStatus DeliVerbAUv2::Reset(AudioUnitScope inScope, AudioUnitElement inElement)
{
    mDSP.reset();
    return AUEffectBase::Reset(inScope, inElement);
}

OSStatus DeliVerbAUv2::GetParameterInfo(AudioUnitScope inScope,
                                         AudioUnitParameterID inParameterID,
                                         AudioUnitParameterInfo& outParameterInfo)
{
    if (inScope != kAudioUnitScope_Global) {
        return kAudioUnitErr_InvalidScope;
    }

    if (inParameterID >= static_cast<AudioUnitParameterID>(kNumParameters)) {
        return kAudioUnitErr_InvalidParameter;
    }

    const ParamInfo& info = kParamInfos[inParameterID];

    outParameterInfo.flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable;
    outParameterInfo.flags |= kAudioUnitParameterFlag_IsHighResolution;

    // Copy name - pass true for inShouldRelease so the SDK takes ownership of the CFString
    CFStringRef nameStr = CFStringCreateWithCString(kCFAllocatorDefault, info.name, kCFStringEncodingUTF8);
    AUBase::FillInParameterName(outParameterInfo, nameStr, true);

    outParameterInfo.unit = info.unit;
    outParameterInfo.minValue = info.minValue;
    outParameterInfo.maxValue = info.maxValue;
    outParameterInfo.defaultValue = info.defaultValue;

    return noErr;
}

OSStatus DeliVerbAUv2::GetPropertyInfo(AudioUnitPropertyID inID,
                                        AudioUnitScope inScope,
                                        AudioUnitElement inElement,
                                        UInt32& outDataSize,
                                        bool& outWritable)
{
    if (inID == kAudioUnitProperty_CocoaUI) {
        outDataSize = sizeof(AudioUnitCocoaViewInfo);
        outWritable = false;
        return noErr;
    }
    return AUEffectBase::GetPropertyInfo(inID, inScope, inElement, outDataSize, outWritable);
}

OSStatus DeliVerbAUv2::GetProperty(AudioUnitPropertyID inID,
                                    AudioUnitScope inScope,
                                    AudioUnitElement inElement,
                                    void* outData)
{
    if (inID == kAudioUnitProperty_CocoaUI) {
        AudioUnitCocoaViewInfo* viewInfo = static_cast<AudioUnitCocoaViewInfo*>(outData);

        // Get the bundle URL for this component
        CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.deliverb.audiounit"));
        if (!bundle) {
            return kAudioUnitErr_InvalidProperty;
        }

        CFURLRef bundleURL = CFBundleCopyBundleURL(bundle);
        if (!bundleURL) {
            return kAudioUnitErr_InvalidProperty;
        }

        viewInfo->mCocoaAUViewBundleLocation = bundleURL;
        viewInfo->mCocoaAUViewClass[0] = CFStringCreateCopy(kCFAllocatorDefault,
            (__bridge CFStringRef)kCocoaViewFactoryClassName);

        return noErr;
    }
    return AUEffectBase::GetProperty(inID, inScope, inElement, outData);
}

OSStatus DeliVerbAUv2::ProcessBufferLists(AudioUnitRenderActionFlags& ioActionFlags,
                                           const AudioBufferList& inBuffer,
                                           AudioBufferList& outBuffer,
                                           UInt32 inFramesToProcess)
{
    // Update parameters from AU state
    for (int i = 0; i < kNumParameters; ++i) {
        mDSP.setParameter(static_cast<DeliVerbDSP::ParamID>(i), GetParameter(i));
    }

    UInt32 numChannels = outBuffer.mNumberBuffers;

    if (numChannels >= 2) {
        // Stereo processing
        const float* leftIn = static_cast<const float*>(inBuffer.mBuffers[0].mData);
        const float* rightIn = static_cast<const float*>(inBuffer.mBuffers[1].mData);
        float* leftOut = static_cast<float*>(outBuffer.mBuffers[0].mData);
        float* rightOut = static_cast<float*>(outBuffer.mBuffers[1].mData);

        // Copy input to output if different buffers
        if (leftIn != leftOut) {
            memcpy(leftOut, leftIn, inFramesToProcess * sizeof(float));
        }
        if (rightIn != rightOut) {
            memcpy(rightOut, rightIn, inFramesToProcess * sizeof(float));
        }

        mDSP.processStereo(leftOut, rightOut, leftOut, rightOut, inFramesToProcess);
    } else if (numChannels == 1) {
        // Mono input - process to stereo output
        const float* inData = static_cast<const float*>(inBuffer.mBuffers[0].mData);
        float* outData = static_cast<float*>(outBuffer.mBuffers[0].mData);

        // For mono, create a temp buffer for the right channel
        static std::vector<float> tempR;
        if (tempR.size() < inFramesToProcess) tempR.resize(inFramesToProcess);

        mDSP.process(inData, outData, tempR.data(), inFramesToProcess);
    }

    return noErr;
}

} // namespace DeliVerb

// Factory function entry point
using DeliVerbAUv2 = DeliVerb::DeliVerbAUv2;
AUSDK_COMPONENT_ENTRY(ausdk::AUBaseFactory, DeliVerbAUv2)
