//
//  AppDelegate.m
//  CamCapture
//
//  Created by Matthias Krauß on 04.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "AppDelegate.h"
#import "CameraGrabber.h"
#import "MarkerDetector.h"
#import "FakeMarkerDetector.h"
#import "PollockBehaviour.h"
#import "ValveCommunicator.h"
#import "Settings.h"
#include BEHAVIOUR_HEADER

@interface AppDelegate () <CameraGrabberDelegate>

@property (weak) IBOutlet NSWindow* window;
@property (weak) IBOutlet NSImageView* imageView;

@property (strong) CameraGrabber* grabber;
@property (strong) ValveCommunicator* valve;
@property (strong) MarkerDetector* markerDetector;
@property (strong) FakeMarkerDetector* fakeMarkerDetector;
@property (strong) BEHAVIOUR_CLASS* behaviour;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.grabber = [CameraGrabber new];
    self.valve = [ValveCommunicator new];
    self.grabber.delegate = self;
    self.markerDetector = [MarkerDetector new];
    self.fakeMarkerDetector = [FakeMarkerDetector new];
    NSURL* templateURL = [[NSBundle mainBundle] URLForImageResource:@"template"];
    self.behaviour = [[BEHAVIOUR_CLASS alloc] initWithTemplateURL:templateURL];
    self.fakeTracking = YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    self.grabber.delegate = nil;
    self.markerDetector = nil;
    self.fakeMarkerDetector = nil;
    self.behaviour = nil;
}

- (void) handleCameraFrame:(NSBitmapImageRep*)frame timestamp:(NSDate*)timestamp {
    NSPoint pos;
    BOOL detected = NO;
    if (self.fakeTracking) {
        detected = [self.fakeMarkerDetector detectMarkerInFrame:frame outPosition:&pos];
    } else {
        detected = [self.markerDetector detectMarkerInFrame:frame outPosition:&pos];
    }
    
    BOOL open = [self.behaviour shouldOpenWithTrackResult:detected
                                                 position:pos
                                                       at:timestamp];
    self.valve.shouldBeOpen = open;
    
    //Real handling done. Now visualize.
    
    int width = (int)frame.pixelsWide;
    int height = (int)frame.pixelsHigh;
    int major = MAX(width, height);
    NSImage* image = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [frame drawInRect:dstRect];
        if (detected) {
            [[NSColor redColor] set];
            float xImg = (pos.x / 2.0) * major + (width / 2.0);
            float yImg = (pos.y / 2.0) * major + (height / 2.0);
            [[NSBezierPath bezierPathWithRect:NSMakeRect(xImg-100,height-yImg-10,200,20)] fill];
            [[NSBezierPath bezierPathWithRect:NSMakeRect(xImg-10,height-yImg-100,20,200)] fill];
            if ([self.behaviour respondsToSelector:@selector(visualizeInRect:)]) {
                [self.behaviour visualizeInRect:dstRect];
            }
        }
        return YES;
    }];
    
    self.imageView.image = image;
}

@end
