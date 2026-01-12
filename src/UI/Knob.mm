#import "Knob.h"
#import "Theme.h"

using namespace DeliVerb;

@interface SSKnob () {
    AUParameterObserverToken _observerToken;
}
@property (nonatomic, strong) CALayer *knobLayer;
@property (nonatomic, strong) CALayer *indicatorLayer;
@property (nonatomic, strong) CATextLayer *labelLayer;
@property (nonatomic, strong) CATextLayer *valueLayer;
@property (nonatomic, assign) CGPoint lastMouseLocation;
@property (nonatomic, assign) float lastValue;
@end

@implementation SSKnob

- (instancetype)initWithFrame:(NSRect)frame label:(NSString *)label {
    self = [super initWithFrame:frame];
    if (self) {
        _label = label;
        _value = 0.5;
        _minValue = 0.0;
        _maxValue = 1.0;
        _defaultValue = 0.5;
        _knobSize = Theme::kLargeKnobSize;
        _showValue = YES;
        _valueFormat = @"%.2f";
        _accentColor = Theme::accentColor();
        _observerToken = nullptr;

        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor clearColor].CGColor;

        [self setupLayers];
    }
    return self;
}

- (void)dealloc {
    if (_observerToken && _parameterTree) {
        [_parameterTree removeParameterObserver:_observerToken];
    }
}

- (void)setupLayers {
    CGFloat centerX = self.bounds.size.width / 2;
    CGFloat knobY = self.bounds.size.height - _knobSize / 2 - 20;

    // Soft edge fade layer (renders behind the knob for blending)
    CGFloat fadeSize = _knobSize + 12;
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    fadeLayer.type = kCAGradientLayerRadial;
    fadeLayer.bounds = CGRectMake(0, 0, fadeSize, fadeSize);
    fadeLayer.position = CGPointMake(centerX, knobY);
    fadeLayer.colors = @[
        (id)[NSColor colorWithWhite:0.0 alpha:0.3].CGColor,
        (id)[NSColor colorWithWhite:0.0 alpha:0.15].CGColor,
        (id)[NSColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    fadeLayer.locations = @[@0.0, @0.3, @1.0];
    fadeLayer.startPoint = CGPointMake(0.5, 0.5);
    fadeLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.layer addSublayer:fadeLayer];

    // Knob body layer
    _knobLayer = [CALayer layer];
    _knobLayer.bounds = CGRectMake(0, 0, _knobSize, _knobSize);
    _knobLayer.position = CGPointMake(centerX, knobY);
    _knobLayer.cornerRadius = _knobSize / 2;
    _knobLayer.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.4].CGColor;

    // Add shadow
    _knobLayer.shadowColor = Theme::shadowColor().CGColor;
    _knobLayer.shadowOffset = CGSizeMake(0, -2);
    _knobLayer.shadowRadius = 4;
    _knobLayer.shadowOpacity = 0.6;

    // Add subtle gradient overlay for 3D effect
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = _knobLayer.bounds;
    gradient.cornerRadius = _knobSize / 2;
    gradient.colors = @[
        (id)[NSColor colorWithWhite:1.0 alpha:0.25].CGColor,
        (id)[NSColor colorWithWhite:0.0 alpha:0.2].CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);
    [_knobLayer addSublayer:gradient];

    // Indicator line - positioned to point downward (toward 6 o'clock) by default
    // Fully rounded capsule shape with soft edges
    CGFloat indicatorWidth = 8;
    CGFloat indicatorHeight = _knobSize / 2 - 1;
    _indicatorLayer = [CALayer layer];
    _indicatorLayer.bounds = CGRectMake(0, 0, indicatorWidth, indicatorHeight);
    _indicatorLayer.position = CGPointMake(_knobSize / 2, _knobSize * 3 / 4 - 2);
    _indicatorLayer.backgroundColor = [NSColor colorWithWhite:0.75 alpha:0.8].CGColor;
    _indicatorLayer.cornerRadius = indicatorWidth / 2;  // Fully rounded ends (capsule)

    // Add soft shadow for depth
    _indicatorLayer.shadowColor = [NSColor blackColor].CGColor;
    _indicatorLayer.shadowOffset = CGSizeMake(0, 1);
    _indicatorLayer.shadowRadius = 4;
    _indicatorLayer.shadowOpacity = 0.3;
    [_knobLayer addSublayer:_indicatorLayer];

    [self.layer addSublayer:_knobLayer];

    // Label
    _labelLayer = [CATextLayer layer];
    _labelLayer.string = _label;
    _labelLayer.font = (__bridge CFTypeRef)Theme::labelFont();
    _labelLayer.fontSize = 10;
    _labelLayer.foregroundColor = Theme::labelColor().CGColor;
    _labelLayer.alignmentMode = kCAAlignmentCenter;
    _labelLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _labelLayer.frame = CGRectMake(0, 5, self.bounds.size.width, 14);
    [self.layer addSublayer:_labelLayer];

    // Value display
    if (_showValue) {
        _valueLayer = [CATextLayer layer];
        _valueLayer.font = (__bridge CFTypeRef)Theme::valueFont();
        _valueLayer.fontSize = 9;
        _valueLayer.foregroundColor = Theme::valueColor().CGColor;
        _valueLayer.alignmentMode = kCAAlignmentCenter;
        _valueLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        _valueLayer.frame = CGRectMake(0, knobY - _knobSize / 2 - 18, self.bounds.size.width, 12);
        [self.layer addSublayer:_valueLayer];
    }

    [self updateRotation];
    [self updateValueDisplay];
}

- (void)updateRotation {
    // Map value to rotation: -120° (7 o'clock) to +120° (5 o'clock) = 240° total range
    // Lowest value at 7 o'clock (bottom-left), highest at 5 o'clock (bottom-right)
    float normalized = [self normalizedValue];
    CGFloat angle = 120.0 - normalized * 240.0;
    CGFloat radians = angle * M_PI / 180.0;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _knobLayer.transform = CATransform3DMakeRotation(radians, 0, 0, 1);
    [CATransaction commit];
}

- (void)updateValueDisplay {
    if (_valueLayer) {
        float displayValue = _minValue + [self normalizedValue] * (_maxValue - _minValue);
        _valueLayer.string = [NSString stringWithFormat:_valueFormat, displayValue];
    }
}

- (void)setValue:(float)value {
    _value = fmaxf(_minValue, fminf(_maxValue, value));
    [self updateRotation];
    [self updateValueDisplay];

    if (_parameter) {
        _parameter.value = _value;
    }
}

- (void)setNormalizedValue:(float)normalized {
    self.value = _minValue + normalized * (_maxValue - _minValue);
}

- (float)normalizedValue {
    if (_maxValue == _minValue) return 0;
    return (_value - _minValue) / (_maxValue - _minValue);
}

- (void)bindToParameter:(AUParameter *)parameter tree:(AUParameterTree *)tree {
    // Remove old observer
    if (_observerToken && _parameterTree) {
        [_parameterTree removeParameterObserver:_observerToken];
        _observerToken = nullptr;
    }

    _parameter = parameter;
    _parameterTree = tree;

    if (parameter && tree) {
        _minValue = parameter.minValue;
        _maxValue = parameter.maxValue;
        _value = parameter.value;

        // Add observer for parameter changes
        __weak SSKnob *weakSelf = self;
        AUParameterAddress paramAddress = parameter.address;
        _observerToken = [tree tokenByAddingParameterObserver:^(AUParameterAddress address, AUValue value) {
            if (address == paramAddress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SSKnob *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_value != value) {
                        strongSelf->_value = value;
                        [strongSelf updateRotation];
                        [strongSelf updateValueDisplay];
                    }
                });
            }
        }];

        [self updateRotation];
        [self updateValueDisplay];
    }
}

- (void)setParameter:(AUParameter *)parameter {
    // For backwards compatibility, try to use stored tree
    [self bindToParameter:parameter tree:_parameterTree];
}

- (void)setAccentColor:(NSColor *)accentColor {
    _accentColor = accentColor;
    // Indicator stays grey, accent color used elsewhere
}

- (void)setKnobSize:(CGFloat)knobSize {
    if (_knobSize != knobSize) {
        _knobSize = knobSize;
        [self rebuildLayers];
    }
}

- (void)setShowValue:(BOOL)showValue {
    if (_showValue != showValue) {
        _showValue = showValue;
        [self rebuildLayers];
    }
}

- (void)setValueFormat:(NSString *)valueFormat {
    if (![_valueFormat isEqualToString:valueFormat]) {
        _valueFormat = [valueFormat copy];
        [self updateValueDisplay];
    }
}

- (void)rebuildLayers {
    // Remove existing layers
    [_knobLayer removeFromSuperlayer];
    [_labelLayer removeFromSuperlayer];
    [_valueLayer removeFromSuperlayer];

    // Recreate with new size
    [self setupLayers];
}

#pragma mark - Mouse Handling

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    _lastMouseLocation = [self convertPoint:event.locationInWindow fromView:nil];
    _lastValue = _value;

    // Double-click to reset
    if (event.clickCount == 2) {
        self.value = _defaultValue;
    }
}

- (void)mouseDragged:(NSEvent *)event {
    CGPoint currentLocation = [self convertPoint:event.locationInWindow fromView:nil];

    // Vertical drag: up = increase, down = decrease
    CGFloat deltaY = currentLocation.y - _lastMouseLocation.y;

    // Sensitivity: shift for fine control
    CGFloat sensitivity = (event.modifierFlags & NSEventModifierFlagShift) ? 0.001 : 0.005;

    float newNormalized = [self normalizedValue] + deltaY * sensitivity;
    newNormalized = fmaxf(0.0, fminf(1.0, newNormalized));

    [self setNormalizedValue:newNormalized];

    _lastMouseLocation = currentLocation;
}

- (void)scrollWheel:(NSEvent *)event {
    CGFloat sensitivity = (event.modifierFlags & NSEventModifierFlagShift) ? 0.005 : 0.02;
    float newNormalized = [self normalizedValue] + event.deltaY * sensitivity;
    newNormalized = fmaxf(0.0, fminf(1.0, newNormalized));
    [self setNormalizedValue:newNormalized];
}

@end
