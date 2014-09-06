//
//  LWBluetoothTableViewController.h
//  Click-Shot
//
//  Created by Luke Wilson on 6/4/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ODRefreshControl.h"
@import CoreBluetooth;
@import MultipeerConnectivity;


@protocol LWBluetoothButtonDelegate;

@interface LWBluetoothTableViewController : UITableViewController <CBCentralManagerDelegate, CBPeripheralDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate>

@property (nonatomic, weak) id <LWBluetoothButtonDelegate> delegate;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) MCPeerID *connectedPeer;
@property (nonatomic) BOOL fullyConnectedToPeer;
@property (strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property (strong, nonatomic) NSMutableArray *discoveredPeers;
@property (strong, nonatomic) NSIndexPath *selectedIndexPath;
@property (strong, nonatomic) NSTimer *scanTimer;
@property (strong, nonatomic) NSTimer *hideRefreshTimer;
@property (strong, nonatomic) ODRefreshControl *betterRefreshControl;


-(void)refreshBluetoothDevices;
-(void)cleanupBluetooth;
-(void)updateRemoteWithCurrentCameraState;
-(void)sendDataToRemote:(NSData *)data withMode:(MCSessionSendDataMode)sendingMode;
-(void)sendImageAtURL:(NSURL *)url withName:(NSString *)imageName;
-(void)virtuallyDisconnectFromRemote;
-(void)cancelAllProgresses; // called when receive memory warning in root view controller


@end


@protocol LWBluetoothButtonDelegate <NSObject>

-(void)bluetoothButtonPressed;
-(void)connectedToBluetoothDevice;
-(void)disconnectedFromBluetoothDevice;
-(void)receivedMessageFromCameraRemoteApp:(NSData *)message;
-(NSData *)currentStateData;

@end

