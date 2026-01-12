#import "DeliVerbView.h"
#import "Theme.h"
#import "Knob.h"
#import "Button.h"
#import "Parameters.h"

using namespace DeliVerb;

@interface DeliVerbView ()

// Main knobs (simple mode - large, overlaid on pedal image)
@property (nonatomic, strong) SSKnob *largeDelayTimeKnob;
@property (nonatomic, strong) SSKnob *largeDelayRepeatKnob;
@property (nonatomic, strong) SSKnob *largeDelayMixKnob;
@property (nonatomic, strong) SSKnob *largeReverbSizeKnob;
@property (nonatomic, strong) SSKnob *largeReverbStyleKnob;
@property (nonatomic, strong) SSKnob *largeReverbMixKnob;

// Advanced mode knobs (smaller, with labels)
@property (nonatomic, strong) SSKnob *delayTimeKnob;
@property (nonatomic, strong) SSKnob *delayRepeatKnob;
@property (nonatomic, strong) SSKnob *delayMixKnob;
@property (nonatomic, strong) SSKnob *reverbSizeKnob;
@property (nonatomic, strong) SSKnob *reverbStyleKnob;
@property (nonatomic, strong) SSKnob *reverbMixKnob;

// Advanced filter knobs
@property (nonatomic, strong) SSKnob *delayLowCutKnob;
@property (nonatomic, strong) SSKnob *delayHighCutKnob;
@property (nonatomic, strong) SSKnob *reverbLowCutKnob;
@property (nonatomic, strong) SSKnob *reverbHighCutKnob;

// Ducking knobs
@property (nonatomic, strong) SSKnob *duckDelayKnob;
@property (nonatomic, strong) SSKnob *duckReverbKnob;
@property (nonatomic, strong) SSKnob *duckBehaviourKnob;

// Advanced button
@property (nonatomic, strong) SSButton *advancedButton;

// Layers
@property (nonatomic, strong) CALayer *backgroundLayer;
@property (nonatomic, strong) CALayer *pedalImageLayer;
@property (nonatomic, strong) CATextLayer *titleLayer;
@property (nonatomic, strong) CATextLayer *versionLayer;

// State
@property (nonatomic, assign) BOOL showAdvanced;
@property (nonatomic, weak) AUParameterTree *parameterTree;

@end

@implementation DeliVerbView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _showAdvanced = NO;
        self.wantsLayer = YES;
        [self setupBackground];
        [self setupPedalImage];
        [self setupTitle];
        [self setupVersion];
        [self setupControls];
    }
    return self;
}

- (void)setupBackground {
    // Main background with metallic blue gradient
    _backgroundLayer = [CAGradientLayer layer];
    CAGradientLayer *gradient = (CAGradientLayer *)_backgroundLayer;
    gradient.frame = self.bounds;
    gradient.colors = @[
        (id)Theme::metalGradientTop().CGColor,
        (id)Theme::metalGradientBottom().CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 1.0);
    gradient.endPoint = CGPointMake(0.5, 0.0);
    gradient.cornerRadius = 12;

    // Add border
    gradient.borderWidth = 2;
    gradient.borderColor = [NSColor colorWithWhite:0.2 alpha:1.0].CGColor;

    // Add shadow
    gradient.shadowColor = [NSColor blackColor].CGColor;
    gradient.shadowOffset = CGSizeMake(0, -4);
    gradient.shadowRadius = 8;
    gradient.shadowOpacity = 0.5;

    [self.layer addSublayer:_backgroundLayer];

    // Add brushed metal texture overlay
    CALayer *textureLayer = [CALayer layer];
    textureLayer.frame = self.bounds;
    textureLayer.backgroundColor = [NSColor colorWithPatternImage:[self brushedMetalTexture]].CGColor;
    textureLayer.opacity = 0.15;
    textureLayer.cornerRadius = 12;
    [self.layer addSublayer:textureLayer];
}

- (NSImage *)brushedMetalTexture {
    NSSize size = NSMakeSize(200, 200);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];

    // Create realistic brushed metal effect with varying line intensities
    srand48(42); // Consistent seed for reproducible pattern

    // Base horizontal brush strokes
    for (int i = 0; i < 200; i++) {
        CGFloat alpha = 0.1 + drand48() * 0.25;
        CGFloat brightness = 0.4 + drand48() * 0.2;
        [[NSColor colorWithWhite:brightness alpha:alpha] setStroke];

        NSBezierPath *line = [NSBezierPath bezierPath];
        CGFloat yOffset = i + (drand48() - 0.5) * 0.5; // Slight variation
        [line moveToPoint:NSMakePoint(0, yOffset)];
        [line lineToPoint:NSMakePoint(200, yOffset)];
        [line setLineWidth:0.3 + drand48() * 0.4];
        [line stroke];
    }

    [image unlockFocus];
    return image;
}

- (void)setupPedalImage {
    // Load the DeliVerb pedal image for simple mode background
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"deliverb" ofType:@"png"];
    NSImage *pedalImage = nil;

    if (imagePath) {
        pedalImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
    }

    if (!pedalImage) {
        // Try loading from assets directory relative to bundle
        NSString *bundlePath = [[bundle bundlePath] stringByDeletingLastPathComponent];
        imagePath = [bundlePath stringByAppendingPathComponent:@"assets/deliverb.png"];
        pedalImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
    }

    _pedalImageLayer = [CALayer layer];

    if (pedalImage) {
        // Scale image to fit view width while maintaining aspect ratio
        CGFloat imageAspect = pedalImage.size.height / pedalImage.size.width;
        CGFloat viewWidth = self.bounds.size.width;
        CGFloat scaledHeight = viewWidth * imageAspect;

        // Center the image vertically, offset up a bit to leave room for button
        CGFloat yOffset = (self.bounds.size.height - scaledHeight) / 2 + 20;

        _pedalImageLayer.frame = CGRectMake(0, yOffset, viewWidth, scaledHeight);
        _pedalImageLayer.contents = pedalImage;
        _pedalImageLayer.contentsGravity = kCAGravityResizeAspect;
    } else {
        _pedalImageLayer.frame = self.bounds;
    }

    [self.layer addSublayer:_pedalImageLayer];
}

- (void)setupTitle {
    // Title (hidden by default in simple mode - pedal image has the title)
    _titleLayer = [CATextLayer layer];
    _titleLayer.string = @"DELIVERB";
    _titleLayer.font = (__bridge CFTypeRef)Theme::titleFont();
    _titleLayer.fontSize = 18;
    _titleLayer.foregroundColor = Theme::labelColor().CGColor;
    _titleLayer.alignmentMode = kCAAlignmentCenter;
    _titleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _titleLayer.frame = CGRectMake(0, self.bounds.size.height - 40, self.bounds.size.width, 24);

    // Add shadow to title
    _titleLayer.shadowColor = [NSColor blackColor].CGColor;
    _titleLayer.shadowOffset = CGSizeMake(0, -1);
    _titleLayer.shadowRadius = 2;
    _titleLayer.shadowOpacity = 0.5;

    // Hidden by default (simple mode shows pedal image with title)
    _titleLayer.hidden = YES;

    [self.layer addSublayer:_titleLayer];
}

- (void)setupVersion {
    // Get version from bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!version) {
        version = @"1.0.0";
    }

    // Version label
    _versionLayer = [CATextLayer layer];
    _versionLayer.string = [NSString stringWithFormat:@"v%@", version];
    _versionLayer.font = (__bridge CFTypeRef)Theme::labelFont();
    _versionLayer.fontSize = 10;
    _versionLayer.foregroundColor = Theme::versionColor().CGColor;
    _versionLayer.alignmentMode = kCAAlignmentRight;
    _versionLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];

    // Position to the right of the title
    CGFloat yPosition = self.bounds.size.height - 40;
    CGFloat rightPadding = 20;
    _versionLayer.frame = CGRectMake(self.bounds.size.width - 80 - rightPadding, yPosition, 80, 24);

    // Add shadow to match title
    _versionLayer.shadowColor = [NSColor blackColor].CGColor;
    _versionLayer.shadowOffset = CGSizeMake(0, -1);
    _versionLayer.shadowRadius = 2;
    _versionLayer.shadowOpacity = 0.5;

    // Hidden by default (only shown in advanced mode)
    _versionLayer.hidden = YES;

    [self.layer addSublayer:_versionLayer];
}

- (void)setupControls {
    CGFloat width = self.bounds.size.width;

    // White indicator color for visibility on dark knobs
    NSColor *indicatorColor = [NSColor colorWithWhite:0.9 alpha:1.0];

    // ========== Large knobs for simple mode (overlaid on pedal image) ==========
    // Positions calibrated for the pedal image layout
    // Top row: Delay Time, Delay Repeat, Delay Mix
    // Bottom row: Reverb Size, Reverb Style, Reverb Mix
    CGFloat largeTopY = 510;
    CGFloat largeBottomY = 420;
    CGFloat col1X = width / 4.0;
    CGFloat col2X = width / 2.0;
    CGFloat col3X = width * 3.0 / 4.0;

    _largeDelayTimeKnob = [self addLargeKnobWithLabel:@"" atX:col1X y:largeTopY color:indicatorColor];
    _largeDelayRepeatKnob = [self addLargeKnobWithLabel:@"" atX:col2X y:largeTopY color:indicatorColor];
    _largeDelayMixKnob = [self addLargeKnobWithLabel:@"" atX:col3X y:largeTopY color:indicatorColor];

    _largeReverbSizeKnob = [self addLargeKnobWithLabel:@"" atX:col1X y:largeBottomY color:indicatorColor];
    _largeReverbStyleKnob = [self addLargeKnobWithLabel:@"" atX:col2X y:largeBottomY color:indicatorColor];
    _largeReverbMixKnob = [self addLargeKnobWithLabel:@"" atX:col3X y:largeBottomY color:indicatorColor];

    // Hide value display for large knobs (pedal image shows labels)
    _largeDelayTimeKnob.showValue = NO;
    _largeDelayRepeatKnob.showValue = NO;
    _largeDelayMixKnob.showValue = NO;
    _largeReverbSizeKnob.showValue = NO;
    _largeReverbStyleKnob.showValue = NO;
    _largeReverbMixKnob.showValue = NO;

    // ========== Advanced mode controls ==========
    CGFloat advRow1Y = self.bounds.size.height - 90;   // Main delay
    CGFloat advRow2Y = advRow1Y - 100;                 // Main reverb
    CGFloat advRow3Y = advRow2Y - 100;                 // Filters
    CGFloat advRow4Y = advRow3Y - 100;                 // More filters
    CGFloat advRow5Y = advRow4Y - 100;                 // Ducking

    // Row 1: Delay controls
    _delayTimeKnob = [self addKnobWithLabel:@"DELAY TIME" atX:col1X y:advRow1Y color:Theme::accentColor()];
    _delayRepeatKnob = [self addKnobWithLabel:@"REPEAT" atX:col2X y:advRow1Y color:Theme::accentColor()];
    _delayMixKnob = [self addKnobWithLabel:@"DELAY MIX" atX:col3X y:advRow1Y color:Theme::accentColor()];

    // Row 2: Reverb controls
    _reverbSizeKnob = [self addKnobWithLabel:@"SIZE" atX:col1X y:advRow2Y color:Theme::reverbAccentColor()];
    _reverbStyleKnob = [self addKnobWithLabel:@"STYLE" atX:col2X y:advRow2Y color:Theme::reverbAccentColor()];
    _reverbMixKnob = [self addKnobWithLabel:@"REVERB MIX" atX:col3X y:advRow2Y color:Theme::reverbAccentColor()];

    // Row 3: Delay filters
    _delayLowCutKnob = [self addKnobWithLabel:@"DLY LOW" atX:col1X y:advRow3Y color:Theme::accentColor()];
    _delayHighCutKnob = [self addKnobWithLabel:@"DLY HIGH" atX:col2X y:advRow3Y color:Theme::accentColor()];

    // Row 4: Reverb filters
    _reverbLowCutKnob = [self addKnobWithLabel:@"REV LOW" atX:col1X y:advRow4Y color:Theme::reverbAccentColor()];
    _reverbHighCutKnob = [self addKnobWithLabel:@"REV HIGH" atX:col2X y:advRow4Y color:Theme::reverbAccentColor()];

    // Row 5: Ducking
    _duckDelayKnob = [self addKnobWithLabel:@"DUCK DLY" atX:col1X y:advRow5Y color:Theme::accentColor()];
    _duckReverbKnob = [self addKnobWithLabel:@"DUCK REV" atX:col2X y:advRow5Y color:Theme::reverbAccentColor()];
    _duckBehaviourKnob = [self addKnobWithLabel:@"BEHAVIOUR" atX:col3X y:advRow5Y color:Theme::accentColor()];

    // Set value formats
    _delayTimeKnob.valueFormat = @"%.0f ms";
    _delayRepeatKnob.valueFormat = @"%.2f";
    _delayMixKnob.valueFormat = @"%.2f";
    _reverbSizeKnob.valueFormat = @"%.2f";
    _reverbStyleKnob.valueFormat = @"%.2f";
    _reverbMixKnob.valueFormat = @"%.2f";
    _delayLowCutKnob.valueFormat = @"%.0f Hz";
    _delayHighCutKnob.valueFormat = @"%.0f Hz";
    _reverbLowCutKnob.valueFormat = @"%.0f Hz";
    _reverbHighCutKnob.valueFormat = @"%.0f Hz";
    _duckDelayKnob.valueFormat = @"%.2f";
    _duckReverbKnob.valueFormat = @"%.2f";
    _duckBehaviourKnob.valueFormat = @"%.2f";

    // Hide advanced knobs by default
    _delayTimeKnob.hidden = YES;
    _delayRepeatKnob.hidden = YES;
    _delayMixKnob.hidden = YES;
    _reverbSizeKnob.hidden = YES;
    _reverbStyleKnob.hidden = YES;
    _reverbMixKnob.hidden = YES;
    _delayLowCutKnob.hidden = YES;
    _delayHighCutKnob.hidden = YES;
    _reverbLowCutKnob.hidden = YES;
    _reverbHighCutKnob.hidden = YES;
    _duckDelayKnob.hidden = YES;
    _duckReverbKnob.hidden = YES;
    _duckBehaviourKnob.hidden = YES;

    // Advanced button
    _advancedButton = [[SSButton alloc] initWithFrame:NSMakeRect(width/2 - 45, 5, 90, 30) title:@"ADVANCED"];
    _advancedButton.onColor = Theme::accentColor();
    __weak DeliVerbView *weakSelf = self;
    _advancedButton.onToggle = ^(BOOL isOn) {
        [weakSelf toggleAdvanced:isOn];
    };
    [self addSubview:_advancedButton];
}

- (SSKnob *)addKnobWithLabel:(NSString *)label atX:(CGFloat)x y:(CGFloat)y color:(NSColor *)color {
    CGFloat knobWidth = 70;
    CGFloat knobHeight = 90;

    SSKnob *knob = [[SSKnob alloc] initWithFrame:NSMakeRect(x - knobWidth/2, y - knobHeight/2, knobWidth, knobHeight)
                                           label:label];
    knob.accentColor = color;
    knob.knobSize = Theme::kLargeKnobSize;
    [self addSubview:knob];
    return knob;
}

- (SSKnob *)addLargeKnobWithLabel:(NSString *)label atX:(CGFloat)x y:(CGFloat)y color:(NSColor *)color {
    CGFloat knobWidth = 100;
    CGFloat knobHeight = 120;
    CGFloat largeKnobSize = 67.0;

    SSKnob *knob = [[SSKnob alloc] initWithFrame:NSMakeRect(x - knobWidth/2, y - knobHeight/2, knobWidth, knobHeight)
                                           label:label];
    knob.accentColor = color;
    knob.knobSize = largeKnobSize;
    [self addSubview:knob];
    return knob;
}

- (void)toggleAdvanced:(BOOL)show {
    _showAdvanced = show;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        // Pedal image (shown in simple mode, hidden in advanced)
        _pedalImageLayer.hidden = show;

        // Title and version (shown in advanced mode)
        _titleLayer.hidden = !show;
        _versionLayer.hidden = !show;

        // Large knobs (simple mode)
        _largeDelayTimeKnob.animator.hidden = show;
        _largeDelayRepeatKnob.animator.hidden = show;
        _largeDelayMixKnob.animator.hidden = show;
        _largeReverbSizeKnob.animator.hidden = show;
        _largeReverbStyleKnob.animator.hidden = show;
        _largeReverbMixKnob.animator.hidden = show;

        // Advanced knobs
        _delayTimeKnob.animator.hidden = !show;
        _delayRepeatKnob.animator.hidden = !show;
        _delayMixKnob.animator.hidden = !show;
        _reverbSizeKnob.animator.hidden = !show;
        _reverbStyleKnob.animator.hidden = !show;
        _reverbMixKnob.animator.hidden = !show;
        _delayLowCutKnob.animator.hidden = !show;
        _delayHighCutKnob.animator.hidden = !show;
        _reverbLowCutKnob.animator.hidden = !show;
        _reverbHighCutKnob.animator.hidden = !show;
        _duckDelayKnob.animator.hidden = !show;
        _duckReverbKnob.animator.hidden = !show;
        _duckBehaviourKnob.animator.hidden = !show;

    } completionHandler:nil];

    // Update parameter
    if (_parameterTree) {
        AUParameter *advParam = [_parameterTree parameterWithAddress:kParamAdvanced];
        if (advParam) {
            advParam.value = show ? 1.0 : 0.0;
        }
    }
}

- (void)setParameterTree:(AUParameterTree *)parameterTree {
    _parameterTree = parameterTree;

    if (!parameterTree) return;

    // Bind large knobs (simple mode) - same parameters as small knobs
    [_largeDelayTimeKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayTime] tree:parameterTree];
    [_largeDelayRepeatKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayRepeat] tree:parameterTree];
    [_largeDelayMixKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayMix] tree:parameterTree];
    [_largeReverbSizeKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbSize] tree:parameterTree];
    [_largeReverbStyleKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbStyle] tree:parameterTree];
    [_largeReverbMixKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbMix] tree:parameterTree];

    // Bind advanced mode knobs - main controls
    [_delayTimeKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayTime] tree:parameterTree];
    [_delayRepeatKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayRepeat] tree:parameterTree];
    [_delayMixKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayMix] tree:parameterTree];
    [_reverbSizeKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbSize] tree:parameterTree];
    [_reverbStyleKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbStyle] tree:parameterTree];
    [_reverbMixKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbMix] tree:parameterTree];

    // Bind filter controls
    [_delayLowCutKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayLowCut] tree:parameterTree];
    [_delayHighCutKnob bindToParameter:[parameterTree parameterWithAddress:kParamDelayHighCut] tree:parameterTree];
    [_reverbLowCutKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbLowCut] tree:parameterTree];
    [_reverbHighCutKnob bindToParameter:[parameterTree parameterWithAddress:kParamReverbHighCut] tree:parameterTree];

    // Bind ducking controls
    [_duckDelayKnob bindToParameter:[parameterTree parameterWithAddress:kParamDuckDelayAmount] tree:parameterTree];
    [_duckReverbKnob bindToParameter:[parameterTree parameterWithAddress:kParamDuckReverbAmount] tree:parameterTree];
    [_duckBehaviourKnob bindToParameter:[parameterTree parameterWithAddress:kParamDuckBehaviour] tree:parameterTree];
}

- (BOOL)isFlipped {
    return NO; // Use standard Cocoa coordinate system (origin at bottom-left)
}

@end
