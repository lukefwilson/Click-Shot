//
//  CameraViewController.h
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "VideoProcessor.h"
#import "LWBluetoothTableViewController.h"
#import "CameraButton.h"
#import "TransferService.h"


@interface CameraViewController : UIViewController <LWBluetoothButtonDelegate>

-(void)pressedCameraButton;
-(void)enableProperCameraModeButtonsForCurrentCameraMode:(BOOL)setEnabled;
-(AVCaptureTorchMode) currentAVTorchMode;
-(AVCaptureFlashMode) currentAVFlashMode;
-(CGPoint) devicePointForScreenPoint:(CGPoint)screenPoint;
-(void)setExposureDevicePointWithTouchLocation:(CGPoint)touchLocation;
-(void)setFocusDevicePointWithTouchLocation:(CGPoint)touchLocation;


-(void)userReopenedApp;
-(void)userClosedApp;

-(void)openFlashModeMenu;
-(void)closeFlashModeMenu:(id)sender;
-(void)openSettingsMenu;
-(void)closeSettingsMenu;

-(void)openTutorial;
-(void)closeTutorial;

- (IBAction)pressedVideoMode:(id)sender;
- (IBAction)pressedRapidShotMode:(id)sender;
- (IBAction)pressedPictureMode:(id)sender;

-(void)switchingToClickShotMode;

+(UIColor *)getHighlightColor;

@property (nonatomic) BOOL autoFocusMode;
@property (nonatomic) BOOL autoExposureMode;
@property (nonatomic) CGPoint exposureDevicePoint;
@property (nonatomic) CGPoint focusDevicePoint;
@property (nonatomic) CGPoint focusedAtImagePoint;
@property (nonatomic) CGPoint exposededAtImagePoint;


@property (nonatomic) BOOL currentDeviceHasFlash;

@property (nonatomic) BOOL swipeModesGestureIsBlocked;
@property (nonatomic) CSStateCameraMode cameraMode;
@property (nonatomic, strong) NSString *cameraButtonString;
@property (nonatomic) CGRect tappablePreviewRect; // used in MoveableImageView
@property (nonatomic) CGRect previewImageRect;

@property (nonatomic) BOOL takePictureAfterSound;

@property (nonatomic) int actionShotSequenceNumber;

@property (nonatomic, weak) IBOutlet UIButton *pictureModeButton;
@property (nonatomic, weak) IBOutlet UIButton *rapidShotModeButton;
@property (nonatomic, weak) IBOutlet UIButton *videoModeButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraRollButton;

@property (nonatomic, weak) IBOutlet UIButton *flashModeAutoButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOnButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOffButton;

@property (nonatomic, weak) IBOutlet UIButton *swithCameraButton;
@property (nonatomic, weak) IBOutlet UIButton *settingsButton;

@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UIButton *exposureButton;
@property (nonatomic, weak) IBOutlet UIButton *soundsButton;
@property (nonatomic, weak) IBOutlet UIButton *bluetoothButton;

@property (nonatomic, weak) IBOutlet CameraButton *cameraButton;

@property (nonatomic) BOOL settingsMenuIsOpen;
@property (nonatomic) BOOL soundsMenuIsOpen;
@property (nonatomic) BOOL bluetoothMenuIsOpen;
@property (nonatomic) BOOL cameraRollIsOpen;
@property (nonatomic) BOOL tutorialIsOpen;

@property (nonatomic) VideoProcessor *videoProcessor;

@property (nonatomic) UIDeviceOrientation lockedOrientation;

@property (nonatomic) float soundDuration;
@property (nonatomic) CSStateCameraSound cameraSound;
@property (nonatomic) CSStateCameraOrientation cameraOrientation;

@property (nonatomic) BOOL shouldSendChangesToRemote;
@end
