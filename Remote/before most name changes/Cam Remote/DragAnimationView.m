//
//  DragAnimationView.m
//  Click-Shot
//
//  Created by Luke Wilson on 7/27/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "DragAnimationView.h"

@implementation DragAnimationView

CGPoint animationsFirstTouchLocation;
CGPoint prevTouchPoint;
CGFloat velocity;
NSTimeInterval prevTimestamp;

static CGFloat const velocityDivider = 600;
static CGFloat const guarenteedVelocity = 600;
static CGFloat const guarenteedRatio = 0.3;

- (id)initWithFrame:(CGRect)frame animations:(NSArray *)animations {
    self = [super initWithFrame:frame];
    if (self) {
        _animationSteps = animations;
        _currentAnimationStep = 0;
        _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    animationsFirstTouchLocation = [touch locationInView:self.superview];
    prevTimestamp = event.timestamp;
    prevTouchPoint = animationsFirstTouchLocation;
    velocity = 0;
    _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];

    if ([self.delegate respondsToSelector:@selector(dragAnimationViewPressed:)]) {
        [self.delegate dragAnimationViewPressed:self];
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self.superview];
    CGFloat ratio = [self animationRatioForTouchPoint:touchPoint];
    velocity = [self velocityForNextTouchPoint:touchPoint andTimeStamp:event.timestamp];
    
    _currentAnimationStepRatio = ratio;

//    _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
    
//    NSLog(@"velocity: %f step: %li - ratio: %f - distance: %f - first touch: %@", velocity,(long)_currentAnimationStep, _currentAnimationStepRatio, _currentAnimationStepDistance, NSStringFromCGPoint(animationsFirstTouchLocation));
    NSArray *animations = [_animationSteps objectAtIndex:_currentAnimationStep];
    for (NSArray *array in animations) {
        UIView *view = [array objectAtIndex:0];
        CABasicAnimation *viewAnimations = [array objectAtIndex:1];
        viewAnimations.timeOffset = ratio;
        [view.layer removeAllAnimations];
        [view.layer addAnimation:viewAnimations forKey:@"dragAnimation"];
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_currentAnimationStepRatio == 0 && velocity == 0) {
        if ([self.delegate respondsToSelector:@selector(dragAnimationViewTapped:atAnimationStep:)]) {
            [self.delegate dragAnimationViewTapped:self atAnimationStep:_currentAnimationStep];
        }
    } else {
        NSArray *animations = [_animationSteps objectAtIndex:_currentAnimationStep];
        BOOL pullingUp = [self determineDirection];
        NSMutableArray *viewsToAnimate = [NSMutableArray array];
        NSMutableArray *animationsForViews = [NSMutableArray array];
        
        for (NSArray *array in animations) {
            UIView *view = [array objectAtIndex:0];
            CABasicAnimation *viewAnimation = [array objectAtIndex:1];
            
            CABasicAnimation *newAnimation = [CABasicAnimation animationWithKeyPath:viewAnimation.keyPath];
            
            NSValue *toValue;
            CGFloat subtractFromDuration;
            if (pullingUp) {
                toValue = viewAnimation.toValue;
                subtractFromDuration = _currentAnimationStepRatio;
            } else {
                toValue = viewAnimation.fromValue;
                subtractFromDuration = 1-_currentAnimationStepRatio;
            }
            
            newAnimation.duration = 1-subtractFromDuration;
            newAnimation.timeOffset = 0;
            newAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            newAnimation.speed = 1+fabs(velocity/velocityDivider);
            newAnimation.removedOnCompletion = NO;
            newAnimation.fillMode = kCAFillModeForwards;
            view.layer.position = [toValue CGPointValue];
            newAnimation.toValue = toValue;
            [viewsToAnimate addObject:view];
            [animationsForViews addObject:newAnimation];
            
        }
        
        [CATransaction begin]; {
            [CATransaction setCompletionBlock:^{
                for (UIView *view in viewsToAnimate) {
                    [view.layer removeAllAnimations];
                }
                if ([self.delegate respondsToSelector:@selector(dragAnimationView:finishedAtAnimationStep:)]) {
                    [self.delegate dragAnimationView:self finishedAtAnimationStep:_currentAnimationStep];
                }
            }];
            for (int i = 0; i < [viewsToAnimate count]; i++) {
                UIView *view = [viewsToAnimate objectAtIndex:i];
                [view.layer addAnimation:[animationsForViews objectAtIndex:i] forKey:@"finishAnimation"];
            }
        } [CATransaction commit];
        
        if (pullingUp) {
            _currentAnimationStep++;
        }
        
        _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
        _currentAnimationStepRatio = 0;
        
//        NSLog(@"FINISHED WITH step: %i - ratio: %f - distance: %f - first touch: %@", _currentAnimationStep, _currentAnimationStepRatio, _currentAnimationStepDistance, NSStringFromCGPoint(animationsFirstTouchLocation));
    }
    if ([self.delegate respondsToSelector:@selector(dragAnimationViewReleased:)]) {
        [self.delegate dragAnimationViewReleased:self];
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(CGFloat)velocityForNextTouchPoint:(CGPoint)touchPoint andTimeStamp:(NSTimeInterval)timestamp {
    CGFloat distanceDif = prevTouchPoint.y-touchPoint.y;
    prevTouchPoint = touchPoint;
    NSTimeInterval timeDif = timestamp - prevTimestamp;
    prevTimestamp = timestamp;
    return distanceDif/timeDif;
}

-(CGFloat)animationRatioForTouchPoint:(CGPoint)location {
    CGFloat yDifference = animationsFirstTouchLocation.y - location.y;
    CGFloat ratio = yDifference/_currentAnimationStepDistance;
    if (ratio == 1) ratio = 0.9999;
    if (ratio < 0) {
        if (_currentAnimationStep > 0) { // change animation to previous one
            _currentAnimationStep--;
            _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
            animationsFirstTouchLocation = CGPointMake(location.x, location.y+_currentAnimationStepDistance);
            ratio = [self animationRatioForTouchPoint:location];
            if ([self.delegate respondsToSelector:@selector(dragAnimationView:beganAnimationStep:)]) {
                [self.delegate dragAnimationView:self beganAnimationStep:_currentAnimationStep];
            }
        } else {  // no previous animation available
            ratio = 0;
        }
    } else if (ratio > 1) {
        if (_currentAnimationStep < [_animationSteps count]-1) { // change animation to previous one
            animationsFirstTouchLocation = location; //CGPointMake(animationsFirstTouchLocation.x, location.y-[self animationDistanceForAnimationStep:_currentAnimationStep]);
            _currentAnimationStep++;
            _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
            ratio = [self animationRatioForTouchPoint:animationsFirstTouchLocation];
            if ([self.delegate respondsToSelector:@selector(dragAnimationView:beganAnimationStep:)]) {
                [self.delegate dragAnimationView:self beganAnimationStep:_currentAnimationStep];
            }
        } else if (_currentAnimationStep >= [_animationSteps count]-1) {
            _currentAnimationStep =[_animationSteps count]-1;
            ratio = 0.9999;
        } else {  // no next animation available
            ratio = 0.9999;
        }
    } else if (_currentAnimationStep > [self.animationSteps count]-1) {
        _currentAnimationStep--;
        _currentAnimationStepDistance = [self.delegate dragAnimationDistanceForView:self animationStep:_currentAnimationStep];
        animationsFirstTouchLocation = CGPointMake(location.x, location.y+_currentAnimationStepDistance);
        ratio = 0.9999;
    }
    return ratio;
}

-(BOOL)determineDirection {
    if (_currentAnimationStepRatio == 0 && velocity == 0) {
        return YES;
    } else if (velocity < -guarenteedVelocity) { // pulling down
        return NO;
    } else if (velocity > guarenteedVelocity) { // pulling up
        return YES;
    } else if (_currentAnimationStepRatio < guarenteedRatio) {
        return NO;
    } else if (1-_currentAnimationStepRatio < guarenteedRatio) {
        return YES;
    } else if (velocity > 0) {
        return YES;
    } else {
        return NO;
    }
}

// keep a number within bounds
-(CGFloat)clamp:(CGFloat)number between:(CGFloat)min and:(CGFloat)max {
    if (number > max) {
        return max;
    } else if (number < min) {
        return min;
    } else {
        return number;
    }
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect
 {
 // Drawing code
 }
 */

@end
