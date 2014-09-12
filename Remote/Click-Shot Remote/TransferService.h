/*
 
 File: TransferService.h
 
 Abstract: The UUIDs generated to identify the Service and Characteristics
 used in the App.
 
 Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by
 Apple Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc.
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */


#ifndef LE_Transfer_TransferService_h
#define LE_Transfer_TransferService_h

#define MPC_SERVICE_TYPE           @"csremotempc"

#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IPHONE_4 ([UIScreen mainScreen].bounds.size.height == 480)
#define IPHONE_5 ([UIScreen mainScreen].bounds.size.height == 568)

#define SEND_PREVIEW_IMAGE_INTERVAL 0.35
#define SEND_PREVIEW_IMAGE_INTERVAL_MAX_WAIT 2

typedef NS_ENUM(Byte, CSStateButtonAction) {
    CSStateButtonActionNone = 0,
    CSStateButtonActionTakePicture = 1,
    CSStateButtonActionStartActionShot = 2,
    CSStateButtonActionStopActionShot = 3,
    CSStateButtonActionStartVideo = 4,
    CSStateButtonActionStopVideo = 5
};

typedef NS_ENUM(Byte, CSStateCameraMode) {
    CSStateCameraModeStill = 0,
    CSStateCameraModeActionShot = 1,
    CSStateCameraModeVideo = 2
};

typedef NS_ENUM(Byte, CSStateFlashMode) {
    CSStateFlashModeAuto = 0,
    CSStateFlashModeOn = 1,
    CSStateFlashModeOff = 2
};

typedef NS_ENUM(Byte, CSStateCameraPosition) {
    CSStateCameraPositionBack = 0,
    CSStateCameraPositionFront = 1
};

typedef NS_ENUM(Byte, CSStateCameraSound) {
    CSStateCameraSoundNone = 0,
    CSStateCameraSound1 = 1,
    CSStateCameraSound2 = 2,
    CSStateCameraSound3 = 3,
    CSStateCameraSound4 = 4,
    CSStateCameraSound5 = 5
};

typedef NS_ENUM(Byte, CSStateCameraOrientation) {
    CSStateCameraOrientationPortrait = 0,
    CSStateCameraOrientationLandscape = 1,
    CSStateCameraOrientationUpsideDownPortrait = 2,
    CSStateCameraOrientationUpsideDownLandscape = 3
};

typedef NS_ENUM(Byte, CSCommunication) {
    CSCommunicationNothing = 0,
    CSCommunicationReceivedPreviewPhoto = 1,
    CSCommunicationVirtuallyDisconnectedFromRemote = 2,
    CSCommunicationVirtuallyConnectedToRemote = 3,
    CSCommunicationShouldSendPreviewImages = 4,
    CSCommunicationShouldNotSendPreviewImages = 5,
    CSCommunicationShouldSendTakenPictures = 6,
    CSCommunicationShouldNotSendTakenPictures = 7
};

#define CSNumSounds 7

#define CSSound1FileName  @"beeps"
#define CSSound2FileName  @"fireAlarm"
#define CSSound3FileName  @"bird"
#define CSSound4FileName  @"dog"
#define CSSound5FileName  @"cat"
#define CSSound6FileName  @"fart2"


#define CSSoundNoneDisplayName  @"No Sound"
#define CSSound1DisplayName  @"Beeps"
#define CSSound2DisplayName  @"Fire Alarm"
#define CSSound3DisplayName  @"Bird Chirps"
#define CSSound4DisplayName  @"Dog Bark"
#define CSSound5DisplayName  @"Cat Meow"
#define CSSound6DisplayName  @"Barking Spider"


/*
 
 Message with length of 1: CSCommunication
    Remote -> Camera
        Received Preview Image
        Virtually Disconnected
        Should Receive Preview Image
    Camera -> Remote
        Virtually Disconnected
        Virtually Connected
 Message with length of 13: Camera Update State -> Remote
 Message with length of 11: Remote Update State -> Camera
 Message larger than 20: Camera Preview Image -> Remote
 
 Message Bytes : <button action>, <camera mode>, <flash mode>,<camera position>, <Sound>, autofocus mode,<Focus X pos>, <Focus Y pos>, auto exposure mode,<Exposure X pos>, <Exposure Y pos>, [{([Has Flash, Orientation])}]
 
 */
#endif