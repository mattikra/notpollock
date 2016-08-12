//
//  ValveCommunicator.h
//
//  Created by Matthias Krauß on 12.10.14.
//  Copyright (c) 2014 Matthias Krauß. All rights reserved.
//

#import <Foundation/Foundation.h>

/** communication states */
typedef enum {
    State_Initializing = 1,
    State_BTOff,
    State_BTUnavailable,
    State_BTDisallowed,
    State_Scanning,
    State_Connecting,
    State_Connected
} ValveCommunicatorState;

/** This class is the communication interface to the BLE hardware */
@interface ValveCommunicator : NSObject

/** reflects the current state of communication with the external hardware. */
@property (nonatomic, readonly, assign) ValveCommunicatorState state;

/** simplified connection state */
@property (readonly, assign) BOOL connected;

/** valve state - actual */
@property (readonly, assign) BOOL isOpen;

/** valve open duration in s */
@property (readwrite, assign) double dropLength;


- (BOOL) drip;

@end
