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
#include DITHER_HEADER

//#import "FloydSteinbergDithering.h"

@interface AppDelegate () <CameraGrabberDelegate>

@property (weak) IBOutlet NSWindow* window;
@property (weak) IBOutlet NSImageView* imageView;
@property (weak) IBOutlet NSImageView* templateImageView;

@property (strong) CameraGrabber* grabber;
@property (strong) ValveCommunicator* valve;
@property (strong) MarkerDetector* markerDetector;
@property (strong) FakeMarkerDetector* fakeMarkerDetector;
@property (strong) DITHER_CLASS* behaviour;

@property (assign) NSTimeInterval lastDrop;

//@property (strong) DitheringBaseGrid *ditheringGrid;

@end

@implementation AppDelegate

-(void)setFakeTracking:(BOOL)fakeTracking {
  _fakeTracking = fakeTracking;
//  [self reInitDithering:_fakeTracking];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.grabber = [CameraGrabber new];
    self.valve = [ValveCommunicator new];
    self.grabber.delegate = self;
    self.markerDetector = [MarkerDetector new];
    self.fakeMarkerDetector = [FakeMarkerDetector new];
    NSURL* templateURL = [[NSBundle mainBundle] URLForImageResource:TEMPLATE_NAME];
    self.behaviour = [[DITHER_CLASS alloc] initWithTemplateURL:templateURL];
    self.behaviour.idleHeight = CAN_HEIGHT;
    self.behaviour.releaseDelay = VALVE_LATENCY;
    self.fakeTracking = NO;
    self.lastDrop = 0.0;
    self.doDrop = NO;
    self.centerX = 0.0;
    self.centerY = 0.0;
    self.roiSize = 0.5;
    self.thresSens = THRESHOLD_PERCENT * 0.01;
}

//-(void) reInitDithering: (BOOL) fake {
//  //TODO: optimize?
//  if(!fake) {
//    NSImage *img = [NSImage imageNamed:@"template"];
//    self.ditheringGrid = [[FloydSteinbergDithering alloc] initWithWidth:img.size.width Height:img.size.height];
//  } else {
//    self.ditheringGrid = [[FloydSteinbergDithering alloc] initWithWidth:1000 Height:1000];
//  }
//}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    self.grabber.delegate = nil;
    self.markerDetector = nil;
    self.fakeMarkerDetector = nil;
    self.behaviour = nil;
}

- (void) handleCameraFrame:(NSBitmapImageRep*)frame timestamp:(NSDate*)timestamp {
    NSPoint pos;
    BOOL detected = NO;
    
    //determine ROI region
    int width = (int)[frame pixelsWide];
    int height = (int)[frame pixelsHigh];
    int roiMinX = (self.centerX / 2.0 + 0.5) * width - 0.5 * MAX(width,height) * self.roiSize;
    int roiMinY = (self.centerY / 2.0 + 0.5) * height - 0.5 * MAX(width,height) * self.roiSize;
    int roiMaxX = (self.centerX / 2.0 + 0.5) * width + 0.5 * MAX(width,height) * self.roiSize;
    int roiMaxY = (self.centerY / 2.0 + 0.5) * height + 0.5 * MAX(width,height) * self.roiSize;
    if (roiMinX < 0) roiMinX = 0;
    if (roiMinY < 0) roiMinY = 0;
    if (roiMaxX >= width) roiMaxX = width-1;
    if (roiMaxY >= height) roiMaxY = height-1;

    //Try to find the marker
    if (self.fakeTracking) {
        detected = [self.fakeMarkerDetector detectMarkerInFrame:frame outPosition:&pos];
    } else {
        detected = [self.markerDetector detectMarkerInFrame:frame
                                                    roiMinX:roiMinX
                                                    roiMaxX:roiMaxX
                                                    roiMinY:roiMinY
                                                    roiMaxY:roiMaxY
                                                       sens:self.thresSens
                                                outPosition:&pos];
    }

    //determine if we should drop
    NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
    BOOL canOpen = (now - self.lastDrop > DROP_DEAD_TIME_S);
    if (!self.doDrop) canOpen = NO;
    BOOL open = [self.behaviour shouldOpenWithTrackResult:detected
                                                 position:pos
                                                       at:timestamp
                                                  canOpen:canOpen
                                                      outPos:NULL];
    if (!canOpen) {
        open = NO;
    }
    if (open) {
        self.lastDrop = now;
    }
    self.valve.shouldBeOpen = open;

    //Real handling done. Now visualize.
    NSImage* image = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [frame drawInRect:dstRect];
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform* transform = [NSAffineTransform transform];
        //transform: -1 sould go to roiMin, 1 should go to roiMax
        [transform translateXBy:(roiMaxX+roiMinX)/2.0 yBy:(roiMaxY+roiMinY)/2.0];
        [transform scaleXBy:(roiMaxX-roiMinX)/2.0 yBy:(roiMinY-roiMaxY)/2.0];
        [transform concat];

#ifdef SHOW_ROI
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(-1,-1)];
        [path lineToPoint:NSMakePoint( 1,-1)];
        [path lineToPoint:NSMakePoint( 1, 1)];
        [path lineToPoint:NSMakePoint(-1, 1)];
        [path closePath];
        [path moveToPoint:NSMakePoint(-0.1, 0)];
        [path lineToPoint:NSMakePoint( 0.1, 0)];
        [path moveToPoint:NSMakePoint(0, -0.1)];
        [path lineToPoint:NSMakePoint(0,  0.1)];
        [[NSColor blueColor] set];
        [path setLineWidth:0.01];
        [path stroke];
#endif
        if (detected) {
        
            NSBezierPath* path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(pos.x-0.1, pos.y-0.1)];
            [path lineToPoint:NSMakePoint(pos.x+0.1, pos.y+0.1)];
            [path moveToPoint:NSMakePoint(pos.x+0.1, pos.y-0.1)];
            [path lineToPoint:NSMakePoint(pos.x-0.1, pos.y+0.1)];
            [[NSColor redColor] set];
            [path setLineWidth:0.01];
            [path stroke];
            
            if ([self.behaviour respondsToSelector:@selector(visualizeInRect:)]) {
                [self.behaviour visualizeInRect:dstRect];
            }

            [NSGraphicsContext restoreGraphicsState];
        }
        return YES;
    }];
    
    self.imageView.image = image;
}

- (void)setRoiCenter {
    self.centerX = self.markerDetector.lastRawPoint.x;
    self.centerY = self.markerDetector.lastRawPoint.y;
}

@end
