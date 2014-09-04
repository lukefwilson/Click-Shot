//
//  CameraButton.m
//  Remote Shot
//
//  Created by Luke Wilson on 4/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "CameraButton.h"
#import "CameraViewController.h"
#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>
#import "TransferService.h"

#define ButtonDistanceFromFinger 100
#define ButtonDistancePercentage 0.75
#define ShouldDoTimedCameraAction(distance) distance > (100/0.75)
#define ShouldDoCameraActionNow(distance) distance < 45
//#define CSStateCameraModeStill 0
//#define CSStateCameraModeActionShot 1
//#define CSStateCameraModeVideo 2

#define kLargeFontSize 70
#define kMediumFontSize 60
#define kSmallFontSize 47

@interface CameraButton ()

@property (nonatomic, strong) UIImage *pictureCameraButtonImage;
@property (nonatomic, strong) UIImage *rapidCameraButtonImage;
@property (nonatomic, strong) UIImage *videoCameraButtonImage;
@property (nonatomic, strong) UIImage *pictureCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *rapidCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *videoCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *cameraButtonPlayingSound;
@property (nonatomic, strong) UIImage *darkCameraButtonBG; // used in masking process

@end

@implementation CameraButton

- (void)initialize{
    [self setNeedsLayout];
    self.prevDuration = 0;
    self.isAnimatingButton = NO;
    self.isDraggable = YES;
    self.enabled = YES;

//    self.ringMoveAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.originalCenterPosition = CGPointMake(screenSize.width/2, screenSize.height-26);
    CGRect buttonFrame = self.buttonImage.frame;
    
    [self.buttonImage removeFromSuperview];
    [self.buttonImage setTranslatesAutoresizingMaskIntoConstraints:YES];
    [self.buttonImage setFrame:buttonFrame];
    self.buttonImage.center = self.originalCenterPosition;
    [self addSubview:self.buttonImage];

    
    self.rings = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        CAShapeLayer *ring = [CAShapeLayer layer];
        switch (i) {
            case 0:
                ring.strokeColor = [CameraViewController getHighlightColor].CGColor;
                break;
            case 1:
                ring.strokeColor = [UIColor blackColor].CGColor;
                break;
            default:
                break;
        }
        ring.lineWidth = 4;
        ring.opacity = 0;
        ring.zPosition = 20;
        ring.position =  [self convertPoint:self.originalCenterPosition toView:self.buttonImage];
        ring.fillColor   = [UIColor clearColor].CGColor;
        ring.strokeEnd = 0.0;
        ring.bounds = CGRectMake(0, 0, self.buttonImage.frame.size.width-(i*6+3), self.buttonImage.frame.size.height-(i*6+3));
        ring.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, self.buttonImage.frame.size.width-(i*6+3), self.buttonImage.frame.size.height-(i*6+3))].CGPath;
        ring.anchorPoint = CGPointMake(0.5, 0.5);
        ring.transform = CATransform3DMakeRotation(270*(M_PI/180), 0.0, 0.0, 1.0);
        [self.buttonImage.layer addSublayer:ring];
        [self.rings addObject:ring];
    }

    self.soundTimerRing = [CAShapeLayer layer];
    self.soundTimerRing.lineWidth = 5;
    self.soundTimerRing.anchorPoint = CGPointMake(0.5, 0.5);

    self.soundTimerRing.opacity = 0;
    self.soundTimerRing.zPosition = 20;
    self.soundTimerRing.position =  [self convertPoint:self.originalCenterPosition toView:self.buttonImage];
    self.soundTimerRing.fillColor   = [UIColor clearColor].CGColor;
    self.soundTimerRing.strokeColor = [CameraViewController getHighlightColor].CGColor;
    self.soundTimerRing.strokeEnd = 0.0;
    self.soundTimerRing.bounds = CGRectMake(0, 0, self.buttonImage.frame.size.width-20, self.buttonImage.frame.size.height-20);
    self.soundTimerRing.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, self.buttonImage.frame.size.width-20, self.buttonImage.frame.size.height-20)].CGPath;
    self.soundTimerRing.transform = CATransform3DMakeRotation(270*(M_PI/180), 0.0, 0.0, 1.0);
    [self.buttonImage.layer addSublayer:self.soundTimerRing];

    
    self.pictureCameraButtonImage = [UIImage imageNamed:@"inner.png"];
    self.rapidCameraButtonImage = [UIImage imageNamed:@"rapidInner.png"];
    self.videoCameraButtonImage = [UIImage imageNamed:@"redInner.png"];
    self.pictureCameraButtonImageHighlighted = [UIImage imageNamed:@"innerHighlighted.png"];
    self.rapidCameraButtonImageHighlighted = [UIImage imageNamed:@"rapidInnerHighlighted.png"];
    self.videoCameraButtonImageHighlighted = [UIImage imageNamed:@"redInnerHighlighted.png"];
    self.darkCameraButtonBG = [UIImage imageNamed:@"cameraButtonDarkBG"];
    self.cameraButtonPlayingSound = [UIImage imageNamed:@"innerPlayingSound"];
    self.isHighlighted = NO;
    
    self.buttonImage.alpha = 0.8;
}

- (id)initWithCoder:(NSCoder *)aCoder{
    if(self = [super initWithCoder:aCoder]){
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)rect{
    if(self = [super initWithFrame:rect]){
        [self initialize];
    }
    return self;
}



- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    if (self.enabled) {
        
        if (self.isAnimatingButton) {
            CGPoint touchLocation = [[touches anyObject] locationInView:self.cameraController.view];
            [self cancelAnimation:touchLocation];
            self.cameraController.swipeModesGestureIsBlocked = YES;
            self.isDraggable = YES;
            [self touchesMoved:touches withEvent:event];
            if (self.cameraController.cameraMode != CSStateCameraModeStill) {
                [self.cameraController pressedCameraButton];
            }
        } else {
            self.isHighlighted = YES;
            [self updateCameraButtonWithText:self.cameraButtonString];
            self.cameraController.swipeModesGestureIsBlocked = YES;
        }
    }
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.enabled) {
        
        self.isDragging = YES;
        CGPoint touchLocation = [[touches anyObject] locationInView:self.cameraController.view];
        float distance = [self distanceBetween:self.originalCenterPosition and:touchLocation];
        if (self.isDraggable) {
            
            if (ShouldDoTimedCameraAction(distance)) {
                self.isHighlighted = NO;
                
                int duration =[self timerDurationForDistance:distance];
                if (self.prevDuration != duration) {
                    if (self.cameraController.cameraMode == CSStateCameraModeStill) {
                        [self updateCameraButtonWithText:[NSString stringWithFormat:@"%i", duration]];
                    } else {
                        [self updateCameraButtonWithText:[NSString stringWithFormat:@"0:%02i", duration]];
                    }
                    self.prevDuration = duration;
                }
                
            } else {
                if(ShouldDoCameraActionNow(distance)) {
                    self.isHighlighted = YES;
                    [self updateCameraButtonWithText:self.cameraButtonString];
                } else {
                    self.isHighlighted = NO;
                    [self updateCameraButtonWithText:@""];
                }
                if (self.prevDuration != 0) {
                    [self updateCameraButtonWithText:@""];
                    self.prevDuration = 0;
                }
            }
            self.buttonImage.center = [self getButtonPositionForTouchLocation:touchLocation];
            
            [self setNeedsDisplay];
        } else {
            self.isHighlighted = YES;
            [self updateCameraButtonWithText:self.cameraButtonString];
            if (!CGPointEqualToPoint(self.buttonImage.center, self.originalCenterPosition)) {
                self.buttonImage.center = [self getButtonPositionForTouchLocation:touchLocation];
                self.isHighlighted = NO;
                
            }
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.enabled) {
        self.isDragging = NO;
        CGPoint touchLocation = [[touches anyObject] locationInView:self.cameraController.view];
        if (self.isDraggable ) {
            float distance = [self distanceBetween:self.originalCenterPosition and:touchLocation];
            float duration;
            if (ShouldDoTimedCameraAction(distance)) {
                duration = [self timerDurationForDistance:distance];
                self.timerDuration = (int)duration;
                self.cameraTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(countdown:) userInfo:nil repeats:YES];
                if (self.cameraController.cameraMode != CSStateCameraModeStill) {
                    [self.cameraController pressedCameraButton];
                }
                
                
                // start ring animations
                for (int i = 0; i < [self.rings count]; i++) {
                    CAShapeLayer *ring = [self.rings objectAtIndex:i];
                    ring.opacity = 1;
                    
                    ring.strokeEnd = 1.0; // set the model ring stroke end
                    
                    switch (i) {
                        case 0: {
                            CABasicAnimation *endToFront = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
                            endToFront.fromValue   = [NSNumber numberWithFloat:0.0];
                            endToFront.toValue     = [NSNumber numberWithFloat:1.0];
                            endToFront.duration    = 1;
                            
                            // fade out the ring part way thru the animation
                            CABasicAnimation *frontToEnd = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
                            frontToEnd.fromValue   = [NSNumber numberWithFloat:0.0];
                            frontToEnd.toValue     = [NSNumber numberWithFloat:1.0];
                            frontToEnd.duration    = 1;
                            frontToEnd.beginTime = 1;
                            
                            
                            CAAnimationGroup* group = [CAAnimationGroup animation];
                            group.duration    = 2;
                            group.animations  = [NSArray arrayWithObjects:endToFront, frontToEnd, nil];
                            group.repeatCount = duration/2;
                            [ring addAnimation:group forKey:nil];
                            
                            
                            if (self.cameraController.cameraMode != CSStateCameraModeStill) {
                                ring.strokeColor = [UIColor whiteColor].CGColor;
                            } else {
                                ring.strokeColor = [CameraViewController getHighlightColor].CGColor;
                            }
                            
                            break;
                        }
                        case 1: {
                            
                            CABasicAnimation *ringAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
                            ringAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
                            ringAnimation.toValue = [NSNumber numberWithFloat:1.0f];
                            ringAnimation.duration = duration;
                            ringAnimation.repeatCount = 1;
                            [ring addAnimation:ringAnimation forKey:@"strokeEndAnimation"];
                            
                            break;
                        }
                        default:
                            break;
                    }
                    
                }
                self.isAnimatingButton = YES;
                
                [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:NO];
                
                self.cameraController.cameraRollButton.enabled = NO;
                
            } else if (ShouldDoCameraActionNow(distance)) {
                [self.cameraController pressedCameraButton];
                [self updateCameraButtonWithText:@""];
                duration = 0.1;
            } else {
                [self updateCameraButtonWithText:@""];
                duration = 0.1;
            }
            
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState  animations:^{
                self.buttonImage.center = self.originalCenterPosition;
            } completion:^(BOOL finished){
                if (finished && ShouldDoTimedCameraAction(distance)) {
                    for (CAShapeLayer *ring in self.rings) {
                        ring.opacity = 0;
                    }
                    [self.cameraController pressedCameraButton];
                    self.isAnimatingButton = NO;
                    self.cameraController.swipeModesGestureIsBlocked = NO;
                    
                    [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:YES];
                    self.cameraController.cameraRollButton.enabled = YES;
                    
                }
            }];
        } else {
            if ([[_buttonImage.layer presentationLayer] hitTest:touchLocation]) {
                [self.cameraController pressedCameraButton];
            }
        }
        self.isHighlighted = NO;
        [self updateCameraButtonWithText:self.cameraButtonString];
        if (!self.isAnimatingButton) self.cameraController.swipeModesGestureIsBlocked = NO;
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(CGPoint)getButtonPositionForTouchLocation:(CGPoint)touchLocation {
    float distance = [self distanceBetween:self.originalCenterPosition and:touchLocation];
    float vec[] = {(self.originalCenterPosition.x-touchLocation.x), (self.originalCenterPosition.y-touchLocation.y)};
    float magnitude = sqrtf(vec[0]*vec[0]+vec[1]*vec[1]);
    float normalizedVec[] = {vec[0] / magnitude, vec[1] / magnitude};
    if (ShouldDoTimedCameraAction(distance)) {
        return CGPointMake(touchLocation.x+(ButtonDistanceFromFinger*normalizedVec[0]), touchLocation.y+(ButtonDistanceFromFinger*normalizedVec[1]));
    } else {
        return CGPointMake(touchLocation.x+((distance*ButtonDistancePercentage)*normalizedVec[0]), touchLocation.y+((distance*ButtonDistancePercentage)*normalizedVec[1]));
    }
}

-(void)animateSoundRingForDuration:(float)soundDuration {
    self.enabled = NO;
    [self updateCameraButtonWithText:@""]; // turn on sound symbol
    [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:NO];
    self.cameraController.cameraRollButton.enabled = NO;
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        _soundTimerRing.opacity = 0;
        self.enabled = YES;
        self.cameraController.cameraRollButton.enabled = YES;
        [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:YES];
    }];
    _soundTimerRing.opacity = 1;
    CABasicAnimation *ringAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    ringAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    ringAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    ringAnimation.duration = soundDuration;
    ringAnimation.repeatCount = 1;
    [_soundTimerRing addAnimation:ringAnimation forKey:@"strokeEndAnimation"];

    [CATransaction commit];

}

// Only take touches that are inside the camera button
-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.cameraController.settingsMenuIsOpen) {
        return NO;
    } else if ([[_buttonImage.layer presentationLayer] hitTest:point]) {
        return YES;
    }
    return NO;
}

-(int)timerDurationForDistance:(float)distance {
    if (self.cameraController.cameraMode == CSStateCameraModeStill) {
        return distance/50;
    } else {
        return distance/25;
    }
}

-(float)distanceBetween:(CGPoint)point1 and:(CGPoint)point2 {
    float xDif =point2.x-point1.x;
    float yDif = point2.y-point1.y;
    return sqrtf(xDif*xDif + yDif*yDif);
}

-(void)countdown:(NSTimer *)timer {
    self.timerDuration--;
    if (self.timerDuration > 0) {
        if (self.cameraController.cameraMode == CSStateCameraModeStill) {
            [self updateCameraButtonWithText:[NSString stringWithFormat:@"%i", self.timerDuration]];
        } else {
            [self updateCameraButtonWithText:[NSString stringWithFormat:@"0:%02i", self.timerDuration]];
        }
    } else {
        [timer invalidate];
        [self updateCameraButtonWithText:@""];
    }
}

// called by touchesBegan if isAnimatingButton
-(void)cancelAnimation:(CGPoint) touchPoint {
    for (int i = 0; i < [self.rings count]; i++) {
        CAShapeLayer *ring = [self.rings objectAtIndex:i];
        ring.opacity = 0;
        [ring removeAllAnimations];
    }
    [_cameraTimer invalidate];
    [self updateCameraButtonWithText:@""];

    [UIView animateWithDuration:0.05 delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.buttonImage.center = touchPoint;
    } completion:nil];
    
    self.isAnimatingButton = NO;

    [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:YES];

    self.cameraController.cameraRollButton.enabled = YES;
}

-(void)cancelTimedAction { // called when view will disappear if is animating
    for (int i = 0; i < [self.rings count]; i++) {
        CAShapeLayer *ring = [self.rings objectAtIndex:i];
        ring.opacity = 0;
        [ring removeAllAnimations];
    }
    [_cameraTimer invalidate];
    [self updateCameraButtonWithText:@""];
    
    [UIView animateWithDuration:0.05 delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.buttonImage.center = _originalCenterPosition;
    } completion:nil];
    
    self.isAnimatingButton = NO;
    
    [self.cameraController enableProperCameraModeButtonsForCurrentCameraMode:YES];
    
    self.cameraController.cameraRollButton.enabled = YES;
    
    self.cameraController.swipeModesGestureIsBlocked = NO;
}

-(void)updateCameraButtonWithText:(NSString *)text {
    self.cameraButtonString = text;
    
    if ([text isEqualToString:@""]) {
            self.buttonImage.image = [self currentPlainCameraButtonImage];
    } else {
        switch (self.cameraController.cameraMode) {
            case CSStateCameraModeStill: {
                self.buttonImage.image = [self maskImage:[self currentPlainCameraButtonImage] withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kLargeFontSize];
                break;
            }
            case CSStateCameraModeActionShot: {
                if (self.isAnimatingButton) {
                    self.buttonImage.image = [self maskImage:self.videoCameraButtonImage withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
                } else {
                    if (self.isHighlighted) {
                        self.buttonImage.image = [self maskImage:self.pictureCameraButtonImageHighlighted withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kMediumFontSize];
                    } else {
                        if (self.isDragging) {
                            self.buttonImage.image = [self maskImage:self.pictureCameraButtonImage withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
                        } else {
                            self.buttonImage.image = [self maskImage:self.pictureCameraButtonImage withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kMediumFontSize];
                        }
                    }
                }
                break;
            }
            case CSStateCameraModeVideo: {
                if (self.isDragging || self.isAnimatingButton) {
                    self.buttonImage.image = [self maskImage:[self currentPlainCameraButtonImage] withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
                } else {
                    if (self.cameraController.lockedOrientation == UIDeviceOrientationLandscapeLeft) {
                        self.buttonImage.image = [self maskImage:[self currentPlainCameraButtonImage] withMaskText:_cameraButtonString offsetFromCenter:CGPointMake(-7, 0) fontSize:kSmallFontSize];
                    } else if (self.cameraController.lockedOrientation == UIDeviceOrientationLandscapeRight) {
                        self.buttonImage.image = [self maskImage:[self currentPlainCameraButtonImage] withMaskText:_cameraButtonString offsetFromCenter:CGPointMake(7, 0) fontSize:kSmallFontSize];
                    } else {
                        self.buttonImage.image = [self maskImage:[self currentPlainCameraButtonImage] withMaskText:_cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
                    }
                }

                break;
            }
            default: {
                break;
            }
        }
    }
}

-(UIImage *)currentPlainCameraButtonImage {
    switch (self.cameraController.cameraMode) {
        case CSStateCameraModeStill:
            if (self.isHighlighted) {
                return self.pictureCameraButtonImageHighlighted;
            } else {
                if (self.cameraController.takePictureAfterSound) {
                    return self.cameraButtonPlayingSound;
                } else {
                    return self.pictureCameraButtonImage;
                }
            }
            break;
        case CSStateCameraModeActionShot:
            if (self.isHighlighted) {
                return self.rapidCameraButtonImageHighlighted;
            } else {
                return self.rapidCameraButtonImage;
            }
        case CSStateCameraModeVideo:
            if (self.isHighlighted) {
                return self.videoCameraButtonImageHighlighted;
            } else {
                return self.videoCameraButtonImage;
            }
        default:
            return self.pictureCameraButtonImage;
            break;
    }
}

-(void)updateCameraButtonImageForCurrentCameraMode {
    [UIView transitionWithView:self
                      duration:0.35f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.buttonImage.image = [self currentPlainCameraButtonImage];
                    } completion:nil];
}

//-(void)updateCameraButtonImagePlayingSound {
////    [UIView transitionWithView:self
////                      duration:0.35f
////                       options:UIViewAnimationOptionTransitionCrossDissolve
////                    animations:^{
//                        self.buttonImage.image = self.cameraButtonPlayingSound;
////                    } completion:nil];
//}


- (UIImage*) maskImage:(UIImage *)image withMaskText:(NSString *)maskText offsetFromCenter:(CGPoint)offset fontSize:(float)fontSize {
    
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    // Create a context for our text mask
    UIGraphicsBeginImageContextWithOptions(image.size, YES, 1);
    CGContextRef textMaskContext = UIGraphicsGetCurrentContext();
    
	// Draw a white background
	[[UIColor whiteColor] setFill];
	CGContextFillRect(textMaskContext, imageRect);
    // Draw black text
    [[UIColor blackColor] setFill];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attr = @{NSParagraphStyleAttributeName: paragraphStyle,
                           NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Thin" size:fontSize],
                           NSForegroundColorAttributeName: [UIColor blackColor]};
    
    CGSize textSize = [maskText sizeWithAttributes:attr];
	[maskText drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y) withAttributes:attr];
    
    //add small number for action shooting + animation
    if (self.cameraController.videoProcessor.actionShooting && self.isAnimatingButton && self.cameraController.actionShotSequenceNumber > 0) {
        attr = @{NSParagraphStyleAttributeName: paragraphStyle,
                 NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Thin" size:24],
                 NSForegroundColorAttributeName: [UIColor blackColor]};
        NSString *sequenceNumString = [NSString stringWithFormat:@"%i", self.cameraController.actionShotSequenceNumber];
        textSize = [sequenceNumString sizeWithAttributes:attr];
        [sequenceNumString  drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y-35) withAttributes:attr];
    }
    
	// Create an image from what we've drawn
	CGImageRef textAlphaMask = CGBitmapContextCreateImage(textMaskContext);
    CGContextRelease(textMaskContext);
    
    // create a bitmap graphics context the size of the image
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef mainImageContext = CGBitmapContextCreate (NULL, image.size.width, image.size.height, CGImageGetBitsPerComponent(image.CGImage), 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(mainImageContext, imageRect, self.darkCameraButtonBG.CGImage); // for semi-transparent dark number
    CGContextClipToMask(mainImageContext, imageRect, textAlphaMask);
    CGContextDrawImage(mainImageContext, imageRect, image.CGImage);
    
    CGImageRef finishedImage =CGBitmapContextCreateImage(mainImageContext);
    UIImage *finalMaskedImage = [UIImage imageWithCGImage: finishedImage];
    
    CGImageRelease(finishedImage);
    CGContextRelease(mainImageContext);
    CGImageRelease(textAlphaMask);
    CGColorSpaceRelease(colorSpace);
    
    // return the image
    return finalMaskedImage;
    
}


@end
