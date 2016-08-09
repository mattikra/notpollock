//
//  ValveCommunicator.m
//
//  Created by Matthias Krauß on 12.10.14.
//  Copyright (c) 2014 Matthias Krauß. All rights reserved.
//

#import "ValveCommunicator.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Settings.h"

#define POLLOCK_SERVICE_UUID   @"E81CD5C9-998B-40DD-80B9-34EF303046DB"
#define POLLOCK_COMM_CHAR_UUID  @"E81C2001-998B-40DD-80B9-34EF303046DB"
#define BLE_QUEUE_NAME "BLE central manager queue"


@interface ValveCommunicator () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, readwrite, assign) ValveCommunicatorState state;
@property (readwrite, assign) BOOL connected;
@property (readwrite, assign) BOOL isOpen;

@property (strong) CBCentralManager* manager;
@property (strong) CBPeripheral* peripheral;
@property (strong) CBService* service;
@property (strong) CBCharacteristic* characteristic;
@property (strong) NSTimer* rssiTimer;

/** trigger a rescan of devices. Rescans typically don't have to be triggered manually, but
 it might be helpful if something went wrong
 @return YES if the scan procedure was successfully (re-)started. */
- (BOOL) rescan;

/** sends a command.
 @param datnonatomic, a data to send */
- (BOOL) sendCommand:(NSData*)data;

@end

@implementation ValveCommunicator

- (id) init {
    self = [super init];
    if (!self) return nil;
    self.state = State_Initializing;
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_queue_create(BLE_QUEUE_NAME, NULL)];
    return self;
}

- (BOOL) rescan {
    NSLog(@"rescanning");
    if (self.state == State_BTOff) return NO;
    if (self.state == State_BTDisallowed) return NO;
    if (self.state == State_BTUnavailable) return NO;
    [self.manager stopScan];
    self.peripheral = nil;        //assume none found - will also disconnect if we're still connected
    self.service = nil;
    self.characteristic = nil;
    [self.rssiTimer invalidate];
    self.rssiTimer = nil;
    NSArray* services = @[[CBUUID UUIDWithString:POLLOCK_SERVICE_UUID]];
    self.state = State_Scanning;
    [self.manager scanForPeripheralsWithServices:services options:@{}];
    return YES;
}

- (BOOL) sendCommand:(NSData*)data {
    NSLog(@"sending command %@",data);
    if (self.state != State_Connected) {
        return NO;
    }
    [self.peripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
    return YES;
}

//CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"central manager state changed to %i",(int)central.state);
    switch (central.state) {
        case CBCentralManagerStateUnsupported:
            self.state = State_BTUnavailable;
            break;
        case CBCentralManagerStateUnauthorized:
            self.state = State_BTDisallowed;
            break;
        case CBCentralManagerStatePoweredOff:
            self.state = State_BTOff;
            break;
        case CBCentralManagerStatePoweredOn:
            [self rescan];
            break;
        default:
            //transient states
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"discovered peripheral");
    self.peripheral = peripheral;
    self.peripheral.delegate = self;
    [self.manager stopScan];
    self.state = State_Connecting;
    [self.manager connectPeripheral:peripheral options:@{}];
}


- (void) updaterssi:(NSTimer*)timer {
    [self.peripheral readRSSI];
    NSLog(@"RSSI: %f",[self.peripheral.RSSI floatValue]);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"did connect");
    self.peripheral = peripheral;
    NSArray* uuids = @[[CBUUID UUIDWithString:POLLOCK_SERVICE_UUID]];
    [peripheral discoverServices:uuids];
    self.rssiTimer = [NSTimer timerWithTimeInterval:0.2
                                                      target:self
                                                    selector:@selector(updaterssi:)
                                                    userInfo:nil
                                                     repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.rssiTimer forMode:NSRunLoopCommonModes];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"failed to connect: %@",error);
    [self rescan];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"disconnected: %@",error);
    [self rescan];
}

//CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"discovered services");
    if (error) {
        NSLog(@"error with services discovery");
        [self rescan];
        return;
    }
    NSArray* services = [self.peripheral services];
    if (services.count < 1) {
        NSLog(@"no services");
        [self rescan];
        return;
    }
    NSLog(@"service count: %i", (int)services.count);
    self.service = services[0];
    
    CBUUID* commUUID = [CBUUID UUIDWithString:POLLOCK_COMM_CHAR_UUID];
    NSArray* uuids = @[commUUID];
    [self.peripheral discoverCharacteristics:uuids forService:self.service];
//    [self.peripheral discoverCharacteristics:nil forService:self.service];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"discovered characteristics");
    if (error) {
        NSLog(@"error with characteristics discovery");
        [self rescan];
        return;
    }
    NSArray* characteristics = [self.service characteristics];
    if (characteristics.count < 1) {
        NSLog(@"no characteristics");
        [self rescan];
        return;
    }
    self.characteristic = characteristics[0];
    NSLog(@"connected now. %i characteristics. First is %@", (int)characteristics.count, characteristics[0]);
    self.state = State_Connected;
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"read callback");
}

- (void) setState:(ValveCommunicatorState)state {
    if (_state != state) {
        [self willChangeValueForKey:@"state"];
        _state = state;
        [self didChangeValueForKey:@"state"];
        self.connected = (state == State_Connected);
        [self syncValveState];
    }
}

- (void) setShouldBeOpen:(BOOL)shouldBeOpen {
    if (_shouldBeOpen != shouldBeOpen) {
        [self willChangeValueForKey:@"shouldBeOpen"];
        _shouldBeOpen = shouldBeOpen;
        [self didChangeValueForKey:@"shouldBeOpen"];

        [self syncValveState];
    }
}

- (void) syncValveState {
    if (self.connected) {
        if (self.isOpen != self.shouldBeOpen) {
            uint8_t val = self.shouldBeOpen;
            NSData* data = [NSData dataWithBytes:&val length:1];
            [self sendCommand:data];
            self.isOpen = self.shouldBeOpen;
            if (self.isOpen) {
                NSTimer* timer = [NSTimer timerWithTimeInterval:VALVE_ON_TIME_S
                                                         target:self
                                                       selector:@selector(close:)
                                                       userInfo:nil
                                                        repeats:NO];
                [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            }

        }
    } else {
        self.isOpen = NO;
        return;
    }
}

- (void) close:(id)arg {
    [self setShouldBeOpen:NO];
}
@end
