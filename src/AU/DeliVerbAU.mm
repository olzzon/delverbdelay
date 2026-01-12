#import "DeliVerbAU.h"
#import "Parameters.h"
#import "DeliVerbView.h"
#include <memory>

using namespace DeliVerb;

#pragma mark - DeliVerbAU Implementation

@implementation DeliVerbAU {
    std::unique_ptr<DeliVerbDSP> _dsp;
    AUAudioUnitBus *_inputBus;
    AUAudioUnitBus *_outputBus;
    AUAudioUnitBusArray *_inputBusArray;
    AUAudioUnitBusArray *_outputBusArray;
    AVAudioFormat *_format;
    AUAudioFrameCount _maxFrames;
    AUParameterTree *_paramTree;
}

@synthesize parameterTree = _paramTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (self == nil) return nil;

    // Initialize DSP
    _dsp = std::make_unique<DeliVerbDSP>();

    // Default format: stereo, 44.1kHz
    _format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];

    // Create input/output busses
    NSError *error = nil;
    _inputBus = [[AUAudioUnitBus alloc] initWithFormat:_format error:&error];
    if (error) {
        if (outError) *outError = error;
        return nil;
    }

    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:_format error:&error];
    if (error) {
        if (outError) *outError = error;
        return nil;
    }

    _inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                            busType:AUAudioUnitBusTypeInput
                                                             busses:@[_inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses:@[_outputBus]];

    // Create parameter tree
    [self createParameterTree];

    // Set max frames
    _maxFrames = 4096;

    return self;
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
        param.value = info.defaultValue;
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

    _paramTree = [AUParameterTree createTreeWithChildren:@[delayGroup, reverbGroup, advancedGroup]];

    // Parameter observer block
    __weak DeliVerbAU *weakSelf = self;
    _paramTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        __strong DeliVerbAU *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_dsp) {
            strongSelf->_dsp->setParameter(static_cast<DeliVerbDSP::ParamID>(param.address), value);
        }
    };

    _paramTree.implementorValueProvider = ^AUValue(AUParameter *param) {
        __strong DeliVerbAU *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_dsp) {
            return strongSelf->_dsp->getParameter(static_cast<DeliVerbDSP::ParamID>(param.address));
        }
        return param.value;
    };

    // String representation of parameter values
    _paramTree.implementorStringFromValueCallback = ^NSString * _Nonnull(AUParameter * _Nonnull param, const AUValue * _Nullable valuePtr) {
        AUValue value = valuePtr ? *valuePtr : param.value;

        switch (param.unit) {
            case kAudioUnitParameterUnit_Hertz:
                if (value >= 1000.0f) {
                    return [NSString stringWithFormat:@"%.1f kHz", value / 1000.0f];
                }
                return [NSString stringWithFormat:@"%.0f Hz", value];

            case kAudioUnitParameterUnit_Milliseconds:
                if (value >= 1000.0f) {
                    return [NSString stringWithFormat:@"%.2f s", value / 1000.0f];
                }
                return [NSString stringWithFormat:@"%.0f ms", value];

            case kAudioUnitParameterUnit_Boolean:
                return value > 0.5f ? @"On" : @"Off";

            default:
                // Generic format - show as percentage
                return [NSString stringWithFormat:@"%.0f%%", value * 100.0f];
        }
    };
}

#pragma mark - AUAudioUnit Overrides

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (AUAudioFrameCount)maximumFramesToRender {
    return _maxFrames;
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {
    _maxFrames = maximumFramesToRender;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }

    // Update sample rate
    double sampleRate = _outputBus.format.sampleRate;
    _dsp->setSampleRate(sampleRate);
    _dsp->reset();

    return YES;
}

- (void)deallocateRenderResources {
    [super deallocateRenderResources];
    _dsp->reset();
}

- (AUInternalRenderBlock)internalRenderBlock {
    // Capture DSP pointer for real-time thread
    DeliVerbDSP *dsp = _dsp.get();

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp *timestamp,
                              AUAudioFrameCount frameCount,
                              NSInteger outputBusNumber,
                              AudioBufferList *outputData,
                              const AURenderEvent *realtimeEventListHead,
                              AURenderPullInputBlock __unsafe_unretained pullInputBlock) {

        // Pull input
        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData);
        if (err != noErr) return err;

        // Process audio
        UInt32 numChannels = outputData->mNumberBuffers;

        if (numChannels >= 2) {
            // Stereo
            float *leftIn = (float *)outputData->mBuffers[0].mData;
            float *rightIn = (float *)outputData->mBuffers[1].mData;
            float *leftOut = leftIn;  // In-place processing
            float *rightOut = rightIn;

            dsp->processStereo(leftIn, rightIn, leftOut, rightOut, frameCount);
        } else if (numChannels == 1) {
            // Mono - process and output stereo to same buffer
            float *buffer = (float *)outputData->mBuffers[0].mData;
            static std::vector<float> tempR;
            if (tempR.size() < frameCount) tempR.resize(frameCount);
            dsp->process(buffer, buffer, tempR.data(), frameCount);
        }

        return noErr;
    };
}

- (BOOL)canProcessInPlace {
    return YES;
}

- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus {
    return YES;
}

#pragma mark - State

- (NSDictionary<NSString *, id> *)fullState {
    NSMutableDictionary *state = [[super fullState] mutableCopy] ?: [NSMutableDictionary dictionary];

    // Save all parameter values
    NSMutableDictionary *paramValues = [NSMutableDictionary dictionary];
    for (AUParameter *param in _paramTree.allParameters) {
        paramValues[param.identifier] = @(param.value);
    }
    state[@"parameters"] = paramValues;

    return state;
}

- (void)setFullState:(NSDictionary<NSString *, id> *)fullState {
    [super setFullState:fullState];

    // Restore parameter values
    NSDictionary *paramValues = fullState[@"parameters"];
    if (paramValues) {
        for (AUParameter *param in _paramTree.allParameters) {
            NSNumber *value = paramValues[param.identifier];
            if (value) {
                param.value = value.floatValue;
            }
        }
    }
}

- (void)requestViewControllerWithCompletionHandler:(void (^)(AUViewControllerBase * _Nullable))completionHandler {
    // Create and return the view controller for this AU
    dispatch_async(dispatch_get_main_queue(), ^{
        DeliVerbAUViewController *viewController = [[DeliVerbAUViewController alloc] init];
        // The view controller needs a reference to this AU
        [viewController performSelector:@selector(setAudioUnit:) withObject:self];
        completionHandler(viewController);
    });
}

@end

#pragma mark - View Controller

@implementation DeliVerbAUViewController {
    DeliVerbAU *_audioUnit;
    DeliVerbView *_mainView;
    AUParameterObserverToken _parameterObserverToken;
}

- (void)loadView {
    _mainView = [[DeliVerbView alloc] initWithFrame:NSMakeRect(0, 0, 400, 640)];
    self.view = _mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (_audioUnit) {
        [self connectViewToAU];
    }
}

- (void)dealloc {
    if (_parameterObserverToken && _audioUnit) {
        [_audioUnit.parameterTree removeParameterObserver:_parameterObserverToken];
    }
}

- (void)setAudioUnit:(DeliVerbAU *)audioUnit {
    _audioUnit = audioUnit;

    // If the view is already loaded, connect it now
    if (self.isViewLoaded && _mainView) {
        [self connectViewToAU];
    }
}

- (void)connectViewToAU {
    if (!_audioUnit || !_mainView) return;

    [_mainView setParameterTree:_audioUnit.parameterTree];

    // Observe parameter changes from the AU
    __weak DeliVerbView *weakView = _mainView;
    _parameterObserverToken = [_audioUnit.parameterTree tokenByAddingParameterObserver:^(AUParameterAddress address, AUValue value) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DeliVerbView *strongView = weakView;
            if (strongView) {
                [strongView setNeedsDisplay:YES];
            }
        });
    }];
}

- (AUAudioUnit *)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc
                                                   error:(NSError **)error {
    _audioUnit = [[DeliVerbAU alloc] initWithComponentDescription:desc options:0 error:error];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self connectViewToAU];
    });

    return _audioUnit;
}

- (NSSize)preferredContentSize {
    return NSMakeSize(400, 640);
}

@end
