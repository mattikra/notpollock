//
//  PollockBehaviour.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//


#import <Cocoa/Cocoa.h>


/*Base protocol for a paint distribution strategy */

@protocol PollockBehaviour <NSObject>

@required

@property (assign) NSPoint idlePoint;    //tracked center point when pendulum is idle
@property (assign) double idleHeight;    //height above canvas in m when pendulum is idle
@property (assign) double releaseDelay;  //drop release latency in s

/* initialize with a given template image URL */
- (id) initWithTemplateURL:(NSURL*)url;

/* determine whether the valve should be open or not based on most recent tracking information */
- (BOOL) shouldOpenWithTrackResult:(BOOL)tracked position:(NSPoint)position at:(NSDate*)time canOpen:(BOOL)canOpen outPos:(NSPoint *)out_projectionPoint;

@optional

/* optional method to show current state. Transform is set to put ROI (draw canvas) at -1/1 rect */
- (void) visualizeInRect:(NSRect)rect;

/* will be called regularly if implemented to do internal service stuff */
- (void) regularService;



@end

