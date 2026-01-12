#import "Button.h"
#import "Theme.h"

using namespace DeliVerb;

@interface SSButton ()
@property (nonatomic, strong) CALayer *buttonLayer;
@property (nonatomic, strong) CALayer *ledLayer;
@property (nonatomic, strong) CATextLayer *titleLayer;
@end

@implementation SSButton

- (instancetype)initWithFrame:(NSRect)frame title:(NSString *)title {
    self = [super initWithFrame:frame];
    if (self) {
        _title = title;
        _isOn = NO;
        _onColor = Theme::accentColor();
        _offColor = [NSColor colorWithWhite:0.3 alpha:1.0];

        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor clearColor].CGColor;

        [self setupLayers];
    }
    return self;
}

- (void)setupLayers {
    CGFloat buttonWidth = self.bounds.size.width;
    CGFloat buttonHeight = 28;

    // Button body
    _buttonLayer = [CALayer layer];
    _buttonLayer.frame = CGRectMake(0, (self.bounds.size.height - buttonHeight) / 2, buttonWidth, buttonHeight);
    _buttonLayer.cornerRadius = 4;
    _buttonLayer.backgroundColor = [NSColor colorWithWhite:0.1 alpha:1.0].CGColor;
    _buttonLayer.borderWidth = 1;
    _buttonLayer.borderColor = [NSColor colorWithWhite:0.15 alpha:1.0].CGColor;

    // Shadow
    _buttonLayer.shadowColor = Theme::shadowColor().CGColor;
    _buttonLayer.shadowOffset = CGSizeMake(0, -1);
    _buttonLayer.shadowRadius = 2;
    _buttonLayer.shadowOpacity = 0.4;

    [self.layer addSublayer:_buttonLayer];

    // LED indicator
    CGFloat ledSize = 8;
    _ledLayer = [CALayer layer];
    _ledLayer.frame = CGRectMake(8, (buttonHeight - ledSize) / 2, ledSize, ledSize);
    _ledLayer.cornerRadius = ledSize / 2;
    _ledLayer.backgroundColor = _offColor.CGColor;
    [_buttonLayer addSublayer:_ledLayer];

    // Title
    _titleLayer = [CATextLayer layer];
    _titleLayer.string = _title;
    _titleLayer.font = (__bridge CFTypeRef)Theme::labelFont();
    _titleLayer.fontSize = 10;
    _titleLayer.foregroundColor = Theme::labelColor().CGColor;
    _titleLayer.alignmentMode = kCAAlignmentCenter;
    _titleLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    _titleLayer.frame = CGRectMake(20, (buttonHeight - 12) / 2, buttonWidth - 28, 12);
    [_buttonLayer addSublayer:_titleLayer];

    [self updateAppearance];
}

- (void)updateAppearance {
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.15];

    if (_isOn) {
        _ledLayer.backgroundColor = _onColor.CGColor;
        _ledLayer.shadowColor = _onColor.CGColor;
        _ledLayer.shadowRadius = 4;
        _ledLayer.shadowOpacity = 0.8;
        _ledLayer.shadowOffset = CGSizeZero;
        _buttonLayer.backgroundColor = [NSColor colorWithWhite:0.25 alpha:1.0].CGColor;
    } else {
        _ledLayer.backgroundColor = _offColor.CGColor;
        _ledLayer.shadowOpacity = 0;
        _buttonLayer.backgroundColor = [NSColor colorWithWhite:0.2 alpha:1.0].CGColor;
    }

    [CATransaction commit];
}

- (void)setIsOn:(BOOL)isOn {
    _isOn = isOn;
    [self updateAppearance];
}

#pragma mark - Mouse Handling

- (void)mouseDown:(NSEvent *)event {
    // Visual feedback
    _buttonLayer.backgroundColor = [NSColor colorWithWhite:0.15 alpha:1.0].CGColor;
}

- (void)mouseUp:(NSEvent *)event {
    CGPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(location, self.bounds)) {
        self.isOn = !_isOn;
        if (_onToggle) {
            _onToggle(_isOn);
        }
    }
    [self updateAppearance];
}

@end
