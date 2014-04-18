//
//  NKOColorPickerView.h
//  ColorPicker
//
//  Created by Carlos Vidal
//  Based on work by Fabián Cañas and Gilly Dekel
//

//NKOBrightnessView
@interface NKOBrightnessView : UIView

@property (nonatomic, strong) UIColor *color;

@end

@interface OpacityView : NKOBrightnessView

@end

//UIImage category
@interface UIImage (NKO)

- (UIImage *) nko_tintImageWithColor:(UIColor *)tintColor;

@end

//NKOColorPickerView
#import "NKOColorPickerView.h"

CGFloat const NKOPickerViewGradientViewHeight = 40.f;
CGFloat const NKOPickerViewGradientTopMargin = 20.;
CGFloat const NKOPickerViewDefaultMargin = 10.f;
CGFloat const NKOPickerViewBrightnessIndicatorWidth = 16.f;
CGFloat const NKOPickerViewBrightnessIndicatorHeight = 48.f;
CGFloat const NKOPickerViewCrossHairshWidthAndHeight = 38.f;

@interface NKOColorPickerView () {
    CGFloat _currentBrightness;
    CGFloat _currentHue;
    CGFloat _currentSaturation;
    CGFloat _currentAlpha;
    BOOL _second;
}

@property (nonatomic, strong) NKOBrightnessView *gradientView;
@property (nonatomic, strong) UIImageView *brightnessIndicator;
@property (nonatomic, strong) UIImageView *alphaIndicator;
@property (nonatomic, strong) UIImageView *hueSatImage;
@property (nonatomic, strong) UIView *crossHairs;
@property (nonatomic, strong) OpacityView *opacityView;

@end

@implementation NKOColorPickerView

- (id) initWithFrame:(CGRect)frame color:(UIColor *)color andDidChangeColorBlock:(NKOColorPickerDidChangeColorBlock)didChangeColorBlock {
    self = [super init];

    if (self != nil) {
        self.frame = frame;

        _color = color;
        _didChangeColorBlock = didChangeColorBlock;
//        self.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return self;
}

- (void) willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];

    if (_color == nil) {
        _color = [UIColor colorWithRed:1. green:1. blue:1. alpha:1.];
    }

    [self setColor:_color];
}

- (void) layoutSubviews {
    if (!_second) {
        dispatch_async_main(^{
            [self setNeedsUpdateConstraints];
        });
        _second = YES;
    }
    [super layoutSubviews];
}

- (void) updateConstraints {
    [self removeConstraints:self.constraints];

    [self hueSatImage];
    [self gradientView];
    [self opacityView];
    [self crossHairs];
    [self brightnessIndicator];
    [self alphaIndicator];
    NSNumber *defaultMargin = @(NKOPickerViewDefaultMargin);
    NSNumber *gradientMargin = @(NKOPickerViewGradientTopMargin);
    NSNumber *gradientHeight = @(NKOPickerViewGradientViewHeight);
    NSNumber *bOffset = @(_gradientView.width * (1. - _currentBrightness));
    NSNumber *aOffset = @(_gradientView.width * (1. - _currentAlpha));
    NSNumber *hOffset = @(_hueSatImage.width * _currentHue);
    NSNumber *sOffset = @((1. - _currentSaturation) * _hueSatImage.height);
    [UIView applyConstraints:@[@"V:|-defaultMargin-[_hueSatImage]-gradientMargin-[_gradientView(gradientHeight)]-gradientMargin-[_opacityView(gradientHeight)]-defaultMargin-|",
                               @"H:|-defaultMargin-[_hueSatImage]-defaultMargin-|",
                               @"H:|-defaultMargin-[_gradientView]-defaultMargin-|",
                               @"H:|-defaultMargin-[_opacityView]-defaultMargin-|",
                               @"_brightnessIndicator.centerY = _gradientView.centerY",
                               @"_brightnessIndicator.centerX = _gradientView.left + bOffset",
                               @"_alphaIndicator.centerY = _opacityView.centerY",
                               @"_alphaIndicator.centerX = _opacityView.left + aOffset",
                               @"_crossHairs.centerX = _hueSatImage.left + hOffset",
                               @"_crossHairs.centerY = _hueSatImage.top + sOffset"]
                     metrics:NSDictionaryOfVariableBindings(defaultMargin, gradientHeight, gradientMargin, bOffset, aOffset, hOffset, sOffset)
                       views:NSDictionaryOfVariableBindings(_hueSatImage, _gradientView, _opacityView, _brightnessIndicator, _alphaIndicator, _crossHairs)];

    [self updateGradientColor];
    [self updateOpacityColor];

    [super updateConstraints];
}

#pragma mark - Public methods
- (void) setTintColor:(UIColor *)tintColor {
    self.hueSatImage.layer.borderColor = tintColor.CGColor;
    self.gradientView.layer.borderColor = tintColor.CGColor;
    self.opacityView.layer.borderColor = tintColor.CGColor;
    self.brightnessIndicator.image = [[UIImage imageNamed:@"nko_brightness_guide"] nko_tintImageWithColor:tintColor];
    self.alphaIndicator.image = [[UIImage imageNamed:@"nko_brightness_guide"] nko_tintImageWithColor:tintColor];
}

- (void) setColor:(UIColor *)newColor {
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(CGColorGetColorSpace(newColor.CGColor));

    if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
        [newColor getWhite:&_currentBrightness alpha:&_currentAlpha];
        _currentHue = 0.5;
        _currentSaturation = 0.;
    } else {
        [newColor getHue:&_currentHue saturation:&_currentSaturation brightness:&_currentBrightness alpha:&_currentAlpha];
    }

    [self _setColor:newColor];
    [self setNeedsUpdateConstraints];
}

#pragma mark - Private methods
- (void) _setColor:(UIColor *)newColor {
    if (![_color isEqual:newColor]) {
        CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(CGColorGetColorSpace(newColor.CGColor));

        if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
            CGFloat brightness, alpha;
            [newColor getWhite:&brightness alpha:&alpha];
            const CGFloat *c = CGColorGetComponents(newColor.CGColor);
            _color = [UIColor colorWithHue:0
                                saturation:0
                                brightness:c[0]
                                     alpha:alpha];
        } else {
            _color = [newColor copy];
        }

        if (self.didChangeColorBlock != nil) {
            self.didChangeColorBlock(self.color);
        }
    }
}

- (void) updateGradientColor {
    UIColor *gradientColor = [UIColor colorWithHue:_currentHue
                                        saturation:_currentSaturation
                                        brightness:1.0
                                             alpha:1.0];

    self.crossHairs.layer.backgroundColor = gradientColor.CGColor;

    [self.gradientView setColor:gradientColor];
}

- (void) updateOpacityColor {
    [self.opacityView setColor:self.color];
}

- (void) updateHueSatWithMovement:(CGPoint)position {
    _currentHue = (position.x - self.hueSatImage.frame.origin.x) / self.hueSatImage.frame.size.width;
    _currentSaturation = 1.0 -  (position.y - self.hueSatImage.frame.origin.y) / self.hueSatImage.frame.size.height;

    UIColor *_tcolor = [UIColor colorWithHue:_currentHue
                                  saturation:_currentSaturation
                                  brightness:_currentBrightness
                                       alpha:_currentAlpha];
    UIColor *gradientColor = [UIColor colorWithHue:_currentHue
                                        saturation:_currentSaturation
                                        brightness:1.0
                                             alpha:1.0];


    self.crossHairs.layer.backgroundColor = gradientColor.CGColor;
    [self updateGradientColor];
    [self updateOpacityColor];
    [self _setColor:_tcolor];
}

- (void) updateBrightnessWithMovement:(CGPoint)position {
    _currentBrightness = 1.0 - ((position.x - self.gradientView.frame.origin.x) / self.gradientView.frame.size.width);

    UIColor *_tcolor = [UIColor colorWithHue:_currentHue
                                  saturation:_currentSaturation
                                  brightness:_currentBrightness
                                       alpha:_currentAlpha];
    [self _setColor:_tcolor];
}

- (void) updateAlphaWithMovement:(CGPoint)position {
    _currentAlpha = 1.0 - ((position.x - self.opacityView.frame.origin.x) / self.opacityView.frame.size.width);

    UIColor *_tcolor = [UIColor colorWithHue:_currentHue
                                  saturation:_currentSaturation
                                  brightness:_currentBrightness
                                       alpha:_currentAlpha];
    [self _setColor:_tcolor];
}


#pragma mark - Touch Handling methods
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [self dispatchTouchEvent:[touch locationInView:self]];
    }
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [self dispatchTouchEvent:[touch locationInView:self]];
    }
}

- (void) dispatchTouchEvent:(CGPoint)position {
    if (CGRectContainsPoint(self.hueSatImage.frame, position)) {
        [self updateHueSatWithMovement:position];
    } else if (CGRectContainsPoint(self.gradientView.frame, position)) {
        [self updateBrightnessWithMovement:position];
    } else if (CGRectContainsPoint(self.opacityView.frame, position)) {
        [self updateAlphaWithMovement:position];
    }

    [self setNeedsUpdateConstraints];
}

#pragma mark - Lazy loading
- (NKOBrightnessView *) gradientView {
    if (_gradientView == nil) {
        _gradientView = [[NKOBrightnessView alloc] initWithAutoLayout];
        _gradientView.layer.borderWidth = 1.f;
        _gradientView.layer.cornerRadius = 6.f;
        _gradientView.layer.borderColor = [UIColor houzzRuleColor].CGColor;
        _gradientView.layer.masksToBounds = YES;
        [self addSubview:_gradientView];
    }

    return _gradientView;
}

- (OpacityView *) opacityView {
    if (_opacityView == nil) {
        _opacityView = [[OpacityView alloc] initWithAutoLayout];
        _opacityView.layer.borderWidth = 1.f;
        _opacityView.layer.cornerRadius = 6.f;
        _opacityView.layer.borderColor = [UIColor houzzRuleColor].CGColor;
        _opacityView.layer.masksToBounds = YES;
        [self addSubview:_opacityView];
    }

    return _opacityView;
}

- (UIImageView *) hueSatImage {
    if (_hueSatImage == nil) {
        _hueSatImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"nko_colormap.png"]];
        _hueSatImage.translatesAutoresizingMaskIntoConstraints = NO;
        _hueSatImage.layer.borderWidth = 1.f;
        _hueSatImage.layer.cornerRadius = 6.f;
        _hueSatImage.layer.borderColor = [UIColor houzzRuleColor].CGColor;
        _hueSatImage.layer.masksToBounds = YES;
        [self addSubview:_hueSatImage];
    }

    return _hueSatImage;
}

- (UIView *) crossHairs {
    if (_crossHairs == nil) {
        _crossHairs = [[UIView alloc] initWithAutoLayout];
        NSNumber *dim = @(NKOPickerViewCrossHairshWidthAndHeight);
        [UIView applyConstraints:@[@"_crossHairs.height = dim",
                                   @"_crossHairs.width = dim"]
                         metrics:NSDictionaryOfVariableBindings(dim)
                           views:NSDictionaryOfVariableBindings(_crossHairs)];

        UIColor *edgeColor = [UIColor colorWithWhite:0.9 alpha:0.8];

        _crossHairs.layer.cornerRadius = 19;
        _crossHairs.layer.borderColor = edgeColor.CGColor;
        _crossHairs.layer.borderWidth = 2;
        _crossHairs.layer.shadowColor = [UIColor blackColor].CGColor;
        _crossHairs.layer.shadowOffset = CGSizeZero;
        _crossHairs.layer.shadowRadius = 1;
        _crossHairs.layer.shadowOpacity = 0.5f;
        [self insertSubview:_crossHairs aboveSubview:self.hueSatImage];
    }

    return _crossHairs;
}

- (UIImageView *) brightnessIndicator {
    if (_brightnessIndicator == nil) {
        _brightnessIndicator = [[UIImageView alloc] initWithAutoLayout];
        _brightnessIndicator.image = [[UIImage imageNamed:@"nko_brightness_guide"] nko_tintImageWithColor:[UIColor houzzDarkTextColor]];
        _brightnessIndicator.backgroundColor = [UIColor clearColor];
        [self insertSubview:_brightnessIndicator aboveSubview:self.gradientView];
    }

    return _brightnessIndicator;
}

- (UIImageView *) alphaIndicator {
    if (_alphaIndicator == nil) {
        _alphaIndicator = [[UIImageView alloc] initWithAutoLayout];
        _alphaIndicator.image = [[UIImage imageNamed:@"nko_brightness_guide"] nko_tintImageWithColor:[UIColor houzzDarkTextColor]];
        _alphaIndicator.backgroundColor = [UIColor clearColor];
        [self insertSubview:_alphaIndicator aboveSubview:self.opacityView];
    }

    return _alphaIndicator;
}

@end


// NKOBrightnessView
@interface NKOBrightnessView () {
    CGGradientRef _gradient;
}

@end

@implementation NKOBrightnessView

- (void) setColor:(UIColor *)color {
    if (_color != color) {
        _color = [color copy];
        [self setupGradient];
        [self setNeedsDisplay];
    }
}

- (void) setupGradient {
    const CGFloat *c = CGColorGetComponents(_color.CGColor);

    CGFloat colors[] = {
        c[0], c[1], c[2], 1.0f,
        0.f,  0.f,  0.f,  1.f,
    };

    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();

    if (_gradient != nil) {
        CGGradientRelease(_gradient);
    }

    _gradient = CGGradientCreateWithColorComponents(rgb, colors, NULL, sizeof(colors) / (sizeof(colors[0]) * 4));
    CGColorSpaceRelease(rgb);
}

- (void) drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGRect clippingRect = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);

    CGPoint endPoints[] =
    {
        CGPointMake(0,                     0),
        CGPointMake(self.frame.size.width, 0),
    };

    CGContextSaveGState(context);
    CGContextClipToRect(context, clippingRect);

    CGContextDrawLinearGradient(context, _gradient, endPoints[0], endPoints[1], 0);
    CGContextRestoreGState(context);
}

- (void) dealloc {
    CGGradientRelease(_gradient);
}

@end


@interface OpacityView () {
    CGGradientRef _gradient;
}

@end

@implementation OpacityView

- (void) setupGradient {
    const CGFloat *c = CGColorGetComponents(self.color.CGColor);

    CGFloat colors[] = {
        c[0], c[1], c[2], 1.0f,
        c[0], c[1], c[2], 0.f,
    };

    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();

    if (_gradient != nil) {
        CGGradientRelease(_gradient);
    }

    _gradient = CGGradientCreateWithColorComponents(rgb, colors, NULL, sizeof(colors) / (sizeof(colors[0]) * 4));
    CGColorSpaceRelease(rgb);
}

- (void) drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect clippingRect = self.bounds;

    CGContextSaveGState(context);
    CGContextClipToRect(context, clippingRect);
    UIColor *checkers = [UIColor colorWithPatternImage:[UIImage imageNamed:@"checkers"]];
    [checkers setFill];
    CGContextFillRect(context, rect);

    CGPoint endPoints[] =
    {
        CGPointMake(0,                     0),
        CGPointMake(self.frame.size.width, 0),
    };


    CGContextDrawLinearGradient(context, _gradient, endPoints[0], endPoints[1], 0);
    CGContextRestoreGState(context);
}

@end


//UIImage category
@implementation UIImage (NKO)

- (UIImage *) nko_tintImageWithColor:(UIColor *)tintColor {
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0f);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, self.size.width, self.size.height);

    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    CGContextSaveGState(ctx);
    CGContextClipToMask(ctx, area, self.CGImage);
    [tintColor set];
    CGContextFillRect(ctx, area);
    CGContextRestoreGState(ctx);
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    CGContextDrawImage(ctx, area, self.CGImage);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return newImage;
}

@end