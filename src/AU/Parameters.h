#pragma once

#import <AudioToolbox/AudioToolbox.h>

namespace DeliVerb {

// Parameter addresses (must match DSP ParamID)
enum ParameterAddress : AUParameterAddress {
    // Main parameters (simple mode)
    kParamDelayTime = 0,
    kParamDelayRepeat,
    kParamDelayMix,
    kParamReverbSize,
    kParamReverbStyle,
    kParamReverbMix,

    // Advanced delay parameters
    kParamDelayLowCut,
    kParamDelayHighCut,

    // Advanced reverb parameters
    kParamReverbLowCut,
    kParamReverbHighCut,

    // Ducking parameters
    kParamDuckDelayAmount,
    kParamDuckReverbAmount,
    kParamDuckBehaviour,

    // UI toggle
    kParamAdvanced,

    kNumParameters
};

// Parameter info structure
struct ParameterInfo {
    const char* identifier;
    const char* name;
    float minValue;
    float maxValue;
    float defaultValue;
    AudioUnitParameterUnit unit;
    bool isAdvanced; // Hidden by default
};

// Parameter definitions
static const ParameterInfo kParameterInfos[] = {
    // Simple mode parameters (always visible)
    { "delayTime",   "Delay Time",   50.0f,  2000.0f, 300.0f, kAudioUnitParameterUnit_Milliseconds, false },
    { "delayRepeat", "Delay Repeat", 0.0f,   0.95f,   0.3f,   kAudioUnitParameterUnit_Generic, false },
    { "delayMix",    "Delay Mix",    0.0f,   1.0f,    0.3f,   kAudioUnitParameterUnit_Generic, false },
    { "reverbSize",  "Reverb Size",  0.0f,   1.0f,    0.5f,   kAudioUnitParameterUnit_Generic, false },
    { "reverbStyle", "Reverb Style", 0.0f,   1.0f,    0.0f,   kAudioUnitParameterUnit_Generic, false },
    { "reverbMix",   "Reverb Mix",   0.0f,   1.0f,    0.3f,   kAudioUnitParameterUnit_Generic, false },

    // Advanced delay parameters
    { "delayLowCut",  "Delay Low Cut",  20.0f,   2000.0f, 80.0f,   kAudioUnitParameterUnit_Hertz, true },
    { "delayHighCut", "Delay High Cut", 1000.0f, 20000.0f, 8000.0f, kAudioUnitParameterUnit_Hertz, true },

    // Advanced reverb parameters
    { "reverbLowCut",  "Reverb Low Cut",  20.0f,   2000.0f, 100.0f,  kAudioUnitParameterUnit_Hertz, true },
    { "reverbHighCut", "Reverb High Cut", 1000.0f, 20000.0f, 10000.0f, kAudioUnitParameterUnit_Hertz, true },

    // Ducking parameters
    { "duckDelayAmount",  "Duck Delay",     0.0f, 1.0f, 0.0f, kAudioUnitParameterUnit_Generic, true },
    { "duckReverbAmount", "Duck Reverb",    0.0f, 1.0f, 0.0f, kAudioUnitParameterUnit_Generic, true },
    { "duckBehaviour",    "Duck Behaviour", 0.0f, 1.0f, 0.5f, kAudioUnitParameterUnit_Generic, true },

    // UI only
    { "advanced", "Advanced", 0.0f, 1.0f, 0.0f, kAudioUnitParameterUnit_Boolean, false },
};

} // namespace DeliVerb
