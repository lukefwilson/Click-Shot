//
//  SAVideoRangeSlider.m
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2013 Andrei Solovjev - http://solovjev.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SAVideoRangeSlider.h"

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *centerView;
@property (nonatomic, strong) AVURLAsset *videoAsset;
@property (nonatomic, strong) SASliderLeft *leftThumb;
@property (nonatomic, strong) SASliderRight *rightThumb;
@property (nonatomic, strong) SAScrubber *scrubber;

@property (nonatomic, strong) SAResizibleBubble *rangePopoverBubble;
@property (nonatomic, strong) SAResizibleBubble *scrubberPopoverBubble;
@property (nonatomic, strong) NSMutableArray *timelineImageViews;
@property (nonatomic, strong) NSMutableArray *fetchImageThreads;

@end

@implementation SAVideoRangeSlider


#define SLIDER_BORDERS_SIZE 3.0f
#define BG_VIEW_BORDERS_SIZE 3.0f
#define PIC_WIDTH 20


- (id)initWithFrame:(CGRect)frame videoAsset:(AVURLAsset *)videoAsset{
    
    self = [super initWithFrame:frame];
    if (self) {
                
        int thumbWidth = ceil(frame.size.width*0.05);
        self.minGap = 0;
        
        
        _bgView = [[UIControl alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor grayColor].CGColor;
        _bgView.backgroundColor = [UIColor colorWithWhite:0.158 alpha:1.000];
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        [self addSubview:_bgView];
        
        _videoAsset = videoAsset;
        
        
        _topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE)];
        _topBorder.backgroundColor = [UIColor colorWithRed:0.560 green:0.895 blue:0.984 alpha:1.000];
        [self addSubview:_topBorder];
        
        
        _bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE)];
        _bottomBorder.backgroundColor = [UIColor colorWithRed:0.239 green: 0.835 blue: 0.984 alpha:1.000];
        [self addSubview:_bottomBorder];
        
        
        _leftThumb = [[SASliderLeft alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        _leftThumb.contentMode = UIViewContentModeLeft;
        _leftThumb.userInteractionEnabled = YES;
        _leftThumb.clipsToBounds = YES;
        _leftThumb.backgroundColor = [UIColor clearColor];
        _leftThumb.layer.borderWidth = 0;
        [self addSubview:_leftThumb];
        
        
        UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftPan:)];
        [_leftThumb addGestureRecognizer:leftPan];
        
        
        _rightThumb = [[SASliderRight alloc] initWithFrame:CGRectMake(self.frame.size.width-thumbWidth, 0, thumbWidth, frame.size.height)];
        _rightThumb.contentMode = UIViewContentModeRight;
        _rightThumb.userInteractionEnabled = YES;
        _rightThumb.clipsToBounds = YES;
        _rightThumb.backgroundColor = [UIColor clearColor];
        [self addSubview:_rightThumb];
        
        UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightPan:)];
        [_rightThumb addGestureRecognizer:rightPan];
        
        _rightPosition = self.frame.size.width-thumbWidth;
        _leftPosition = thumbWidth;
        
        
        
        _centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _centerView.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerView];
        
        UIPanGestureRecognizer *centerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCenterPan:)];
        [_centerView addGestureRecognizer:centerPan];
        
        
        _rangePopoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, self.frame.size.height, 120, 60)];
        _rangePopoverBubble.alpha = 0;
        _rangePopoverBubble.backgroundColor = [UIColor clearColor];
        [self addSubview:_rangePopoverBubble];
        
        _rangeBubbleText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _rangePopoverBubble.frame.size.width, _rangePopoverBubble.frame.size.height)];
        _rangeBubbleText.font = [UIFont boldSystemFontOfSize:12];
        _rangeBubbleText.backgroundColor = [UIColor clearColor];
        _rangeBubbleText.textColor = [UIColor blackColor];
        _rangeBubbleText.textAlignment = NSTextAlignmentCenter;
        
        [_rangePopoverBubble addSubview:_rangeBubbleText];
        
        _scrubber = [[SAScrubber alloc] initWithFrame:CGRectMake(0, 0, 15*2, self.frame.size.height)]; // 15*2 for extra 15 pixels of touchable, clear space
        _scrubber.center = CGPointMake(thumbWidth, _scrubber.center.y);
        _scrubberPosition = thumbWidth;
        [self addSubview:_scrubber];
        UIPanGestureRecognizer *scrubberPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrubberPan:)];
        [_scrubber addGestureRecognizer:scrubberPan];
        
        _scrubberPopoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, self.frame.size.height, 100, 55)];
        _scrubberPopoverBubble.alpha = 0;
        _scrubberPopoverBubble.backgroundColor = [UIColor clearColor];
        [self addSubview:_scrubberPopoverBubble];
        
        _scrubberBubbleText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _scrubberPopoverBubble.frame.size.width, _scrubberPopoverBubble.frame.size.height)];
        _scrubberBubbleText.font = [UIFont boldSystemFontOfSize:12];
        _scrubberBubbleText.backgroundColor = [UIColor clearColor];
        _scrubberBubbleText.textColor = [UIColor blackColor];
        _scrubberBubbleText.textAlignment = NSTextAlignmentCenter;
        
        [_scrubberPopoverBubble addSubview:_scrubberBubbleText];
        
        _durationSeconds = CMTimeGetSeconds([_videoAsset duration]);
        
        // use main queue to custom draw our views
        dispatch_async(dispatch_get_main_queue(), ^{
            [_scrubber setNeedsDisplay];
            [_leftThumb setNeedsDisplay];
            [_rightThumb setNeedsDisplay];
            [_rangePopoverBubble setNeedsDisplay];
            [_scrubberPopoverBubble setNeedsDisplay];
        });
        [self setUpTimelineImages];
        [self getMovieFramesAsync];
        [self layoutSubviews];
    }
    return self;
}

-(void)setRangePopoverBubbleFrame:(CGRect)newFrame{
    _rangePopoverBubble.frame = newFrame;
    _rangeBubbleText.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
}

-(void)setScrubberPopoverBubbleFrame:(CGRect)newFrame{
    _scrubberPopoverBubble.frame = newFrame;
    _scrubberBubbleText.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
}

-(void)updateFrame:(CGRect)frame {
    if (!CGRectEqualToRect(frame, self.frame)) {
        int thumbWidth = ceil(frame.size.width*0.05);
        float leftThumbTimePosition = [self leftTimePosition];
        float rightThumbTimePosition = [self rightTimePosition];
        float scrubberTimePosition = [self scrubberTimePosition];
        
        self.frame = frame;
        
        
        _bgView.frame = CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height);
        _topBorder.frame = CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE);
        _bottomBorder.frame = CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE);
        _leftThumb.frame = CGRectMake(0, 0, thumbWidth, frame.size.height);
        _rightThumb.frame = CGRectMake(self.frame.size.width-thumbWidth, 0, thumbWidth, frame.size.height);
        _centerView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        
        _leftPosition = [self positionForTime:leftThumbTimePosition];
        _rightPosition = [self positionForTime:rightThumbTimePosition];
        _scrubberPosition = [self positionForTime:scrubberTimePosition];
        
        // use main queue to custom draw our views
        dispatch_async(dispatch_get_main_queue(), ^{
            [_scrubber setNeedsDisplay];
            [_leftThumb setNeedsDisplay];
            [_rightThumb setNeedsDisplay];
            [_rangePopoverBubble setNeedsDisplay];
            [_scrubberPopoverBubble setNeedsDisplay];
        });
        for (UIImageView *imageView in self.timelineImageViews) {
            [imageView removeFromSuperview];
        }
        if (self.imageGenerator) [self.imageGenerator cancelAllCGImageGeneration];
        [self setUpTimelineImages];
        [self getMovieFramesAsync];
        [self layoutSubviews];
    }
}

#pragma mark - Gestures

- (void)handleLeftPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        if (_leftPosition < _leftThumb.frame.size.width) {
            _leftPosition = _leftThumb.frame.size.width;
        }
        
        if (_rightPosition-_leftPosition <= _minGap){
            _leftPosition -= translation.x;
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        _scrubberPosition = _leftPosition;
        [_delegate videoRange:self didChangeStartTime:[self leftTimePosition]];
        [_delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
    }
    
    _rangePopoverBubble.alpha = 1;
    [self setRangeTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_rangePopoverBubble];
    }
    
    [self updateScrubberPosition];
    [self updateLeftThumbPosition];
    [self updateDependentViewPositions];
}



- (void)handleRightPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        _rightPosition += translation.x;
        if (_rightPosition > self.frame.size.width-_rightThumb.frame.size.width){
            _rightPosition = self.frame.size.width-_rightThumb.frame.size.width;
        }
        
        if (_rightPosition-_leftPosition <= _minGap){
            _rightPosition -= translation.x;
        }
        
        if (_rightPosition < _scrubberPosition) {
            _scrubberPosition = _rightPosition;
            [self updateScrubberPosition];
            [_delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [_delegate videoRange:self didChangeEndTime:[self rightTimePosition]];
        
    }
    
    _rangePopoverBubble.alpha = 1;
    [self setRangeTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self hideBubble:_rangePopoverBubble];
    }
    
    [self updateRightThumbPosition];
    [self updateDependentViewPositions];
}

- (void)handleCenterPan:(UIPanGestureRecognizer *)gesture
{
    
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        _rightPosition += translation.x;
        
        if (_rightPosition > self.frame.size.width-_rightThumb.frame.size.width || _leftPosition < _leftThumb.frame.size.width){
            _leftPosition -= translation.x;
            _rightPosition -= translation.x;
        } else {
            _scrubberPosition = _leftPosition;
            [_delegate videoRange:self didChangeStartTime:[self leftTimePosition] endTime:[self rightTimePosition]];
            [_delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
            [self layoutSubviews];
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
    }
    
    _rangePopoverBubble.alpha = 1;
    [self setRangeTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_rangePopoverBubble];
    }
    
}

- (void)handleScrubberPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _scrubberPosition += translation.x;
        
        [gesture setTranslation:CGPointZero inView:self];
        
        if (_scrubberPosition < _leftPosition) {
            _scrubberPosition = _leftPosition;
        } else if (_scrubberPosition > _rightPosition) {
            _scrubberPosition = _rightPosition;
        }
        
        [self.delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
        _scrubberPopoverBubble.alpha = 1;
        [self setScrubberTimeLabel:[self scrubberTimePosition]];
        
        [self updateScrubberPosition];
        [self updateDependentViewPositions];
    } else if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_scrubberPopoverBubble];
    }
}

-(void)updateLeftThumbPosition {
    _leftThumb.frame = CGRectMake(_leftPosition-_leftThumb.frame.size.width, _leftThumb.frame.origin.y, _leftThumb.frame.size.width, _leftThumb.frame.size.height);
}

-(void)updateRightThumbPosition {
    _rightThumb.frame = CGRectMake(_rightPosition, _rightThumb.frame.origin.y, _rightThumb.frame.size.width, _rightThumb.frame.size.height);
}

-(void)updateScrubberPosition {
    _scrubber.center = CGPointMake(_scrubberPosition, _scrubber.center.y);
}

-(void)updateDependentViewPositions {
    _topBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, 0, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    _bottomBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _bgView.frame.size.height-SLIDER_BORDERS_SIZE, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    _centerView.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _centerView.frame.origin.y, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width, _centerView.frame.size.height);
    
    // center range popover
    CGRect frame = _rangePopoverBubble.frame;
    frame.origin.x = _centerView.frame.origin.x+_centerView.frame.size.width/2-frame.size.width/2;
    _rangePopoverBubble.frame = frame;
    
    // position scrubber popover bubble beneath scrubber
    _scrubberPopoverBubble.center = CGPointMake(_scrubberPosition, _scrubberPopoverBubble.center.y);
    
    [self fixOffscreenPopoverBubble:_scrubberPopoverBubble];
    [self fixOffscreenPopoverBubble:_rangePopoverBubble];
}

- (void)layoutSubviews {
    [self updateLeftThumbPosition];
    [self updateRightThumbPosition];
    [self updateScrubberPosition];
    [self updateDependentViewPositions];
}

-(void)fixOffscreenPopoverBubble:(UIView *)popover {
    if (popover.frame.origin.x < 0) {
        CGRect frame = popover.frame;
        frame.origin = CGPointMake(0, frame.origin.y);
        popover.frame = frame;
    } else if (popover.frame.origin.x + popover.frame.size.width > self.frame.size.width) {
        CGRect frame = popover.frame;
        frame.origin = CGPointMake(self.frame.size.width - popover.frame.size.width, frame.origin.y);
        popover.frame = frame;
    }
}

-(void)updateScrubberWithCurrentPlayTime:(NSTimeInterval)time {
    if (!isnan(time) && !isnan(self.durationSeconds)) {
        if (time < 0) time = 0;
        CGFloat ratio = time/(CGFloat)_durationSeconds;
        CGFloat position = (ratio * (self.frame.size.width-( _leftThumb.frame.size.width*2)) ) + _leftThumb.frame.size.width;
        _scrubberPosition = position;
//    NSLog(@"time = %f", time);
        _scrubber.center = CGPointMake(_scrubberPosition, _scrubber.center.y);
    }
}


#pragma mark - Video

-(void)setUpTimelineImages {
    int picCount = ceil(_bgView.frame.size.width / PIC_WIDTH);
    self.timelineImageViews = [NSMutableArray array];
    for (int i = 0; i < picCount; i++) {
        UIImageView *tmp = [[UIImageView alloc] initWithFrame:CGRectMake(i*PIC_WIDTH, 0, PIC_WIDTH, _bgView.frame.size.height)];
        tmp.clipsToBounds = YES;
        tmp.contentMode = UIViewContentModeScaleAspectFill;
        [_bgView addSubview:tmp];
        [self.timelineImageViews addObject:tmp];
    }
}

-(void)getMovieFramesAsync {
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:_videoAsset];
    self.imageGenerator.appliesPreferredTrackTransform = YES;
    BOOL isRetina = [self isRetina];

    if (isRetina){
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*2, _bgView.frame.size.height*2);
    } else {
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width, _bgView.frame.size.height);
    }
    NSMutableArray *times = [NSMutableArray array];
    for (int i = 0; i < [self.timelineImageViews count]; i++) {
        float frameAtTime = ((i*PIC_WIDTH)/_bgView.frame.size.width)*_durationSeconds;
        frameAtTime += 0.1; // add 0.1 so the first pic isn't the first frame (because it may be black)
        CMTime frameTime = CMTimeMakeWithSeconds(MIN(frameAtTime, _durationSeconds), 600);
        [times addObject:[NSValue valueWithCMTime:frameTime]];
    }
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            int i = [times indexOfObject:[NSValue valueWithCMTime:requestedTime]];
            CFRetain(image);
            dispatch_async(dispatch_get_main_queue(), ^{ // fade in new images on main queue as they load
                if (i > [self.timelineImageViews count]-1 || i == NSNotFound || !image) {
                    NSLog(@"saved a crash");
                    return;
                }
                UIImageView *tmp = [self.timelineImageViews objectAtIndex:i];
                int totalWidthCovered = (i+1)*PIC_WIDTH;
                if (totalWidthCovered > _bgView.frame.size.width){
                    CGRect imageViewFrame = tmp.frame;
                    int delta = totalWidthCovered - _bgView.frame.size.width;
                    imageViewFrame.size.width -= delta;
                    tmp.frame = imageViewFrame;
                }
                UIImage *videoFrame;
                if (isRetina){
                    videoFrame = [[UIImage alloc] initWithCGImage:image scale:2.0 orientation:UIImageOrientationUp];
                } else {
                    videoFrame = [[UIImage alloc] initWithCGImage:image];
                }
                [UIView transitionWithView:tmp
                                  duration:0.2
                                   options:UIViewAnimationOptionTransitionCrossDissolve
                                animations:^{
                                    tmp.image = videoFrame;
                                } completion:nil];
                CFRelease(image);
            });
        }
    }];
}


#pragma mark - Properties

- (CGFloat)leftTimePosition {
    return ((_leftPosition-_leftThumb.frame.size.width) / (self.frame.size.width-(_leftThumb.frame.size.width*2))) * _durationSeconds;
}


- (CGFloat)rightTimePosition {
    return ((_rightPosition-_rightThumb.frame.size.width) / (self.frame.size.width-(_leftThumb.frame.size.width*2))) * _durationSeconds;
}

-(CGFloat)scrubberTimePosition {
    return ((_scrubberPosition-_leftThumb.frame.size.width) / (self.frame.size.width-(_leftThumb.frame.size.width*2))) * _durationSeconds;
}


-(CGFloat)positionForTime:(CGFloat)timePosition {
    return (timePosition/_durationSeconds)*(self.frame.size.width-(_leftThumb.frame.size.width*2)) + _leftThumb.frame.size.width;
}


#pragma mark - Bubble

- (void)hideBubble:(UIView *)popover
{
    [UIView animateWithDuration:0.4
                          delay:0
                        options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         popover.alpha = 0;
                     }
                     completion:nil];
    
    if ([_delegate respondsToSelector:@selector(videoRange:didGestureStateEndedLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didGestureStateEndedLeftPosition:self.leftPosition rightPosition:self.rightPosition];
        
    }
}

-(void)setScrubberTimeLabel:(CGFloat)seconds {
    self.scrubberBubbleText.text = [self secondsToTimeString:seconds];
}

-(void) setRangeTimeLabel {
    self.rangeBubbleText.text = [self trimIntervalString];
}


-(NSString *)trimDurationString{
    int delta = floor(self.rightPosition - self.leftPosition);
    return [NSString stringWithFormat:@"%d", delta];
}


-(NSString *)trimIntervalString{
    NSString *from = [self secondsToTimeString:[self leftTimePosition]];
    NSString *to = [self secondsToTimeString:[self rightTimePosition]];
    return [NSString stringWithFormat:@"%@ - %@", from, to];
}


#pragma mark - Helpers

- (NSString *)secondsToTimeString:(CGFloat)time
{
    int min = floor(time / 60);
    int sec = floor(time - min * 60);
    NSString *minStr = [NSString stringWithFormat:min >= 10 ? @"%i" : @"0%i", min];
    NSString *secStr = [NSString stringWithFormat:sec >= 10 ? @"%i" : @"0%i", sec];
    return [NSString stringWithFormat:@"%@:%@", minStr, secStr];
}


-(BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0));
}


@end
