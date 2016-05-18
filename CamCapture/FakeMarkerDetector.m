//
//  FakeMarkerDetector.m
//  CamCapture
//
//  Created by Matthias Krauß on 16.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "FakeMarkerDetector.h"

#define MIN_FRAMES 100
#define MAX_FRAMES 400
#define MID_JITTER 0.1
#define MIN_AMP 0.2
#define MAX_AMP 0.35
#define MIN_PHASE 0
#define MAX_PHASE (2.0*M_PI)
#define MIN_SPEED 0.015
#define MAX_SPEED 0.06

@interface FakeMarkerDetector ()

@property (assign) int framesRemaining;
@property (assign) double midX;
@property (assign) double midY;
@property (assign) double ampX;
@property (assign) double ampY;
@property (assign) double speedX;
@property (assign) double speedY;
@property (assign) double phaseX;
@property (assign) double phaseY;

- (void) randomize;

@end

@implementation FakeMarkerDetector

- (id) init {
    self = [super init];
    if (self) {
        [self randomize];
    }
    return self;
}

- (void) randomize {
    self.framesRemaining = (int)[self randomFrom:MIN_FRAMES to:MAX_FRAMES];
    self.midX = [self randomFrom:-MID_JITTER to:MID_JITTER];
    self.midY = [self randomFrom:-MID_JITTER to:MID_JITTER];
    self.ampX = [self randomFrom:MIN_AMP to:MAX_AMP];
    self.ampY = [self randomFrom:MIN_AMP to:MAX_AMP];
    self.phaseX = [self randomFrom:MIN_PHASE to:MAX_PHASE];
    self.phaseY = [self randomFrom:MIN_PHASE to:MAX_PHASE];
    self.speedX = [self randomFrom:MIN_SPEED to:MAX_SPEED];
    self.speedY = [self randomFrom:MIN_SPEED to:MAX_SPEED];
}

- (double) randomFrom:(double)min to:(double)max {
    long l = random() & 0x7fffffff;
    double d = ((double)l) / 2147483647.0;
    return (d * (max-min)) + min;
}

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame outPosition:(NSPoint*)pt {
    self.framesRemaining--;
    if (self.framesRemaining < 0) {
        [self randomize];
        return NO;
    }
    self.phaseX += self.speedX;
    self.phaseY += self.speedY;
    if (pt) {
        double x = self.ampX * sin(self.phaseX) + self.midX;
        double y = self.ampY * sin(self.phaseY) + self.midY;
        *pt = NSMakePoint(x,y);
    }
    return YES;
}


@end
