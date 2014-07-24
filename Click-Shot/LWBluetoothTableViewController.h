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


@protocol LWBluetoothButtonDelegate;

@interface LWBluetoothTableViewController : UITableViewController <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, weak) id <LWBluetoothButtonDelegate> delegate;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property (strong, nonatomic) NSIndexPath *selectedIndexPath;
@property (strong, nonatomic) NSTimer *scanTimer;
@property (strong, nonatomic) ODRefreshControl *betterRefreshControl;

-(void)refreshBluetoothDevices;
-(void)cleanupBluetooth;

@end


@protocol LWBluetoothButtonDelegate <NSObject>

@optional
-(void)bluetoothButtonPressed;
-(void)connectedToBluetoothDevice;
-(void)disconnectedFromBluetoothDevice;
@end

