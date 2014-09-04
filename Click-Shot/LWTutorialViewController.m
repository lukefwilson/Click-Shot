//
//  LWTutorialViewController.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/6/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "LWTutorialViewController.h"
#import "CameraViewController.h"
#import "UIImage+ImageFromColor.h"

#define kCloseButtonWidth 100
#define kCloseButtonHeight 34
#define kSettingsViewHeight 100
#define kNumberOfPages 7
#define kOffscreenRect CGRectMake(self.mainController.pictureModeButton.frame.origin.x, -15, self.mainController.videoModeButton.frame.origin.x+self.mainController.videoModeButton.frame.size.width-self.mainController.pictureModeButton.frame.origin.x, 1)
#define kSmallGroundOffset 135
#define kLargeGroundOffset 235
#define kPage2TextDown 70
#define kPage2TextUp 33
#define kWarningLabelTag 3


@implementation LWTutorialViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    self.dataSource = self;
    self.delegate = self;
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.500];
    
    _maskLayer = [CAShapeLayer layer];
    _maskLayer.frame = self.view.frame;
    _maskLayer.fillColor = [UIColor blackColor].CGColor;
    _maskLayer.fillRule = kCAFillRuleEvenOdd;
    self.view.layer.mask = _maskLayer;
    _border = [[UIView alloc] initWithFrame:CGRectZero];
    [_border.layer setBorderWidth:5.0];
    [_border.layer setBorderColor:[UIColor whiteColor].CGColor];
    [self.view addSubview:_border];
    
    [self setMaskRect:kOffscreenRect];

    
    LWTutorialChildViewController *initialViewController = [self viewControllerAtIndex:0];
    self.currentPage = 0;
    
    NSArray *viewControllers = [NSArray arrayWithObject:initialViewController];
    
    self.currentPageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height-kSmallGroundOffset, self.view.frame.size.width, 80)];
    self.currentPageLabel.alpha = 0;
    self.currentPageLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:17];
    self.currentPageLabel.textColor = [UIColor whiteColor];
    self.currentPageLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.currentPageLabel];
    
    [self setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
}

-(void)setMaskRect:(CGRect)maskRect {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:maskRect];
    [path appendPath:[UIBezierPath bezierPathWithRect:self.view.frame]];
    _maskLayer.path = path.CGPath;
    _border.frame = CGRectMake(maskRect.origin.x-10, maskRect.origin.y-10, maskRect.size.width+20, maskRect.size.height+20);
    _maskRect = maskRect;
}

-(void)animateMaskRect:(CGRect)maskRect withSpeed:(CGFloat)speed andCompletion:(void (^)(BOOL))completionBlock {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:maskRect];
    [path appendPath:[UIBezierPath bezierPathWithRect:self.view.frame]];
    
    CABasicAnimation *animate = [CABasicAnimation animationWithKeyPath:@"path"];
    animate = [CABasicAnimation animationWithKeyPath:@"path"];
    animate.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animate.fromValue = (id)_maskLayer.path;
    _maskLayer.path = path.CGPath;
    animate.toValue = (id)_maskLayer.path;
    animate.duration = 1;
    animate.speed = speed;
    
    [_maskLayer addAnimation:animate forKey:nil];
    
    [UIView animateWithDuration:1/speed animations:^{
        _border.frame = CGRectMake(maskRect.origin.x-10, maskRect.origin.y-10, maskRect.size.width+20, maskRect.size.height+20);

    } completion:completionBlock];
    
    _maskRect = maskRect;
}

- (LWTutorialChildViewController *)viewControllerAtIndex:(NSUInteger)index {
    
    LWTutorialChildViewController *childViewController = [self.storyboard instantiateViewControllerWithIdentifier:[NSString stringWithFormat:@"tutorialPage%li", (unsigned long)index]];
    childViewController.view.backgroundColor = [UIColor clearColor];
    childViewController.index = index;
    
    if (index == 0) {
    
        [childViewController.skipTutorialButton setBackgroundImage:[UIImage imageWithColor:[CameraViewController getHighlightColor]] forState:UIControlStateNormal];
    }
    
    return childViewController;
    
}


- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    NSUInteger index = [(LWTutorialChildViewController *)viewController index];
    
    if (index == 0) {
        return nil;
    }
    
    return [self viewControllerAtIndex:(index-1)];
    
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    NSUInteger index = [(LWTutorialChildViewController *)viewController index];
    
    if (index == (kNumberOfPages-1)) {
        return nil;
    }
    
    return [self viewControllerAtIndex:(index+1)];
    
}

-(BOOL)swallowTouchPoint:(CGPoint)point {
    BOOL touchedHole = CGRectContainsPoint(_maskRect, point);
    if (CGPointEqualToPoint(point, _previousTouchPoint) && touchedHole) {
        switch (_currentPage) {
            case 2:
                [self turnOnWarningLabel];
                return YES;
                break;
            case 3:
                break;
            case 4:
                [self turnOnWarningLabel];
                return YES;
                break;
            case 5:
                break;
            case 6:
                [self.mainController closeTutorial];
                break;
            default:
                break;
        }
        _previousTouchPoint = point;
        return NO;
    } else if (touchedHole) {
        _previousTouchPoint = point;
        return NO;
    }
    _previousTouchPoint = point;
    return YES;
}

-(void)turnOnWarningLabel {
    LWTutorialChildViewController *currentPage = [self.viewControllers lastObject];
    UILabel *label = (UILabel *)[currentPage.view viewWithTag:kWarningLabelTag];
    [UIView animateWithDuration:0.25 animations:^{
        label.alpha = 1;
    }];
}

-(void)turnOffWarningLabel {
    LWTutorialChildViewController *currentPage = [self.viewControllers lastObject];
    UILabel *label = (UILabel *)[currentPage.view viewWithTag:kWarningLabelTag];
    [UIView animateWithDuration:0.5 animations:^{
        label.alpha = 0;
    }];
}

-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed {
//    NSLog(@"did transition");
    
    if (!completed)  return;
    
    LWTutorialChildViewController *toViewController = (LWTutorialChildViewController *)[self.viewControllers lastObject];
    if (toViewController.index == _currentPage) return;
    switch (toViewController.index) {
        case 0: {
            [self animateMaskRect:kOffscreenRect withSpeed:2 andCompletion:nil];
            self.currentPageLabel.alpha = 0;
            break;
        }
        case 1: {
            [UIView animateWithDuration:0.5 animations:^{
                self.currentPageLabel.alpha = 1;
            }];
            if (self.currentPage == 2) { // coming back from next page
                [self.mainController closeSettingsMenu];
                [self moveCurrentPageLabelDown];
                LWTutorialChildViewController *page2 = [previousViewControllers lastObject];
                page2.page2TextDistanceFromTop.constant = kPage2TextDown;
                [page2.view layoutIfNeeded];
            }
            [self animateMaskRect:CGRectMake(self.mainController.pictureModeButton.frame.origin.x, 0, self.mainController.videoModeButton.frame.origin.x+self.mainController.pictureModeButton.frame.size.width-self.mainController.pictureModeButton.frame.origin.x, self.mainController.pictureModeButton.frame.size.height) withSpeed:1.5 andCompletion:nil];
            
            break;
        }
        case 2: { // camera mode wasn't pressed, swiped instead
            if (self.currentPage == 3) {
                [self animateMaskRect:self.mainController.soundsButton.frame withSpeed:1 andCompletion:nil];
            } else {
                [self animateMaskRect:self.mainController.settingsButton.frame withSpeed:1 andCompletion:^(BOOL finished) {
                    if (self.currentPage == 2) {
                        [self.mainController openSettingsMenu];
                        [self moveCurrentPageLabelUp];
                        [self animateMaskRect:self.mainController.soundsButton.frame withSpeed:1 andCompletion:nil];
                        [UIView animateWithDuration:0.5 animations:^{
                            toViewController.page2TextDistanceFromTop.constant = kPage2TextUp;
                            [toViewController.view layoutIfNeeded];
                        }];
                    }
                }];
            }
            break;
        }
        case 3: { // swiped after sounds
            [self.mainController openSettingsMenu];
            [self moveCurrentPageLabelUp];
            [self animateMaskRect:CGRectMake(self.mainController.focusButton.frame.origin.x, self.mainController.focusButton.frame.origin.y, self.mainController.exposureButton.frame.origin.x+self.mainController.exposureButton.frame.size.width-self.mainController.focusButton.frame.origin.x, self.mainController.focusButton.frame.size.height) withSpeed:1 andCompletion:nil];
            break;
        }
        case 4: {
            [self.mainController openSettingsMenu];
            [self moveCurrentPageLabelUp];
            [self animateMaskRect:self.mainController.bluetoothButton.frame withSpeed:1 andCompletion:nil];
            break;
        }
        case 5: { // swipe to Camera Roll
            [self animateMaskRect:self.mainController.cameraRollButton.frame withSpeed:1 andCompletion:nil];
            [self.mainController closeSettingsMenu];
            [self moveCurrentPageLabelDown];
            if (self.currentPageLabel.alpha != 1) {
                [UIView animateWithDuration:0.5 animations:^{
                    self.currentPageLabel.alpha = 1;
                }];
            }
            break;
        }
        case 6: { // swipe to Main camera button
            [self animateMaskRect:self.mainController.cameraButton.outerButtonImage.frame withSpeed:1 andCompletion:nil];
            [UIView animateWithDuration:0.5 animations:^{
                self.currentPageLabel.alpha = 0;
            }];
            break;
        }
        default:
            break;
    }
    self.currentPage = toViewController.index;
    self.currentPageLabel.text = [NSString stringWithFormat:@"%li of %i", (long)self.currentPage, kNumberOfPages-1];
    NSLog(@"%@", NSStringFromCGSize(toViewController.view.frame.size));
}

-(void)moveCurrentPageLabelUp {
    [UIView animateWithDuration:0.5 animations:^{
        self.currentPageLabel.frame = CGRectMake(0, self.view.frame.size.height-kLargeGroundOffset, self.view.frame.size.width, self.currentPageLabel.frame.size.height);
    }];
}

-(void)moveCurrentPageLabelDown {
    [UIView animateWithDuration:0.5 animations:^{
        self.currentPageLabel.frame = CGRectMake(0, self.view.frame.size.height-kSmallGroundOffset, self.view.frame.size.width, self.currentPageLabel.frame.size.height);
    }];
}

-(void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers {
//    NSLog(@"will transition");
    LWTutorialChildViewController *toViewController = (LWTutorialChildViewController *)[pendingViewControllers firstObject];
    if (toViewController.index == 0 || toViewController.index == 6) {
        self.currentPageLabel.alpha = 0;
    }
    [self turnOffWarningLabel];
}


-(void)restartTutorial {
    LWTutorialChildViewController *initialViewController = [self viewControllerAtIndex:0];
    self.currentPage = 0;
    [self setMaskRect:kOffscreenRect];

    [self setViewControllers:@[initialViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

@interface LWTutorialChildViewController ()

@end

@implementation LWTutorialChildViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self initialize];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}

-(id)init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

-(void)initialize {
    // custom init

}


- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}
- (IBAction)pressedStillButton:(id)sender {
    LWTutorialViewController *mainTutorialViewController = (LWTutorialViewController *)self.parentViewController;
    [mainTutorialViewController.mainController pressedPictureMode:nil];
}
- (IBAction)pressedActionButton:(id)sender {
    LWTutorialViewController *mainTutorialViewController = (LWTutorialViewController *)self.parentViewController;
    [mainTutorialViewController.mainController pressedRapidShotMode:nil];
}
- (IBAction)pressedVideoButton:(id)sender {
    LWTutorialViewController *mainTutorialViewController = (LWTutorialViewController *)self.parentViewController;
    [mainTutorialViewController.mainController pressedVideoMode:nil];
}

- (IBAction)closeTutorial:(id)sender {
    LWTutorialViewController *mainTutorialViewController = (LWTutorialViewController *)self.parentViewController;
    [mainTutorialViewController.mainController closeTutorial];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

@implementation LWTutorialContainerView

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.delegate swallowTouchPoint:point];
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
