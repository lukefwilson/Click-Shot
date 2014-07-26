//
//  LWTutorialViewController.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/6/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "LWTutorialViewController.h"
#import "CameraViewController.h"

#define kCloseButtonWidth 100
#define kCloseButtonHeight 34
#define kSettingsViewHeight 100
#define kNumberOfPages 11
#define kOffscreenRect CGRectMake(-15, -15, 5, 5)

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
    
    [self setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
}

-(void)setMaskRect:(CGRect)maskRect {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:maskRect];
    [path appendPath:[UIBezierPath bezierPathWithRect:self.view.frame]];
    _maskLayer.path = path.CGPath;
    _border.frame = CGRectMake(maskRect.origin.x-10, maskRect.origin.y-10, maskRect.size.width+20, maskRect.size.height+20);
    _maskRect = maskRect;
}

-(void)animateMaskRect:(CGRect)maskRect withSpeed:(CGFloat)speed {
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
    }];
    
    _maskRect = maskRect;
}

- (LWTutorialChildViewController *)viewControllerAtIndex:(NSUInteger)index {
    
    LWTutorialChildViewController *childViewController = [self.storyboard instantiateViewControllerWithIdentifier:[NSString stringWithFormat:@"tutorialPage%li", (unsigned long)index]];
    childViewController.view.backgroundColor = [UIColor clearColor];
    childViewController.index = index;
    
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
            case 1: // pressed flash menu open
                [self setViewControllers:@[[self viewControllerAtIndex:2]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
                self.currentPage = 2;
                [self animateMaskRect:CGRectMake(0, 0, self.mainController.flashModeAutoButton.frame.size.width, self.mainController.flashModeAutoButton.frame.size.height*3) withSpeed:2];
                break;
            case 2: // chose flash mode from menu
                [self setViewControllers:@[[self viewControllerAtIndex:3]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
                self.currentPage = 3;
                [self animateMaskRect:CGRectMake(self.mainController.pictureModeButton.frame.origin.x, 0, self.mainController.videoModeButton.frame.origin.x+self.mainController.pictureModeButton.frame.size.width-self.mainController.pictureModeButton.frame.origin.x, self.mainController.pictureModeButton.frame.size.height) withSpeed:1.5];
                break;
            case 3: // chose camera mode from menu
                [self setViewControllers:@[[self viewControllerAtIndex:4]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
                self.currentPage = 4;
                [self animateMaskRect:self.mainController.swithCameraButton.frame withSpeed:1];
                break;
            case 4: // switched camera
                [self setViewControllers:@[[self viewControllerAtIndex:5]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
                self.currentPage = 5;
                [self animateMaskRect:self.mainController.settingsButton.frame withSpeed:1];
                break;
            case 5: // settings menu opened
                [self setViewControllers:@[[self viewControllerAtIndex:6]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
                self.currentPage = 6;
//                [self animateMaskRect:CGRectMake(0, self.view.frame.size.height-kSettingsViewHeight, self.view.frame.size.width, kSettingsViewHeight) withSpeed:1];
                [self animateMaskRect:self.mainController.soundsButton.frame withSpeed:1];

                break;
            case 6: // can't progress from settings menu, but can play with it
                break;
            case 7: // can't progress from settings menu, but can play with it
                break;
            case 8: // can't progress from settings menu, but can play with it
                break;
            case 9: // don't let them mess with camera roll
                return YES;
                break;
            case 10:
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

-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed {
//    NSLog(@"did transition");
    
    if (!completed)  return;
    
    LWTutorialChildViewController *currentViewController = (LWTutorialChildViewController *)[self.viewControllers lastObject];
    if (currentViewController.index == _currentPage) return;
    switch (currentViewController.index) {
        case 0: {
            [self animateMaskRect:kOffscreenRect withSpeed:2];
            break;
        }
        case 1: {
            [self animateMaskRect:self.mainController.flashModeAutoButton.frame withSpeed:2];
            if (self.currentPage == 2) { // going back from open flash menu
                [self.mainController closeFlashModeMenu:self.mainController.flashModeAutoButton];
            }
            break;
        }
        case 2: { // flash menu wasn't chosen, swiped instead
            [self.mainController openFlashModeMenu];
            [self animateMaskRect:CGRectMake(0, 0, self.mainController.flashModeAutoButton.frame.size.width, self.mainController.flashModeAutoButton.frame.size.height*3) withSpeed:2];
            break;
        }
        case 3: { // flash mode wasn't chosen from menu, swiped instead
            [self.mainController closeFlashModeMenu:self.mainController.flashModeAutoButton];
            [self animateMaskRect:CGRectMake(self.mainController.pictureModeButton.frame.origin.x, 0, self.mainController.videoModeButton.frame.origin.x+self.mainController.pictureModeButton.frame.size.width-self.mainController.pictureModeButton.frame.origin.x, self.mainController.pictureModeButton.frame.size.height) withSpeed:1.5];
            break;
        }
        case 4: { // camera mode wasn't chosen from menu, swiped instead
            [self animateMaskRect:self.mainController.swithCameraButton.frame withSpeed:1];
            break;
        }
        case 5: { // switch camera  wasn't pressed, swiped instead
            [self animateMaskRect:self.mainController.settingsButton.frame withSpeed:1];
            if (self.currentPage == 6) { // coming back from next page
                [self.mainController closeSettingsMenu];
            }
            break;
        }
        case 6: { // settings menu wasn't pressed, swiped instead
//            [self animateMaskRect:CGRectMake(0, self.view.frame.size.height-kSettingsViewHeight, self.view.frame.size.width, kSettingsViewHeight) withSpeed:1];
            [self animateMaskRect:self.mainController.soundsButton.frame withSpeed:1];
            [self.mainController openSettingsMenu];
            break;
        }
        case 7: { // swiped after sounds
            [self animateMaskRect:CGRectMake(self.mainController.focusButton.frame.origin.x, self.mainController.focusButton.frame.origin.y, self.mainController.exposureButton.frame.origin.x+self.mainController.exposureButton.frame.size.width-self.mainController.focusButton.frame.origin.x, self.mainController.focusButton.frame.size.height) withSpeed:1];
            break;
        }
        case 8: {
            [self animateMaskRect:self.mainController.bluetoothButton.frame withSpeed:1];

            if (self.currentPage == 9) { // coming back from next page
                [self.mainController openSettingsMenu];
            }
            break;
        }
        case 9: { // swipe to Camera Roll
            [self animateMaskRect:self.mainController.cameraRollButton.frame withSpeed:1];
            [self.mainController closeSettingsMenu];
            break;
        }
        case 10: { // swipe to Main circle
            [self animateMaskRect:self.mainController.cameraButton.outerButtonImage.frame withSpeed:1];
            break;
        }
        default:
            break;
    }
    self.currentPage = currentViewController.index;
//    NSLog(@"current page %li", (long)self.currentPage);
}

-(void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers {
//    NSLog(@"will transition");
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
