//
//  CameraViewController.m
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import "CameraPreviewView.h"
#import "MoveableImageView.h"
#import "GPUImage.h"
#import "MHGallery.h"
#import "LWTutorialViewController.h"
#import "DragAnimationView.h"



//#define CSStateCameraModeStill 0
//#define CSStateCameraModeActionShot 1
//#define CSStateCameraModeVideo 2

//#define CSStateFlashModeAuto 0
//#define CSStateFlashModeOn 1
//#define CSStateFlashModeOff 2

#define kDefaultAlpha 1

#define kFocusViewTag 1
#define kExposeViewTag 2

/* not needed anymore
#define BTTN_SERVICE_UUID           @"fffffff0-00f7-4000-b000-000000000000"
#define BTTN_DETECTION_CHARACTERISTIC_UUID    @"fffffff2-00f7-4000-b000-000000000000"
#define BTTN_NOTIFICATION_CHARACTERISTIC_UUID    @"fffffff4-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_CHARACTERISTIC_UUID    @"fffffff5-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_KEY    @"BC:F5:AC:48:40" // old key
*/
#define kSwipeVelocityUntilGuarenteedSwitch 800
#define kLargeFontSize 70
#define kMediumFontSize 60
#define kSmallFontSize 47

#define kSettingsViewHeight 100
#define kiPhonePhotoPreviewHeight 426.666

#define kVideoDimension (9.0/16)
#define kPhotoDimension (3.0/4)





// Interface here for private properties
@interface CameraViewController () <VideoProcessorDelegate, UIPickerViewDataSource, UIPickerViewDelegate, AVAudioPlayerDelegate, DragAnimationViewDelegate>

@property (nonatomic, weak) IBOutlet CameraPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIView *cameraUIView;

@property (nonatomic) UIImageView *cameraRollImage; //child of cameraRollButton (stacks on top just taken picture)
@property (nonatomic, weak) IBOutlet MoveableImageView *focusPointView;
@property (nonatomic, weak) IBOutlet MoveableImageView *exposePointView;
@property (nonatomic, weak) IBOutlet UIImageView *blurredImagePlaceholder;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraUIDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraUIDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraPreviewViewDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraPreviewViewDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blackBackgroundDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blackBackgroundDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blurredImageDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blurredImageDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashOnDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashOffDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashAutoDistanceToTop;
@property (weak, nonatomic) IBOutlet UILabel *flashOnLabel;
@property (weak, nonatomic) IBOutlet UILabel *flashOffLabel;
@property (weak, nonatomic) IBOutlet UILabel *flashAutoLabel;

@property (nonatomic) CGFloat distanceToCenterPhotoPreview;
@property (weak, nonatomic) IBOutlet UIView *blackBackground;

@property (nonatomic, weak)  UIView *pictureSwipeView;
@property (nonatomic, weak)  UIView *rapidShotSwipeView;
@property (nonatomic, weak)  UIView *videoSwipeView;

@property (nonatomic)  DragAnimationView *settingsButtonDragView;
@property (nonatomic)  DragAnimationView *previewOverlayDragView;
@property (nonatomic)  NSArray *menuAnimationSteps;
@property (nonatomic)  NSArray *iPhone5MenuAnimationSteps;

@property (nonatomic, strong) UIButton *currentFlashButton;
@property (nonatomic, strong) UIView *modeSelectorBar;



- (IBAction)pressedCameraRoll:(id)sender;
- (IBAction)pressedSettings:(id)sender;
- (IBAction)pressedFlashButton:(id)sender;
- (IBAction)switchCamera:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Settings Menu
@property (nonatomic, weak) IBOutlet UIView *settingsView;

@property (nonatomic, weak) IBOutlet UIButton *tutorialButton;
@property (nonatomic, weak) IBOutlet UIView *bluetoothMenu;
@property (nonatomic, weak) LWBluetoothTableViewController *bluetoothViewController;
@property (nonatomic, weak) IBOutlet LWTutorialContainerView *tutorialView;
@property (nonatomic, weak) LWTutorialViewController *tutorialViewController;

@property (nonatomic, weak) IBOutlet UIPickerView *soundPicker;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *soundPickerDistsanceFromLeft;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *soundPickerDistsanceFromRight;
- (IBAction)toggleFocusButton:(id)sender;
- (IBAction)toggleExposureButton:(id)sender;
- (IBAction)pressedSounds:(id)sender;

// Utilities.
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic) CSStateFlashMode flashMode;
@property (nonatomic) BOOL flashModeMenuIsOpen;
@property (nonatomic) AVAudioPlayer *soundPlayer;
@property (nonatomic) BOOL shouldPlaySound;

// Swipe Mode Control
@property (nonatomic) UITouch *primaryTouch;

@property (nonatomic) CGFloat startXTouch;
@property (nonatomic) CGFloat previousXTouch;
@property (nonatomic) CFTimeInterval lastMoveTime;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) CGFloat velocity;
@property (nonatomic) CGFloat selectorBarStartCenterX;

@property (nonatomic) NSDate *recordingStart;
@property (nonatomic) NSTimer *recordingTimer;

@property (nonatomic) GPUImageiOSBlurFilter *blurFilter;
@property (nonatomic) NSMutableArray *galleryItems;

@property (nonatomic) BOOL micPermission;
@property (nonatomic) BOOL assetsPermission;


@end

#pragma mark - Implementation

@implementation CameraViewController

static NSInteger const settingsClosedAnimStep = 0;
static NSInteger const settingsOpenAnimStep = 1;
static NSInteger const soundsOpenAnimStep = 2;
static NSInteger const bluetoothOpenAnimStep = 3;

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
    __weak CameraViewController *weakSelf = self;

    _shouldSendChangesToRemote = YES;
    _exposureDevicePoint = CGPointMake(0.5, 0.5);
    _focusDevicePoint = _exposureDevicePoint;
    _cameraOrientation = CSStateCameraOrientationPortrait;
    
    self.cameraMode = CSStateCameraModeStill;
    [self updateModeButtonsForMode:self.cameraMode];
    self.flashMode = CSStateFlashModeAuto;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger soundNumber = [[defaults objectForKey:@"sound"] integerValue];
    [self updateSoundPlayerWithSoundNumber:soundNumber];
    [self.soundPicker selectRow:soundNumber inComponent:0 animated:NO];
    
    BOOL notFirstTime = [[defaults objectForKey:@"isNotFirstTime"] boolValue];
    if (!notFirstTime) {
        [self openTutorial];
        [defaults setObject:@YES forKey:@"isNotFirstTime"];
        [defaults synchronize];
    }

    self.currentFlashButton = self.flashModeAutoButton;
    self.autoExposureMode = ![[defaults objectForKey:@"noAutoExposureMode"] boolValue];
    [self updateMoveableExposureView];
    self.exposePointView.center = self.view.center;
    self.autoFocusMode = [[defaults objectForKey:@"autoFocusMode"] boolValue];
    [self updateMoveableFocusView];
    self.focusPointView.center = self.view.center;
    self.swipeModesGestureIsBlocked = NO;
    
    self.focusPointView.parentViewController = weakSelf;
    self.exposePointView.parentViewController = weakSelf;
    self.cameraButton.cameraController = weakSelf;
    [self.cameraButton initialize];
	   
	// Check for device authorization
	[self checkMicPermission];
    [self checkAssetsPremission];


    self.currentFlashButton.alpha = kDefaultAlpha;
    self.focusButton.alpha = kDefaultAlpha;
    self.exposureButton.alpha = kDefaultAlpha;
    self.swithCameraButton.alpha = kDefaultAlpha;
    
    self.modeSelectorBar = [[UIView alloc] initWithFrame:CGRectMake(self.pictureModeButton.frame.origin.x, self.pictureModeButton.frame.origin.y+self.pictureModeButton.frame.size.height+3, self.pictureModeButton.frame.size.width, 7)];
    self.modeSelectorBar.backgroundColor = [UIColor whiteColor];
    [self.cameraUIView addSubview:self.modeSelectorBar];
//    self.pictureCameraButtonImage = [UIImage imageNamed:@"inner.png"];
//    self.rapidCameraButtonImage = [UIImage imageNamed:@"rapidInner.png"];
//    self.videoCameraButtonImage = [UIImage imageNamed:@"redInner.png"];
//    self.pictureCameraButtonImageHighlighted = [UIImage imageNamed:@"innerHighlighted.png"];
//    self.rapidCameraButtonImageHighlighted = [UIImage imageNamed:@"rapidInnerHighlighted.png"];
//    self.videoCameraButtonImageHighlighted = [UIImage imageNamed:@"redInnerHighlighted.png"];
//    self.darkCameraButtonBG = [UIImage imageNamed:@"cameraButtonDarkBG"];

    self.videoProcessor = [[VideoProcessor alloc] init];
    self.videoProcessor.delegate = self;
    self.videoProcessor.previewView = self.previewView;
    [self.videoProcessor setupAndStartCaptureSession];
    [self.videoProcessor setFlashMode:[self currentAVFlashMode]];

    self.cameraRollImage = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, self.cameraRollButton.frame.size.width-6, self.cameraRollButton.frame.size.height-6)];
    self.cameraRollImage.contentMode = UIViewContentModeScaleAspectFill;
    self.cameraRollImage.clipsToBounds = YES;
    [self.cameraRollButton addSubview:self.cameraRollImage];
    
    self.blurFilter = [[GPUImageiOSBlurFilter alloc] init];
    self.blurFilter.blurRadiusInPixels = 10.0f;
    self.blurFilter.saturation = 0.6;
    
    self.distanceToCenterPhotoPreview = 0; // only iPhone 5 has non 0 here
    if (IPHONE_5) {
        self.distanceToCenterPhotoPreview = (self.view.center.y - ((self.view.frame.size.height-self.flashModeOnButton.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height)/2+self.flashModeOnButton.frame.size.height))/2;
    }
    [self updateCameraPreviewPosition];
    [self updateTappablePreviewRectForCameraMode:self.cameraMode];


    self.pictureSwipeView = [self swipeViewForMode:CSStateCameraModeStill];
    self.rapidShotSwipeView = [self swipeViewForMode:CSStateCameraModeActionShot];
    self.videoSwipeView = [self swipeViewForMode:CSStateCameraModeVideo];
    
    if(!IPHONE_4) {
        [self createMenuAnimationArrays];
        _settingsButtonDragView = [[DragAnimationView alloc] initWithFrame:self.settingsButton.frame animations:_menuAnimationSteps];
        _settingsButtonDragView.delegate = self;
        _previewOverlayDragView = [[DragAnimationView alloc] initWithFrame:self.cameraUIView.frame animations:_menuAnimationSteps];
        _previewOverlayDragView.delegate = self;
        _previewOverlayDragView.hidden = YES;
        [self updateDragViewAnimations]; // adjust if iPhone 5
        [self.cameraUIView addSubview:_previewOverlayDragView];
        [self.cameraUIView addSubview:_settingsButtonDragView];
    }
}

-(void)createMenuAnimationArrays {
    CABasicAnimation *moveUpForSettings=[CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForSettings.duration = 1;
    moveUpForSettings.autoreverses = NO;
    moveUpForSettings.fromValue = [NSValue valueWithCGPoint:self.cameraUIView.layer.position];
    moveUpForSettings.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-kSettingsViewHeight)];
    moveUpForSettings.speed = 0;
    moveUpForSettings.timeOffset = 0;
    
    CABasicAnimation *moveUpForSounds = [CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForSounds.duration = 1;
    moveUpForSounds.autoreverses = NO;
    moveUpForSounds.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-kSettingsViewHeight)];
    moveUpForSounds.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height))];
    moveUpForSounds.speed = 0;
    moveUpForSounds.timeOffset = 0;
    
    CABasicAnimation *moveUpForBluetooth=[CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForBluetooth.duration = 1;
    moveUpForBluetooth.autoreverses = NO;
    moveUpForBluetooth.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height))];
    moveUpForBluetooth.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.bluetoothMenu.frame.size.height))];
    moveUpForBluetooth.speed = 0;
    moveUpForBluetooth.timeOffset = 0;
    
    CABasicAnimation *openSoundsMenuAnim =[CABasicAnimation animationWithKeyPath:@"position"];
    openSoundsMenuAnim.duration = 1;
    openSoundsMenuAnim.autoreverses = NO;
    openSoundsMenuAnim.toValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    openSoundsMenuAnim.fromValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    openSoundsMenuAnim.speed = 0;
    openSoundsMenuAnim.timeOffset = 0;
    
    CABasicAnimation *closeSoundsMenuAnim =[CABasicAnimation animationWithKeyPath:@"position"];
    closeSoundsMenuAnim.duration = 1;
    closeSoundsMenuAnim.autoreverses = NO;
    closeSoundsMenuAnim.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x+CGRectGetWidth(self.view.frame), self.soundPicker.layer.position.y)];
    closeSoundsMenuAnim.fromValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    closeSoundsMenuAnim.speed = 0;
    closeSoundsMenuAnim.timeOffset = 0;
    
    _menuAnimationSteps = @[ @[@[self.cameraUIView, moveUpForSettings], @[self.previewView, moveUpForSettings], @[self.blackBackground, moveUpForSettings]], @[@[self.cameraUIView, moveUpForSounds], @[self.previewView, moveUpForSounds], @[self.blackBackground, moveUpForSounds], @[self.soundPicker, openSoundsMenuAnim]],  @[@[self.cameraUIView, moveUpForBluetooth], @[self.previewView, moveUpForBluetooth], @[self.blackBackground, moveUpForBluetooth], @[self.soundPicker, closeSoundsMenuAnim]] ];
    
//    if (IPHONE_5) {
//    NSLog(@"reg %@ non %@", NSStringFromCGPoint(self.cameraUIView.layer.position), NSStringFromCGPoint(self.previewView.layer.position));
        CABasicAnimation *previewMoveUpForSettings=[CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForSettings.duration = 1;
        previewMoveUpForSettings.autoreverses = NO;
        previewMoveUpForSettings.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSettings.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-kSettingsViewHeight-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSettings.speed = 0;
        previewMoveUpForSettings.timeOffset = 0;
        
        CABasicAnimation *previewMoveUpForSounds = [CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForSounds.duration = 1;
        previewMoveUpForSounds.autoreverses = NO;
        previewMoveUpForSounds.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-kSettingsViewHeight-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSounds.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSounds.speed = 0;
        previewMoveUpForSounds.timeOffset = 0;
        
        CABasicAnimation *previewMoveUpForBluetooth=[CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForBluetooth.duration = 1;
        previewMoveUpForBluetooth.autoreverses = NO;
        previewMoveUpForBluetooth.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForBluetooth.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.bluetoothMenu.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForBluetooth.speed = 0;
        previewMoveUpForBluetooth.timeOffset = 0;
        
        _iPhone5MenuAnimationSteps = @[ @[@[self.cameraUIView, moveUpForSettings], @[self.previewView, previewMoveUpForSettings], @[self.blackBackground, moveUpForSettings]], @[@[self.cameraUIView, moveUpForSounds], @[self.previewView, previewMoveUpForSounds], @[self.blackBackground, moveUpForSounds], @[self.soundPicker, openSoundsMenuAnim]],  @[@[self.cameraUIView, moveUpForBluetooth], @[self.previewView, previewMoveUpForBluetooth], @[self.blackBackground, moveUpForBluetooth], @[self.soundPicker, closeSoundsMenuAnim]] ];
//    }
}

// used to fix preview view on iPhone 5
-(void)updateDragViewAnimations {
    if (IPHONE_5 && self.cameraMode != CSStateCameraModeVideo) {
        _settingsButtonDragView.animationSteps = _iPhone5MenuAnimationSteps;
        _previewOverlayDragView.animationSteps = _iPhone5MenuAnimationSteps;
    } else {
        _settingsButtonDragView.animationSteps = _menuAnimationSteps;
        _previewOverlayDragView.animationSteps = _menuAnimationSteps;
    }
}

-(void)updateTappablePreviewRectForCameraMode:(NSInteger)cameraMode {
    if (IPAD) {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
        } else {
            self.tappablePreviewRect = CGRectMake(0, self.swithCameraButton.frame.size.height, self.view.frame.size.width, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
        }
    } else if (IPHONE_5) {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
        } else {
            self.distanceToCenterPhotoPreview = (self.view.center.y - ((self.view.frame.size.height-self.flashModeOnButton.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height)/2+self.flashModeOnButton.frame.size.height))/2;
            CGFloat previewHeight = self.view.frame.size.height * kPhotoDimension;
            
            self.tappablePreviewRect = CGRectMake(0, (self.view.frame.size.height-previewHeight)/2-self.distanceToCenterPhotoPreview, self.view.frame.size.width, previewHeight);
        }
    } else {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
        } else {
            self.tappablePreviewRect = CGRectMake(0, self.swithCameraButton.frame.size.height, self.view.frame.size.width, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
        }
    }
    [self.focusPointView fixIfOffscreen];
    [self.exposePointView fixIfOffscreen];
//    NSLog(@"%@", NSStringFromCGRect(self.tappablePreviewRect));
}

// used to fix iphone centering picture preview frame
// brings the cameraPreviewView to zero'd out position with its blurred image view
-(void)updateCameraPreviewPosition {
    if (self.cameraMode == CSStateCameraModeVideo) {
        self.cameraPreviewViewDistanceToTop.constant = 0;
        self.cameraPreviewViewDistanceToBottom.constant = 0;
        self.blurredImageDistanceToTop.constant = 0;
        self.blurredImageDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToTop.constant = 0;
    } else {
        self.cameraPreviewViewDistanceToTop.constant = -self.distanceToCenterPhotoPreview;
        self.cameraPreviewViewDistanceToBottom.constant = self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToTop.constant = -self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToBottom.constant = self.distanceToCenterPhotoPreview;
        self.blackBackgroundDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToTop.constant = 0;
    }
    [self.view layoutIfNeeded];
}

-(void)resumeSessions {
    [self.videoProcessor resumeCaptureSession];
    [self.bluetoothViewController refreshBluetoothDevices];
}

-(void)pauseSessions {
    [self.videoProcessor pauseCaptureSession];
    [self.bluetoothViewController cleanupBluetooth];
}

- (void)viewWillAppear:(BOOL)animated {
    self.cameraRollIsOpen = NO;
    [self updateGalleryItems];
}

-(void)moveMainViewVerticallyTo:(CGFloat)yPosition {
    self.cameraUIDistanceToBottom.constant = yPosition;
    self.cameraUIDistanceToTop.constant = -yPosition;
    self.blackBackgroundDistanceToBottom.constant = yPosition;
    self.blackBackgroundDistanceToTop.constant = -yPosition;

    if (self.cameraMode != CSStateCameraModeVideo) {
        self.cameraPreviewViewDistanceToBottom.constant = yPosition+self.distanceToCenterPhotoPreview;
        self.cameraPreviewViewDistanceToTop.constant = -yPosition-self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToBottom.constant = yPosition+self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToTop.constant = -yPosition-self.distanceToCenterPhotoPreview;
    } else {
        self.cameraPreviewViewDistanceToBottom.constant = yPosition;
        self.cameraPreviewViewDistanceToTop.constant = -yPosition;
        self.blurredImageDistanceToBottom.constant = yPosition;
        self.blurredImageDistanceToTop.constant = -yPosition;
    }
    [self.view layoutIfNeeded];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)pressedPictureMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeStill];
    self.pictureSwipeView.frame = CGRectMake(-self.pictureSwipeView.frame.size.width, 0, self.pictureSwipeView.frame.size.width, self.pictureSwipeView.frame.size.height);
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedRapidShotMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeActionShot];
    if (self.cameraMode == CSStateCameraModeStill) {
        self.rapidShotSwipeView.frame = CGRectMake(self.view.frame.size.width, 0, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
    } else {
        self.rapidShotSwipeView.frame = CGRectMake(-self.rapidShotSwipeView.frame.size.width, 0, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
    }
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedVideoMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeVideo];
    self.videoSwipeView.frame = CGRectMake(self.videoSwipeView.frame.size.width, 0, self.videoSwipeView.frame.size.width, self.videoSwipeView.frame.size.height);
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedCameraRoll:(id)sender {
    MHGalleryController *gallery = [[MHGalleryController alloc]initWithPresentationStyle:MHGalleryViewModeOverView];
    __weak MHGalleryController *blockGallery = gallery;
    gallery.galleryItems = self.galleryItems;
    MHUICustomization *customize = [[MHUICustomization alloc] init];
    customize.barStyle = UIBarStyleBlackTranslucent;
    customize.barTintColor = [UIColor blackColor];
    
    customize.barButtonsTintColor = [UIColor colorWithRed:0.242 green:0.804 blue:0.974 alpha:1.000];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeOverView];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarHidden];

    gallery.UICustomization = customize;
    gallery.finishedCallback = ^(NSUInteger currentIndex,UIImage *image,MHTransitionDismissMHGallery *interactiveTransition,MHGalleryViewMode viewMode){
        [blockGallery dismissViewControllerAnimated:YES dismissImageView:nil completion:nil];
    };
    self.cameraRollIsOpen = YES;
    [self presentMHGalleryController:gallery animated:YES completion:nil];
}


- (IBAction)switchCamera:(id)sender {
    [self.videoProcessor beginSwitchingCamera];
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint touchPoint = [gestureRecognizer locationInView:[gestureRecognizer view]];
    if (/*!self.swipeModesGestureIsBlocked && */!self.settingsMenuIsOpen && !CGRectContainsPoint(self.settingsButton.frame, touchPoint) && ![[self.cameraButton.buttonImage.layer presentationLayer] hitTest:touchPoint]) {
        self.exposePointView.center = touchPoint;
        self.focusPointView.center = touchPoint;
        self.focusPointView.alpha = 0;
        self.exposePointView.alpha = 0;
        [self.focusPointView fixIfOffscreen];
        [self.exposePointView fixIfOffscreen];
        CGPoint devicePoint =[self devicePointForScreenPoint:touchPoint];
        [self.videoProcessor focusWithMode:[self currentAVFocusMode] exposeWithMode:[self currentAVExposureMode] atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
        _focusDevicePoint = devicePoint;
        _exposureDevicePoint = devicePoint;
        [self.bluetoothViewController updateRemoteWithCurrentCameraState];
        if (!self.autoFocusMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.focusPointView.alpha = 0;
                }];
            }];
        }
        if (!self.autoExposureMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.exposePointView.alpha = 0;
                }];
            }];
        }
    }
}

-(void)setExposureDevicePointWithTouchLocation:(CGPoint)touchLocation{
    CGPoint devicePoint = [self devicePointForScreenPoint:touchLocation];
    _exposureDevicePoint = devicePoint;
    [self.videoProcessor exposeAtPoint:_exposureDevicePoint];
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
}

-(void)setFocusDevicePointWithTouchLocation:(CGPoint)touchLocation{
    CGPoint devicePoint = [self devicePointForScreenPoint:touchLocation];
    _focusDevicePoint = devicePoint;
    [self.videoProcessor focusAtPoint:_focusDevicePoint];
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];

}


-(CGPoint)devicePointForScreenPoint:(CGPoint)screenPoint {
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:screenPoint];
    return CGPointMake([self clamp:devicePoint.x between:0 and:1], [self clamp:devicePoint.y between:0 and:1]); // keep inside 0 and 1 bounds
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

- (IBAction)pressedSettings:(id)sender {
    if (self.settingsMenuIsOpen) {
        [self closeSettingsMenu];
    } else {
        [self openSettingsMenu];
    }
}

#pragma mark -
#pragma mark Settings Menu

-(void)closeSettingsMenu {
    self.settingsMenuIsOpen = NO;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = settingsClosedAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsClosedAnimStep;
    _previewOverlayDragView.hidden = YES;

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.cameraUIDistanceToBottom.constant = 0;
        self.cameraUIDistanceToTop.constant = 0;
        [self updateCameraPreviewPosition];
    } completion:^(BOOL finished){
        [self ensureClosedSettingsMenu];
    }];
}

-(void)openSettingsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = settingsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsOpenAnimStep;
    _previewOverlayDragView.hidden = NO;

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.cameraMode != CSStateCameraModeVideo) {
            self.cameraPreviewViewDistanceToBottom.constant = kSettingsViewHeight+self.distanceToCenterPhotoPreview;
            self.cameraPreviewViewDistanceToTop.constant = -kSettingsViewHeight-self.distanceToCenterPhotoPreview;
        } else {
            self.cameraPreviewViewDistanceToBottom.constant = kSettingsViewHeight;
            self.cameraPreviewViewDistanceToTop.constant = -kSettingsViewHeight;
        }
        self.blackBackgroundDistanceToBottom.constant = kSettingsViewHeight;
        self.blackBackgroundDistanceToTop.constant = -kSettingsViewHeight;
        // not needed but the blurred image view could also move here
        self.cameraUIDistanceToBottom.constant = kSettingsViewHeight;
        self.cameraUIDistanceToTop.constant = -kSettingsViewHeight;
        [self.view layoutIfNeeded];
    }completion:^(BOOL finished){
        [self ensureOpenSettingsMenu];
    }];
}

-(void)ensureOpenSettingsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    
    self.settingsButtonDragView.currentAnimationStep = settingsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsOpenAnimStep;
    
    [self moveMainViewVerticallyTo:kSettingsViewHeight];

}

-(void)ensureClosedSettingsMenu {
    self.settingsMenuIsOpen = NO;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    
    self.settingsButtonDragView.currentAnimationStep = settingsClosedAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsClosedAnimStep;

    [self moveMainViewVerticallyTo:0];
}

#pragma mark Settings Menu IBActions

- (IBAction)toggleFocusButton:(id)sender {
    self.autoFocusMode = !self.autoFocusMode;
    [self updateMoveableFocusView];
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
}

- (IBAction)toggleExposureButton:(id)sender {
    self.autoExposureMode = !self.autoExposureMode;
    [self updateMoveableExposureView];
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
}

-(IBAction)pressedSounds:(id)sender {
    if (self.soundsMenuIsOpen) {
        [self closeSoundsMenuToSettings];
    } else {
        [self openSoundsMenu];
    }
    self.bluetoothMenuIsOpen = NO;
}

-(void)openSoundsMenu {
    float yPosition = kSettingsViewHeight+self.soundPicker.frame.size.height;
    [self.settingsView bringSubviewToFront:self.soundPicker];
    if (self.bluetoothMenuIsOpen) {
        self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
        self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            self.soundPickerDistsanceFromLeft.constant = 0;
            self.soundPickerDistsanceFromRight.constant = 0;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenSoundsMenu];
        }];
    } else {
        self.soundPickerDistsanceFromLeft.constant = 0;
        self.soundPickerDistsanceFromRight.constant = 0;
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenSoundsMenu];
        }];
    }
    self.soundsMenuIsOpen = YES;
}

-(void)closeSoundsMenuToSettings {
    [self.settingsView bringSubviewToFront:self.soundPicker];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self moveMainViewVerticallyTo:kSettingsViewHeight];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self ensureOpenSettingsMenu];
    }];
    self.soundsMenuIsOpen = NO;
}

-(void)ensureOpenSoundsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = YES;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = soundsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = soundsOpenAnimStep;

    self.soundPickerDistsanceFromLeft.constant = 0;
    self.soundPickerDistsanceFromRight.constant = 0;
    
    float yPosition = kSettingsViewHeight+self.soundPicker.frame.size.height;
    [self moveMainViewVerticallyTo:yPosition];
    [self.view layoutIfNeeded];
}

- (IBAction)pressedBluetooth:(id)sender {
    if (self.bluetoothMenuIsOpen) {
        [self closeBluetoothMenuToSettings];
    } else {
        [self openBluetoothMenu];
    }
    self.soundsMenuIsOpen = NO;
}



-(void)openBluetoothMenu {
    float yPosition = kSettingsViewHeight+self.bluetoothMenu.frame.size.height;
    if (self.soundsMenuIsOpen) {
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
            self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self.settingsView bringSubviewToFront:self.bluetoothMenu];
            [self ensureOpenBluetoothMenu];
        }];
    } else {
        [self.settingsView bringSubviewToFront:self.bluetoothMenu];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenBluetoothMenu];
        }];
    }
    self.bluetoothMenuIsOpen = YES;
}

-(void)closeBluetoothMenuToSettings {
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self moveMainViewVerticallyTo:kSettingsViewHeight];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished){
        [self.settingsView bringSubviewToFront:self.soundPicker];
        [self ensureOpenSettingsMenu];
    }];
    self.bluetoothMenuIsOpen = NO;
}

-(void)ensureOpenBluetoothMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = YES;
    self.settingsButtonDragView.currentAnimationStep = bluetoothOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = bluetoothOpenAnimStep;

    
    self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
    self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
    
    
    float yPosition = kSettingsViewHeight+self.bluetoothMenu.frame.size.height;
    [self moveMainViewVerticallyTo:yPosition];
    [self.view layoutIfNeeded];
}

- (IBAction)pressedTutorial:(id)sender {
    [self openTutorial];
}

-(void)openTutorial {
    [self closeSettingsMenu];
    [self.tutorialViewController restartTutorial];
    self.tutorialView.alpha = 0;
    self.tutorialView.hidden = NO;
    [UIView animateWithDuration:0.5 animations:^{
        self.tutorialView.alpha = 1;
    }];
    self.tutorialIsOpen = YES;
}

-(void)closeTutorial {
    [UIView animateWithDuration:0.5 animations:^{
        self.tutorialView.alpha = 0;
    } completion:^(BOOL finished){
        self.tutorialView.hidden = YES;
        self.tutorialIsOpen = NO;
    }];
}



#pragma mark -
#pragma mark Camera Functions


//-(void)setCameraButtonText:(NSString *)text withOffset:(CGPoint)offset fontSize:(float)fontSize{
//    self.cameraButtonString = text;
//    if ([text isEqualToString:@""]) {
//        self.cameraButton.buttonImage.image = [self currentCameraButtonImage];
//    } else if (self.cameraMode == CSStateCameraModeActionShot/* && (self.videoProcessor.actionShooting || cameraButton is dragging) */) {
//        self.cameraButton.buttonImage.image = [self maskImage:self.pictureCameraButtonImage withMaskText:text offsetFromCenter:offset fontSize:fontSize];
//    } else {
//        self.cameraButton.buttonImage.image = [self maskImage:[self currentCameraButtonImage] withMaskText:text offsetFromCenter:offset fontSize:fontSize];
//    }
//}

//- (UIImage*) maskImage:(UIImage *)image withMaskText:(NSString *)maskText offsetFromCenter:(CGPoint)offset fontSize:(float)fontSize {
//    
//    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
//    
//    // Create a context for our text mask
//    UIGraphicsBeginImageContextWithOptions(image.size, YES, 1);
//    CGContextRef textMaskContext = UIGraphicsGetCurrentContext();
//    
//	// Draw a white background
//	[[UIColor whiteColor] setFill];
//	CGContextFillRect(textMaskContext, imageRect);
//    // Draw black text
//    [[UIColor blackColor] setFill];
//    
//    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
//    paragraphStyle.alignment = NSTextAlignmentCenter;
//    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
//    NSDictionary *attr = @{NSParagraphStyleAttributeName: paragraphStyle,
//                           NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
//                           NSStrokeColorAttributeName: [UIColor blackColor],
//                           NSStrokeWidthAttributeName: [NSNumber numberWithFloat:5.0]};
//    
//    CGSize textSize = [maskText sizeWithAttributes:attr];
//	[maskText drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y) withAttributes:attr];
//    
//    //add small number for action shooting + animation
//    if (self.videoProcessor.actionShooting && self.cameraButton.isAnimatingButton && self.actionShotSequenceNumber > 0) {
//        attr = @{NSParagraphStyleAttributeName: paragraphStyle,
//                 NSFontAttributeName: [UIFont boldSystemFontOfSize:48],
//                 NSForegroundColorAttributeName: [UIColor blackColor]};
//        NSString *sequenceNumString = [NSString stringWithFormat:@"%i", self.actionShotSequenceNumber];
//        textSize = [sequenceNumString sizeWithAttributes:attr];
//        [sequenceNumString  drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y-70) withAttributes:attr];
//    }
//    
//	// Create an image from what we've drawn
//	CGImageRef textAlphaMask = CGBitmapContextCreateImage(textMaskContext);
//    CGContextRelease(textMaskContext);
//    
//    // create a bitmap graphics context the size of the image
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    CGContextRef mainImageContext = CGBitmapContextCreate (NULL, image.size.width, image.size.height, CGImageGetBitsPerComponent(image.CGImage), 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
//    
//    CGContextDrawImage(mainImageContext, imageRect, self.darkCameraButtonBG.CGImage); // for semi-transparent dark number
//    CGContextClipToMask(mainImageContext, imageRect, textAlphaMask);
//    CGContextDrawImage(mainImageContext, imageRect, image.CGImage);
//    
//    CGImageRef finishedImage =CGBitmapContextCreateImage(mainImageContext);
//    UIImage *finalMaskedImage = [UIImage imageWithCGImage: finishedImage];
//    
//    CGImageRelease(finishedImage);
//    CGContextRelease(mainImageContext);
//    CGImageRelease(textAlphaMask);
//    CGColorSpaceRelease(colorSpace);
//    
//    // return the image
//    return finalMaskedImage;
//    
//}


- (void)pressedCameraButton {
    if (self.shouldPlaySound && self.cameraMode == CSStateCameraModeStill && !self.videoProcessor.recording) {
        [self.soundPlayer play];
        self.takePictureAfterSound = YES;
        [self.cameraButton animateSoundRingForDuration:self.soundDuration];
    } else {
        [self cameraAction];
    }
}

-(void)cameraAction {
    switch (self.cameraMode) {
        case CSStateCameraModeStill:
            if (self.assetsPermission) {
                [self.videoProcessor snapStillImage];
            } else {
                [self checkAssetsPremission];
            }
            break;
        case CSStateCameraModeActionShot:
            if (self.assetsPermission) {
                [self.videoProcessor toggleActionShot];
                if (!self.videoProcessor.actionShooting && !self.cameraButton.isDragging)[self.cameraButton updateCameraButtonWithText:@""];
            } else {
                [self checkAssetsPremission];
            }
            break;
        case CSStateCameraModeVideo:
            if (self.assetsPermission && self.micPermission) {
                [self.videoProcessor toggleRecordVideo];
            } else {
                [self checkMicPermission];
                [self checkAssetsPremission];
            }
            break;
        default:
            break;
    }
}

-(void)startActionShot {
    if (self.assetsPermission && !self.videoProcessor.actionShooting) {
        [self.videoProcessor startActionShot];
        if (!self.videoProcessor.actionShooting && !self.cameraButton.isDragging)[self.cameraButton updateCameraButtonWithText:@""];
    } else {
        [self checkAssetsPremission];
    }
}

-(void)stopActionShot {
    if (self.videoProcessor.actionShooting) {
        [self.videoProcessor stopActionShot];
        if (!self.videoProcessor.actionShooting && !self.cameraButton.isDragging)[self.cameraButton updateCameraButtonWithText:@""];
    }
    
}

-(void)startRecording {
    if (self.assetsPermission && self.micPermission && !self.videoProcessor.isRecording) {
        [self.videoProcessor startRecording];
    } else {
        [self checkMicPermission];
        [self checkAssetsPremission];
    }
}
-(void)stopRecording {
    if (self.videoProcessor.isRecording) {
        [self.videoProcessor stopRecording];
    }
}

-(void)countRecordingTime:(NSTimer *)timer {
    NSTimeInterval secs = [[NSDate date] timeIntervalSinceDate:self.recordingStart];
    int minute = (int)secs/60;
    int second = (int)secs%60;
    if (!self.cameraButton.isAnimatingButton) {
        [self.cameraButton updateCameraButtonWithText:[NSString stringWithFormat:@"%i:%02i", minute, second]];
//TODO: locked orientation stuff for camera button
//        if (self.lockedOrientation == UIDeviceOrientationLandscapeLeft) {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointMake(-15, 0) fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(-15, 0) fontSize:kSmallFontSize];
//            }
//        } else if (self.lockedOrientation == UIDeviceOrientationLandscapeRight) {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointMake(15, 0) fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(15, 0) fontSize:kSmallFontSize];
//            }
//        } else {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointZero fontSize:kSmallFontSize];
//            }
//        }
    }
}

-(void) updateCameraRollButtonWithImage:(UIImage *)image duration:(float)duration {
    [UIView transitionWithView:self.cameraRollButton
                      duration:duration
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.cameraRollImage.image = image;
                    } completion:nil];
}

#pragma mark -
#pragma mark Flash Button

- (IBAction)pressedFlashButton:(id)sender {
    if (self.flashModeMenuIsOpen) {
        [self closeFlashModeMenu:sender];
    } else {
        [self openFlashModeMenu];
    }
}

-(void)openFlashModeMenu {
    self.flashModeMenuIsOpen = YES;
    switch (self.flashMode) {
        case CSStateFlashModeAuto: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashOnDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeOnButton.alpha = kDefaultAlpha;
                
                self.flashOffDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOffButton.alpha = kDefaultAlpha;
                
                [self.view layoutIfNeeded];
            } completion:^(BOOL finished) {
            }];
            break;
        }
        case CSStateFlashModeOn: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashAutoDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashOffDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOffButton.alpha = kDefaultAlpha;
                [self.view layoutIfNeeded];

            } completion:^(BOOL finished) {
            }];
            break;
        }
        case CSStateFlashModeOff: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashAutoDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashOnDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOnButton.alpha = kDefaultAlpha;
                [self.view layoutIfNeeded];

            } completion:^(BOOL finished) {
            }];
            break;
        }
        default:
            break;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL notFirstTime = [[defaults objectForKey:@"isNotFirstTimeFlashMenu"] boolValue];
    if (!notFirstTime) {
        [UIView animateWithDuration:0.5 animations:^{
            _flashOnLabel.alpha = 1;
            _flashOffLabel.alpha = 1;
            _flashAutoLabel.alpha = 1;
        }];
        [defaults setObject:@YES forKey:@"isNotFirstTimeFlashMenu"];
        [defaults synchronize];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (_flashModeMenuIsOpen) {
                [UIView animateWithDuration:0.5 animations:^{
                    _flashOnLabel.alpha = 1;
                    _flashOffLabel.alpha = 1;
                    _flashAutoLabel.alpha = 1;
                }];
            }
        });
    }
}

-(void)closeFlashModeMenu:(id)sender {
    [UIView animateWithDuration:0.5 animations:^{
        self.flashOffDistanceToTop.constant = 0;
        self.flashOnDistanceToTop.constant = 0;
        self.flashAutoDistanceToTop.constant = 0;
        if ([sender isEqual:self.flashModeAutoButton]) {
            self.flashModeAutoButton.alpha = kDefaultAlpha;
            self.flashModeOffButton.alpha = 0;
            self.flashModeOnButton.alpha = 0;
            self.flashOffLabel.alpha = 0;
            self.flashOnLabel.alpha = 0;
        } else if ([sender isEqual:self.flashModeOnButton]) {
            self.flashModeOnButton.alpha = kDefaultAlpha;
            self.flashModeOffButton.alpha = 0;
            self.flashModeAutoButton.alpha = 0;
            self.flashAutoLabel.alpha = 0;
            self.flashOffLabel.alpha = 0;
        } else if ([sender isEqual:self.flashModeOffButton]) {
            self.flashModeOffButton.alpha = kDefaultAlpha;
            self.flashModeAutoButton.alpha = 0;
            self.flashModeOnButton.alpha = 0;
            self.flashAutoLabel.alpha = 0;
            self.flashOnLabel.alpha = 0;
        }
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.5 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _flashOnLabel.alpha = 0;
            _flashOffLabel.alpha = 0;
            _flashAutoLabel.alpha = 0;
        } completion:nil];
        
    }];
    
    if ([sender isEqual:self.flashModeAutoButton]) {
        self.currentFlashButton = self.flashModeAutoButton;
        self.flashMode = CSStateFlashModeAuto;
    } else if ([sender isEqual:self.flashModeOnButton]) {
        self.currentFlashButton = self.flashModeOnButton;
        self.flashMode = CSStateFlashModeOn;
    } else if ([sender isEqual:self.flashModeOffButton]) {
        self.currentFlashButton = self.flashModeOffButton;
        self.flashMode = CSStateFlashModeOff;
    }
    if (self.cameraMode == CSStateCameraModeVideo || self.cameraMode == CSStateCameraModeActionShot) {
        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
    } else {
        [self.videoProcessor setTorchMode:AVCaptureTorchModeOff];
        [self.videoProcessor setFlashMode:[self currentAVFlashMode]];
    }
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
    
    self.flashModeMenuIsOpen = NO;
}

#pragma mark -
#pragma mark Camera Modes

-(void) updateModeButtonsForMode:(NSInteger)mode {
    switch (mode) {
        case CSStateCameraModeStill:
            [self.pictureModeButton setSelected:YES];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:NO];

            break;
        case CSStateCameraModeActionShot:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:YES];
            [self.videoModeButton setSelected:NO];

            break;
        case CSStateCameraModeVideo:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:YES];

            break;
        default:
            break;
    }
}

-(void)switchToPictureMode {
    if (self.cameraMode != CSStateCameraModeStill) {
        [self switchToPhotoOutputQuality];
        self.cameraMode = CSStateCameraModeStill;
        [self.videoProcessor setTorchMode:AVCaptureTorchModeOff];
        [self.videoProcessor setFlashMode:[self currentAVFlashMode]];
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self.bluetoothViewController updateRemoteWithCurrentCameraState];
    }
}

- (void)switchToRapidShotMode {
    if (self.cameraMode != CSStateCameraModeActionShot) {
        
        [self switchToPhotoOutputQuality];
        self.cameraMode = CSStateCameraModeActionShot;
        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self.bluetoothViewController updateRemoteWithCurrentCameraState];
    }
}

- (void)switchToVideoMode {
    if (self.cameraMode != CSStateCameraModeVideo) {
        
        [self switchToHighOutputQuality];
        self.cameraMode = CSStateCameraModeVideo;
        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self.bluetoothViewController updateRemoteWithCurrentCameraState];
    }
}

-(void)switchToPhotoOutputQuality {
    [self.videoProcessor beginSwitchingToOutputQuality:AVCaptureSessionPresetPhoto];
}

-(void)switchToHighOutputQuality {
    [self.videoProcessor beginSwitchingToOutputQuality:AVCaptureSessionPresetHigh];
}


-(AVCaptureFlashMode) currentAVFlashMode {
    switch (self.flashMode) {
        case CSStateFlashModeAuto:
            return AVCaptureFlashModeAuto;
            break;
        case CSStateFlashModeOn:
            return AVCaptureFlashModeOn;
            break;
        case CSStateFlashModeOff:
            return AVCaptureFlashModeOff;
            break;
        default:
            return AVCaptureFlashModeAuto;
            break;
    }
}

-(AVCaptureTorchMode) currentAVTorchMode {
    switch (self.flashMode) {
        case CSStateFlashModeAuto:
            return AVCaptureTorchModeAuto;
            break;
        case CSStateFlashModeOn:
            return AVCaptureTorchModeOn;
            break;
        case CSStateFlashModeOff:
            return AVCaptureTorchModeOff;
            break;
        default:
            return AVCaptureTorchModeAuto;
            break;
    }
}

-(AVCaptureFocusMode) currentAVFocusMode {
    if (self.autoFocusMode) {
        return AVCaptureFocusModeContinuousAutoFocus;
    } else {
        return AVCaptureFocusModeLocked;
    }
}

-(AVCaptureExposureMode) currentAVExposureMode {
    if (self.autoExposureMode) {
        return AVCaptureExposureModeContinuousAutoExposure;
    } else {
        return AVCaptureExposureModeLocked;
    }
}

-(void)enableProperCameraModeButtonsForCurrentCameraMode:(BOOL)setEnabled {
    switch (self.cameraMode) {
        case CSStateCameraModeStill:
            self.rapidShotModeButton.enabled = setEnabled;
            self.videoModeButton.enabled = setEnabled;
            break;
        case CSStateCameraModeActionShot:
            self.pictureModeButton.enabled = setEnabled;
            self.videoModeButton.enabled = setEnabled;
            break;
        case CSStateCameraModeVideo:
            self.rapidShotModeButton.enabled = setEnabled;
            self.pictureModeButton.enabled = setEnabled;
            break;
    }
}


//-(UIImage *)currentCameraButtonImage {
//    switch (self.cameraMode) {
//        case CSStateCameraModeStill:
//            return self.pictureCameraButtonImage;
//            break;
//        case CSStateCameraModeActionShot:
//            return self.rapidCameraButtonImage;
//        case CSStateCameraModeVideo:
//            return self.videoCameraButtonImage;
//        default:
//            return self.pictureCameraButtonImage;
//            break;
//    }
//}

//-(UIImage *)currentHighlightedCameraButtonImage {
//    switch (self.cameraMode) {
//        case CSStateCameraModeStill:
//            return self.pictureCameraButtonImageHighlighted;
//            break;
//        case CSStateCameraModeActionShot:
//            if (self.videoProcessor.actionShooting) {
//                return [self maskImage:self.pictureCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kMediumFontSize];
//            } else {
//                return self.rapidCameraButtonImageHighlighted;
//            }
//        case CSStateCameraModeVideo:
//            return [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
//        default:
//            return self.pictureCameraButtonImageHighlighted;
//            break;
//    }
//    NSLog(@"%i", self.cameraMode);
//}


//-(void)switchCameraButtonImageTo:(UIImage *)newImage {
//    [UIView transitionWithView:self.cameraButton
//                      duration:0.35f
//                       options:UIViewAnimationOptionTransitionCrossDissolve
//                    animations:^{
//                        self.cameraButton.buttonImage.image = newImage;
//                    } completion:nil];
//}

#pragma mark -
#pragma mark UI

- (void)runStillImageCaptureAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.layer setOpacity:0.01];
        [UIView animateWithDuration:.2 animations:^{
            [self.view.layer setOpacity:1.0];
        }];
    });
}

-(void)checkMicPermission {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
		if (granted) {
            self.micPermission = YES;
			//Granted access to mediaType
		} else {
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"Where's the mic?"
											message:@"Click-Shot doesn't have permission to use the microphone. You need to change this in your Privacy Settings to record a video."
										   delegate:self
								  cancelButtonTitle:@"OK, I'll fix that now"
								  otherButtonTitles:nil] show];
			});
		}
	}];
}

-(void)checkAssetsPremission {
    self.assetsPermission = YES;
    ALAssetsLibraryGroupsEnumerationResultsBlock assetGroupEnumerator =
    ^(ALAssetsGroup *assetGroup, BOOL *stop) {
        if (assetGroup != nil) {
            // do nothing
        }
    };
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:assetGroupEnumerator failureBlock:^(NSError *error) {
        NSLog(@"%@", error);
        self.assetsPermission = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:@"I can't save!"
                                        message:@"Click-Shot doesn't have permission to access or save photos. You can change this in your Privacy Settings."
                                       delegate:self
                              cancelButtonTitle:@"OK, I'll do that now"
                              otherButtonTitles:nil] show];
        });
    }];

}

-(void) updateMoveableExposureView {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:!self.autoExposureMode] forKey:@"noAutoExposureMode"];
    [self.exposureButton setSelected:self.autoExposureMode];
    CGPoint exposurePoint = [self.videoProcessor startExposeMode:[self currentAVExposureMode]];
    _exposureDevicePoint = exposurePoint;
    self.exposePointView.userInteractionEnabled = !self.autoExposureMode;
    if (!self.autoExposureMode) {
        self.exposePointView.center = CGPointMake(exposurePoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, exposurePoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
        [self.exposePointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = 0;
        }];
    }
}

-(void) updateMoveableExposureViewForCurrentExposurePoint {
    self.exposePointView.alpha = 0;
    
    self.exposePointView.center = CGPointMake(_exposureDevicePoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, _exposureDevicePoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
    [self.exposePointView fixIfOffscreen];

    if (!self.autoExposureMode) {
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.7 animations:^{
                self.exposePointView.alpha = 0;
            }];
        }];
    }
}

-(void) updateMoveableFocusView {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:self.autoFocusMode] forKey:@"autoFocusMode"];
    [self.focusButton setSelected:self.autoFocusMode];
    CGPoint focusPoint = [self.videoProcessor startFocusMode:[self currentAVFocusMode]];
    _focusDevicePoint = focusPoint;
    self.focusPointView.userInteractionEnabled = !self.autoFocusMode;
    if (!self.autoFocusMode) {
        self.focusPointView.center = CGPointMake(focusPoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, focusPoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
        [self.focusPointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = 0;
        }];
    }
}

-(void) updateMoveableFocusViewForCurrentFocusPoint {
    self.focusPointView.alpha = 0;
    
    self.focusPointView.center = CGPointMake(_focusDevicePoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, _focusDevicePoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
    [self.focusPointView fixIfOffscreen];
    if (!self.autoFocusMode) {
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.7 animations:^{
                self.focusPointView.alpha = 0;
            }];
        }];
    }
}

#pragma mark -
#pragma mark Manage Rotations

-(BOOL)shouldAutorotate {
    return NO;
}

- (void)deviceDidRotate:(NSNotification *)notification {
    if (!self.tutorialIsOpen) {
        [self updateRotations];
    }
}

-(void) updateRotations {
    UIDeviceOrientation currentOrientation = [[UIDevice currentDevice] orientation];
	// Don't update the reference orientation when the device orientation is face up/down or unknown.
    
    double rotation = 0;
    switch (currentOrientation) {
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
            return;
        case UIDeviceOrientationPortrait:
            rotation = 0;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortrait];
            self.cameraOrientation = CSStateCameraOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotation = -M_PI;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            self.cameraOrientation = CSStateCameraOrientationUpsideDownPortrait;

            break;
        case UIDeviceOrientationLandscapeLeft:
            rotation = M_PI_2;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeRight];
            self.cameraOrientation = CSStateCameraOrientationUpsideDownLandscape;
            break;
        case UIDeviceOrientationLandscapeRight:
            rotation = -M_PI_2;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeLeft];
            self.cameraOrientation = CSStateCameraOrientationLandscape;
            break;
    }
    [self.bluetoothViewController updateRemoteWithCurrentCameraState]; // for orientation change
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);
    [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        if (!self.videoProcessor.isRecording)
            [self.cameraButton.buttonImage setTransform:transform];
        [self.cameraRollButton setTransform:transform];
        [self.flashModeAutoButton setTransform:transform];
        [self.flashModeOffButton setTransform:transform];
        [self.flashModeOnButton setTransform:transform];
        [self.focusButton setTransform:transform];
        [self.exposureButton setTransform:transform];
        [self.swithCameraButton setTransform:transform];
        [self.settingsButton setTransform:transform];
        [self.soundsButton setTransform:transform];
        [self.bluetoothButton setTransform:transform];
        [self.tutorialButton setTransform:transform];
    } completion:nil];
    if (self.flashModeMenuIsOpen) {
        [self pressedFlashButton:self.currentFlashButton];
    }
}


#pragma mark -
#pragma mark Handle Embed Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"bluetoothTableEmbed"]) {
        LWBluetoothTableViewController *bluetoothController = segue.destinationViewController;
        bluetoothController.delegate = self;
        self.bluetoothViewController = bluetoothController;
    } else if ([segue.identifier isEqualToString:@"tutorialEmbed"]) {
        LWTutorialViewController *tutorialController = segue.destinationViewController;
        self.tutorialViewController = tutorialController;
        self.tutorialView.delegate = tutorialController;
        self.tutorialViewController.mainController = self;
    }
}

#pragma mark -
#pragma mark Bluetooth Delegates

-(void)bluetoothButtonPressed {
    if (!self.cameraButton.isAnimatingButton) {
        [self pressedCameraButton];
    }
}

-(void)connectedToBluetoothDevice {
    [self.bluetoothButton setSelected:YES];
}

-(void)disconnectedFromBluetoothDevice {
    [self.bluetoothButton setSelected:NO];
}

-(void)receivedMessageFromCameraRemoteApp:(NSData *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        _shouldSendChangesToRemote = NO;
        NSLog(@"Received from remote: %@", message);
        CGFloat remoteFocusDevicePointX = 0;
        CGFloat remoteFocusDevicePointY = 0;
        CGFloat remoteExposureDevicePointX = 0;
        CGFloat remoteExposureDevicePointY = 0;
        for (int i = 0; i < message.length; i++) {
            Byte byteBuffer;
            [message getBytes:&byteBuffer range:NSMakeRange(i, 1)];
            switch (i) {
                case 0: // Camera Action
                    switch (byteBuffer) {
                        case CSStateButtonActionNone:
                            // do nothing
                            break;
                        case CSStateButtonActionTakePicture:
                            //                        if (self.cameraButton.enabled) {
                            [self pressedCameraButton];
                            //                        }
                            break;
                        case CSStateButtonActionStartActionShot:
                            [self startActionShot];
                            break;
                        case CSStateButtonActionStopActionShot:
                            [self stopActionShot];
                            break;
                        case CSStateButtonActionStartVideo:
                            [self startRecording];
                            break;
                        case CSStateButtonActionStopVideo:
                            [self stopRecording];
                            break;
                        default:
                            break;
                    }
                    break;
                case 1: // Camera Mode
                    if (self.cameraMode != byteBuffer) {
                        switch (byteBuffer) {
                            case CSStateCameraModeStill:
                                [self pressedPictureMode:nil];
                                break;
                            case CSStateCameraModeActionShot:
                                [self pressedRapidShotMode:nil];
                                break;
                            case CSStateCameraModeVideo:
                                [self pressedVideoMode:nil];
                                break;
                            default:
                                break;
                        }
                    }
                    break;
                case 2: // Flash Mode
                    if (byteBuffer != self.flashMode) {
                        switch (byteBuffer) {
                            case CSStateFlashModeAuto:
                                [self closeFlashModeMenu:self.flashModeAutoButton];
                                break;
                            case CSStateFlashModeOn:
                                [self closeFlashModeMenu:self.flashModeOnButton];
                                break;
                            case CSStateFlashModeOff:
                                [self closeFlashModeMenu:self.flashModeOffButton];
                                break;
                            default:
                                break;
                        }
                    }
                    break;
                case 3: // Camera Position
                    switch (byteBuffer) {
                        case CSStateCameraPositionBack:
                            if ([self.videoProcessor.captureDevice position] != AVCaptureDevicePositionBack) {
                                [self.videoProcessor beginSwitchingCamera];
                            }
                            break;
                        case CSStateCameraPositionFront:
                            if ([self.videoProcessor.captureDevice position] != AVCaptureDevicePositionFront) {
                                [self.videoProcessor beginSwitchingCamera];
                            }
                            break;
                        default:
                            break;
                    }
                    break;
                case 4: // Sound
                    if (self.cameraSound != byteBuffer) {
                        [self updateSoundPlayerWithSoundNumber:byteBuffer];
                    }
                    break;
                case 5: // auto focus
                    if (_autoFocusMode != byteBuffer) {
                        _autoFocusMode = byteBuffer;
                        [self updateMoveableFocusView];
                    }
                    break;
                case 6: { // Focus X
                    remoteFocusDevicePointX = ((CGFloat)byteBuffer)/100.0;
                    break;
                }
                case 7: { // Focus Y
                    remoteFocusDevicePointY = ((CGFloat)byteBuffer)/100.0;
                    break;
                }
                case 8: // auto expsure
                    if (_autoExposureMode != byteBuffer) {
                        _autoExposureMode = byteBuffer;
                        [self updateMoveableExposureView];
                    }
                    break;
                case 9: { // Exposure X
                    remoteExposureDevicePointX = ((CGFloat)byteBuffer)/100.0;
                    break;
                }
                case 10: { // Exposure Y
                    remoteExposureDevicePointY = ((CGFloat)byteBuffer)/100.0;
                    break;
                }
                default:
                    break;
            }
        }
        if (remoteFocusDevicePointY != _focusDevicePoint.y || remoteFocusDevicePointX != _focusDevicePoint.x) {
            _focusDevicePoint = CGPointMake(remoteFocusDevicePointX, remoteFocusDevicePointY);
            [self.videoProcessor focusAtPoint:_focusDevicePoint];
            [self updateMoveableFocusViewForCurrentFocusPoint];
        }
        if (remoteExposureDevicePointY != _exposureDevicePoint.y || remoteExposureDevicePointX != _exposureDevicePoint.x) {
            _exposureDevicePoint = CGPointMake(remoteExposureDevicePointX, remoteExposureDevicePointY);
            [self.videoProcessor exposeAtPoint:_exposureDevicePoint];
            [self updateMoveableExposureViewForCurrentExposurePoint];
        }
        _shouldSendChangesToRemote = YES;

    });

}

-(NSData *)currentStateData {
    Byte focusX = [self byteForFEFloat:_focusDevicePoint.x];
    Byte focusY = [self byteForFEFloat:_focusDevicePoint.y];
    Byte exposureX = [self byteForFEFloat:_exposureDevicePoint.x];
    Byte exposureY = [self byteForFEFloat:_exposureDevicePoint.y];
    
    AVCaptureDevicePosition currentCameraPosition = [self.videoProcessor.captureDevice position];
    Byte cameraPosition = CSStateCameraPositionBack;
    if (currentCameraPosition == AVCaptureDevicePositionFront) {
        cameraPosition = CSStateCameraPositionFront;
    }
    const Byte messageBytes[13] = { CSStateButtonActionNone , self.cameraMode, self.flashMode, cameraPosition, self.cameraSound, self.autoFocusMode,focusX, focusY, self.autoExposureMode, exposureX, exposureY, self.currentDeviceHasFlash, self.cameraOrientation};
    
    
    NSData *currentState = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
    
    if (!_shouldSendChangesToRemote) {
        const Byte empty[1] = {0x00};
        return [NSData dataWithBytes:empty length:1];
    } else {
        return currentState;
    }

}

-(Byte)byteForFEFloat:(CGFloat)number{
    number *= 100;
    return (Byte)number;
}


#pragma mark -
#pragma mark Manage Touches

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        _primaryTouch = [touches anyObject];
        _startXTouch = [_primaryTouch locationInView:self.view].x;
        _hasMoved = NO;
        _lastMoveTime = CACurrentMediaTime();
        _selectorBarStartCenterX = self.modeSelectorBar.center.x;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        // Switching camera mode with swipe
        CGFloat currentXPos = [[touches anyObject] locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (diffFromBeginning < 0 ) { //swiping  to rapid shot or video shot
            if (self.modeSelectorBar.frame.origin.x < self.videoModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(self.view.frame.size.width/55)), self.modeSelectorBar.center.y);
            }
            if (self.cameraMode == CSStateCameraModeStill) { // swiping to rapid from picture
                [self swipeView:self.rapidShotSwipeView distance:diffFromBeginning];
            } else if (self.cameraMode == CSStateCameraModeActionShot) { // swiping to video from rapid
                [self swipeView:self.videoSwipeView distance:diffFromBeginning];
            }
        } else  { // swiping  to rapid shot or picture shot
            if (self.modeSelectorBar.frame.origin.x > self.pictureModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(self.view.frame.size.width/55)), self.modeSelectorBar.center.y);
            }
            if (self.cameraMode == CSStateCameraModeVideo) { // swiping to rapid from video
                [self swipeView:self.rapidShotSwipeView distance:diffFromBeginning];
            } else if (self.cameraMode == CSStateCameraModeActionShot) { // swiping to picture from rapid
                [self swipeView:self.pictureSwipeView distance:diffFromBeginning];
            }
        }
        [self highlightSelectorMode];
        CGFloat diffFromLastPos = currentXPos - _previousXTouch;
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval elapsedTime = now - _lastMoveTime;
        _velocity = diffFromLastPos/elapsedTime;
        
        _previousXTouch = currentXPos;
        _lastMoveTime = now;
        _hasMoved = YES;
    }
}

-(void)swipeView:(UIView *)view distance:(CGFloat)distance {
    view.alpha = fabsf(distance)/self.view.frame.size.width;
    if (distance < 0) {
        view.frame = CGRectMake(self.view.frame.size.width+distance, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
    } else {
        view.frame = CGRectMake(distance-self.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        // Switching camera mode with swipe
        CGFloat currentXPos = [_primaryTouch locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (_hasMoved) {
            if (_velocity >= kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == CSStateCameraModeVideo) {
                    [self swipeToMode:CSStateCameraModeActionShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == CSStateCameraModeActionShot) {
                    [self swipeToMode:CSStateCameraModeStill withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else if (_velocity <= -kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == CSStateCameraModeStill) {
                    [self swipeToMode:CSStateCameraModeActionShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == CSStateCameraModeActionShot) {
                    [self swipeToMode:CSStateCameraModeVideo withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else {
                [self swipeToSelectedButtonCameraMode];
            }
        }
        _primaryTouch = nil;
        _hasMoved = NO;
    }
    else if (self.settingsMenuIsOpen && IPHONE_4 && CGRectContainsPoint(self.previewView.frame, [[touches anyObject] locationInView:self.view])) {
        [self closeSettingsMenu];
    }
}


-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(void)swipeToMode:(NSInteger)newMode withVelocity:(CGFloat)velocity andDistanceMoved:(CGFloat)distanceMoved {
    distanceMoved = fabsf(distanceMoved);
    velocity = fabsf(velocity);
    CGFloat distanceToMove = self.pictureModeButton.frame.size.width+1-distanceMoved;
    NSTimeInterval lengthOfAnimation = distanceToMove/velocity;
    lengthOfAnimation *= 2;
    
    if (newMode == CSStateCameraModeStill) {
        [self switchToPictureMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
            self.pictureSwipeView.center = self.view.center;
            self.pictureSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.pictureSwipeView];
        }];
    } else if (newMode == CSStateCameraModeActionShot) {
        [self switchToRapidShotMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
            self.rapidShotSwipeView.center = self.view.center;
            self.rapidShotSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.rapidShotSwipeView];
        }];
    } else if (newMode == CSStateCameraModeVideo) {
        [self switchToVideoMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
            self.videoSwipeView.center = self.view.center;
            self.videoSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.videoSwipeView];
        }];
    }
}

-(void)fadeOutSwipeView:(UIView *)view {
    [UIView animateWithDuration:0.3 delay:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 0;
    } completion:nil];
}

-(void)swipeToSelectedButtonCameraMode {
    if (self.pictureModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeStill) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.frame = CGRectMake(self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
            } completion:^(BOOL finished) {
            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
                self.pictureSwipeView.center = self.view.center;
                self.pictureSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.pictureSwipeView];
            }];
        }
        [self switchToPictureMode];
    } else if (self.rapidShotModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeActionShot) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.videoSwipeView.frame = CGRectMake(self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
                self.pictureSwipeView.frame = CGRectMake(-self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
                self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
            } completion:^(BOOL finished) {

            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.center = self.view.center;
                self.rapidShotSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.rapidShotSwipeView];
            }];
        }
        [self switchToRapidShotMode];
    } else if (self.videoModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeVideo) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.frame = CGRectMake(-self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
            } completion:^(BOOL finished) {

            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
                self.videoSwipeView.center = self.view.center;
                self.videoSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.videoSwipeView];

            }];
        }
        [self switchToVideoMode];
    }
}

-(void)highlightSelectorMode {
    if (fabsf(self.pictureModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = YES;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.rapidShotModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = YES;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.videoModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = YES;
    }
}

-(UIView *)swipeViewForMode:(NSInteger)mode {
    UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
    view.backgroundColor = [UIColor colorWithWhite:0.754 alpha:0.750];
    switch (mode) {
        case CSStateCameraModeStill: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"stillSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        case CSStateCameraModeActionShot: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"actionSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        case CSStateCameraModeVideo: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"videoSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        default:
            break;
    }
    view.alpha = 0;
    [self.view insertSubview:view belowSubview:self.cameraUIView];
    return view;
}

#pragma mark - Drag Animation View Delegate

-(void)dragAnimationViewPressed:(DragAnimationView *)dragAnimationView {
    if (dragAnimationView == self.settingsButtonDragView) {
        self.settingsButton.highlighted = YES;
    }
}

-(void)dragAnimationViewReleased:(DragAnimationView *)dragAnimationView {
    if (dragAnimationView == self.settingsButtonDragView) {
        self.settingsButton.highlighted = NO;
    }
}

-(void)dragAnimationView:(DragAnimationView *)dragAnimationView beganAnimationStep:(NSInteger)animationStep {
    if (animationStep == soundsOpenAnimStep) {
        [self.settingsView bringSubviewToFront:self.soundPicker];
    }
}

-(void)dragAnimationViewTapped:(DragAnimationView *)dragAnimationView atAnimationStep:(NSInteger)animationStep {
    if (animationStep == settingsClosedAnimStep) {
        NSLog(@"tap: open settings menu");
        [self openSettingsMenu];
        _previewOverlayDragView.hidden = NO;
    } else {
        NSLog(@"tap: close settings menu");
        [self closeSettingsMenu];
        _previewOverlayDragView.hidden = YES;
    }
}

-(void)dragAnimationView:(DragAnimationView *)dragAnimationView finishedAtAnimationStep:(NSInteger)animationStep {
    switch (animationStep) {
        case settingsClosedAnimStep:
            NSLog(@"settings closed");
            [self ensureClosedSettingsMenu];
            break;
        case settingsOpenAnimStep:
            NSLog(@"settings open");
            [self ensureOpenSettingsMenu];
            break;
        case soundsOpenAnimStep:
            NSLog(@"sounds open");
            [self ensureOpenSoundsMenu];
            break;
        case bluetoothOpenAnimStep:
            NSLog(@"bluetooth open");
            [self ensureOpenBluetoothMenu];
            break;
        default:
            break;
    }
    if (animationStep == settingsClosedAnimStep) {
        _previewOverlayDragView.hidden = YES;
    } else {
        _previewOverlayDragView.hidden = NO;
    }
}

-(CGFloat)dragAnimationDistanceForView:(DragAnimationView *)dragAnimationView animationStep:(NSInteger)step {
    switch (step) {
        case 0:
            return kSettingsViewHeight;
            break;
        case 1:
            return CGRectGetHeight(self.soundPicker.frame);
        case 2:
            return CGRectGetHeight(self.bluetoothMenu.frame) - CGRectGetHeight(self.soundPicker.frame);
        default:
            return 100;
            break;
    }
}

#pragma mark - Video Processor Delegate



-(void)hideCameraUI {
    [UIView animateWithDuration:0.5 animations:^{
        self.flashModeOnButton.alpha = 0;
        self.flashModeOffButton.alpha = 0;
        self.flashModeAutoButton.alpha = 0;
        self.pictureModeButton.alpha = 0;
        self.rapidShotModeButton.alpha = 0;
        self.videoModeButton.alpha = 0;
        self.modeSelectorBar.alpha = 0;
        self.swithCameraButton.alpha = 0;
        self.cameraRollImage.alpha = 0;
        self.cameraRollButton.alpha = 0;
        self.settingsButton.alpha = 0;
    } completion:^(BOOL finished) {
        self.settingsButtonDragView.userInteractionEnabled = NO;
        self.settingsButton.enabled = NO;
        self.currentFlashButton.enabled = NO;
    }];
}

-(void)showCameraUI {
    self.settingsButtonDragView.userInteractionEnabled = YES;
    self.settingsButton.enabled = YES;
    if (_currentDeviceHasFlash) {
        self.currentFlashButton.enabled = YES;
    }
    [UIView animateWithDuration:0.5 animations:^{
        self.flashModeOnButton.alpha = 1;
        self.flashModeOffButton.alpha = 1;
        self.flashModeAutoButton.alpha = 1;
        self.pictureModeButton.alpha = 1;
        self.rapidShotModeButton.alpha = 1;
        self.videoModeButton.alpha = 1;
        self.modeSelectorBar.alpha = 1;
        self.swithCameraButton.alpha = 1;
        self.cameraRollImage.alpha = 1;
        self.cameraRollButton.alpha = 1;
        self.settingsButton.alpha = 1;
    } completion:nil];
}

-(void)recordingWillStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.pictureModeButton setEnabled:NO];
        [self.rapidShotModeButton setEnabled:NO];
        [self.swithCameraButton setEnabled:NO];
        [self.cameraRollButton setEnabled:NO];
//        [self.settingsButton setEnabled:NO];
        self.swipeModesGestureIsBlocked = YES;
        if (!self.cameraButton.isAnimatingButton) {
            self.cameraButton.isDraggable = NO;
        }
        self.lockedOrientation = [[UIDevice currentDevice] orientation];
        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
        [self hideCameraUI];
    });
}

-(void)recordingDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordingStart = [NSDate date];
        [self countRecordingTime:nil];
        self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(countRecordingTime:) userInfo:nil repeats:YES];
    });
}

-(void)recordingWillStop {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pictureModeButton setEnabled:YES];
        [self.rapidShotModeButton setEnabled:YES];
        [self.swithCameraButton setEnabled:YES];
        [self.cameraRollButton setEnabled:YES];
        //        [self.settingsButton setEnabled:YES];
        if (!self.cameraButton.isDragging) {
            self.swipeModesGestureIsBlocked = NO;
            [self.cameraButton updateCameraButtonWithText:@""];
        }
        self.cameraButton.isDraggable = YES;
        [self showCameraUI];
        [self.recordingTimer invalidate];
        
    });
}

-(void)recordingDidStop:(UIImage *)image savedAt:(NSURL *)assetURL{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRotations];
        [self updateCameraRollButtonWithImage:image duration:0.25];
        //TODO: updated gallery items here instead
        if (!self.cameraButton.isDragging) {
            [self updateGalleryItems];
        }
        //        MHGalleryItem *item = [[MHGalleryItem alloc] initWithURL:assetURL.absoluteString galleryType:MHGalleryTypeVideo];
        //        [self.galleryItems insertObject:item atIndex:0];
        
    });
}
- (void)willTakeStillImage {
    
}


- (void)didTakeStillImage:(UIImage *)image {
    [self runStillImageCaptureAnimation];
    [self updateCameraRollButtonWithImage:image duration:0.35];
    // updated gallery items in didFinishSavingStillImage instead
    //    MHGalleryItem *item = [[MHGalleryItem alloc] initWithImage:image];
    //    [self.galleryItems insertObject:item atIndex:0];
}

-(void)didFinishSavingStillImage {
        [self updateGalleryItems];
}


- (void)didTakeActionShot:(UIImage *)image number:(int)seriesNumber {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.videoProcessor.actionShooting) {
            [self.cameraButton updateCameraButtonWithText:@""];
            self.actionShotSequenceNumber = 0;
        } else {
            [self updateCameraRollButtonWithImage:image duration:0.2];
            self.actionShotSequenceNumber = seriesNumber;

            if (!self.cameraButton.isAnimatingButton) {
                [self.cameraButton updateCameraButtonWithText:[NSString stringWithFormat:@"%i", seriesNumber]];
            } else {
                //TODO: might not need this line below
                [self.cameraButton updateCameraButtonWithText:self.cameraButton.cameraButtonString];
            }

//            [UIView animateWithDuration:0.05 delay:0 options:UIViewAnimationOptionAllowAnimatedContent animations:^{
//                self.cameraButton.buttonImage.alpha = 0;
//            } completion:^(BOOL finished) {
//                [UIView animateWithDuration:0.05 animations:^{
//                    self.cameraButton.buttonImage.alpha = 1;
//                }];
//            }];
            
            // taken out because caused large memory over load problems
            //TODO: updated gallery items here instead
//            [self updateGalleryItems];
//            MHGalleryItem *item = [[MHGalleryItem alloc] initWithImage:image];
//            [self.galleryItems insertObject:item atIndex:0];
        }
    });
}

-(void)actionShotDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.pictureModeButton setEnabled:NO];
        [self.videoModeButton setEnabled:NO];
        [self.swithCameraButton setEnabled:NO];
        [self.cameraRollButton setEnabled:NO];
//        [self.settingsButton setEnabled:NO];
        self.swipeModesGestureIsBlocked = YES;
        self.cameraButton.isDraggable = NO;
        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
        [self hideCameraUI];
    });
}

-(void)actionShotDidStop {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.cameraButton.isDraggable = YES;
        [self.pictureModeButton setEnabled:YES];
        [self.videoModeButton setEnabled:YES];
        [self.swithCameraButton setEnabled:YES];
        [self.cameraRollButton setEnabled:YES];
//        [self.settingsButton setEnabled:YES];
        if (!self.cameraButton.isDragging) {
            self.swipeModesGestureIsBlocked = NO;
        }
        [self showCameraUI];
        if (!self.cameraButton.isDragging) {
            [self updateGalleryItems];
        }
    });
}

-(void) willSwitchCamera:(UIImage *)image {
    _settingsButton.enabled = NO;
    _settingsButtonDragView.userInteractionEnabled = NO;
    [UIView transitionWithView:self.blurredImagePlaceholder duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:nil];
    [UIView transitionWithView:self.previewView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:^(BOOL finished){
        [UIView animateWithDuration:0.5 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.blurredImagePlaceholder.alpha = 0;
            [self updateCameraPreviewPosition];
            [self updateTappablePreviewRectForCameraMode:self.cameraMode];
        } completion:^(BOOL finished) {
            _settingsButton.enabled = YES;
            _settingsButtonDragView.userInteractionEnabled = YES;
        }];
    }];
    
    UIImage *blurredImage = [self.blurFilter imageByFilteringImage:image];
    if (self.videoProcessor.captureDevice.position == AVCaptureDevicePositionFront) {
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(-1, 1);
    } else {
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(1, 1);
    }
    self.blurredImagePlaceholder.image = blurredImage;
    self.blurredImagePlaceholder.alpha = 1;
}

-(void)readyToSwitchToCurrentOutputQuality:(UIImage *)image {
    UIImage *blurredImage = [self.blurFilter imageByFilteringImage:image];
    if (self.videoProcessor.captureDevice.position == AVCaptureDevicePositionFront) {
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(-1, 1);
    } else {
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(1, 1);
    }
    self.blurredImagePlaceholder.image = blurredImage;
    
    _settingsButton.enabled = NO;
    _settingsButtonDragView.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.blurredImagePlaceholder.alpha = 1;
    } completion:^(BOOL finished) {
        self.previewView.alpha = 0;
        

        [self.videoProcessor switchToCurrentOutputQuality];
        [UIView animateWithDuration:0.4 delay:1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.blurredImagePlaceholder.alpha = 0;
            self.previewView.alpha = 1;
            [self updateCameraPreviewPosition];
            [self updateTappablePreviewRectForCameraMode:self.cameraMode];
            [self updateDragViewAnimations];
        } completion:^(BOOL finished) {
            _settingsButton.enabled = YES;
            _settingsButtonDragView.userInteractionEnabled = YES;
        }];
    }];
}


- (void)switchedToCameraDevice:(AVCaptureDevice *)device {
    if([device hasFlash]) {
        _flashModeOnButton.enabled = YES;
        _flashModeOffButton.enabled = YES;
        _flashModeAutoButton.enabled = YES;
        _currentDeviceHasFlash = YES;
    } else {
        _flashModeOnButton.enabled = NO;
        _flashModeOffButton.enabled = NO;
        _flashModeAutoButton.enabled = NO;
        _currentDeviceHasFlash = NO;
    }
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
}

- (BOOL)connectedToPeer {
    return self.bluetoothViewController.fullyConnectedToPeer;
}

- (void)sendPreviewImageToPeer:(UIImage *)image {
    NSData *compressedImageData = UIImageJPEGRepresentation(image, 0.0);
    [self.bluetoothViewController sendImageDataToRemote:compressedImageData];
}


-(void)updateGalleryItems {
    //TODO: dont do this on main queue?
    NSLog(@"updated gallery items");
    self.galleryItems = [NSMutableArray new];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        [group setAssetsFilter:[ALAssetsFilter allAssets]];
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *alAsset, NSUInteger index, BOOL *innerStop) {
            if (alAsset) {
                if ([[alAsset valueForProperty:@"ALAssetPropertyType"] isEqualToString:@"ALAssetTypePhoto"]) {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeImage];
                    [self.galleryItems addObject:item];
                } else {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeVideo];
                    [self.galleryItems addObject:item];
                }
            }
        }];
    } failureBlock: ^(NSError *error) {
        NSLog(@"ERROR in method updateGalleryItems in class CameraViewController =====> %@", error);
    }];
}

#pragma mark - Sound Picker Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 6;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    switch (row) {
        case 0:
            return @"No Sound";
            break;
        case 1:
            return @"Bomb Countdown";
            break;
        case 2:
            return @"Alien Ramp Up";
            break;
        case 3:
            return @"Cat Meow";
            break;
        case 4:
            return @"Bird Chirp";
            break;
        case 5:
            return @"Dog Bark";
            break;
        default:
            return @"No Sound";
            break;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 35;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    [self updateSoundPlayerWithSoundNumber:row];
    if (self.shouldPlaySound) {
        self.takePictureAfterSound = NO;
        [self.soundPlayer play];
    }
}

-(void)updateSoundPlayerWithSoundNumber:(Byte)number {
    self.shouldPlaySound = YES;
    NSError *error;
    NSURL *soundURL = nil;
    self.cameraSound = number;
    [self.bluetoothViewController updateRemoteWithCurrentCameraState];
    switch (number) {
        case 0:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            break;
        case 1: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"bombCountdown" ofType:@"wav"]];
            break;
        }
        case 2: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"alienRampUp" ofType:@"wav"]];
            break;
        }
        case 3: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"catMeow" ofType:@"wav"]];
            break;
        }
        case 4: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"birdChirp" ofType:@"wav"]];
            break;
        }
        case 5: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"dogBark" ofType:@"wav"]];
            break;
        }
        default:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            break;
    }
    if (soundURL) {
        AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:soundURL options:nil];
        CMTime audioDuration = audioAsset.duration;
        self.soundDuration = CMTimeGetSeconds(audioDuration);
        self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&error];
    }
    if (number == 0)
        [self.soundsButton setSelected:NO];
    else
        [self.soundsButton setSelected:YES];
    self.soundPlayer.delegate = self;
    [self.soundPlayer prepareToPlay];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:number] forKey:@"sound"];
}

#pragma  mark - Audio Player Delegate

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.takePictureAfterSound) {
        [self cameraAction];
        self.takePictureAfterSound = NO;
        [self.cameraButton updateCameraButtonWithText:@""]; // get rid of sound symbol in camera button
    }
}

#pragma  mark - Memory Warning
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
