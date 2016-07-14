//
//  DitheredPollockBehaviour.m
//  CamCapture
//
//  Created by Omid Hashemi on 12/07/16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "DitheredPollockBehaviour.h"
#import "Settings.h"
#include BEHAVIOUR_HEADER

@interface DitheredPollockBehaviour()

@property (strong) BEHAVIOUR_CLASS* behaviour;

@property (assign) int width;
@property (assign) int height;
@property (assign) float stepsize;

@property (strong) NSMutableData* matrixData;

- (float) matrixValueAtX:(unsigned int)x y:(unsigned int)y;
- (void) setMatrixValueAtX:(unsigned int)x y:(unsigned int)y to:(float)val;

@end

@implementation DitheredPollockBehaviour

//PollockBehaviour properties
@synthesize idlePoint;     //tracked center point when pendulum is idle
@synthesize idleHeight;    //height above canvas in m when pendulum is idle
@synthesize releaseDelay;  //drop release latency in s
@synthesize templateScale; //arbitrary scale factor (0..1) - use full tracking range for 1

/* initialize with a given template image URL */
- (id) initWithTemplateURL:(NSURL*)url {
  self = [super init];
  if (self) {
    
    self.width = DITHER_MATRIX_WIDTH;
    self.height = DITHER_MATRIX_HEIGHT;
    self.matrixData = [NSMutableData dataWithLength:sizeof(float) * self.width * self.height];
    self.stepsize = (ABS(DITHER_GRID_MAX_VALUE) + ABS(DITHER_GRID_MIN_VALUE)) / ABS(MAX(DITHER_MATRIX_WIDTH, DITHER_MATRIX_HEIGHT));  // calculate the step size for our matrix
    
    self.behaviour = [[BEHAVIOUR_CLASS alloc] initWithTemplateURL:url];
    self.behaviour.idleHeight = CAN_HEIGHT;
    self.behaviour.templateScale = TEMPLATE_SCALE;
    self.behaviour.releaseDelay = VALVE_LATENCY;
  }
  return self;
}

/* determine whether the valve should be open or not based on most recent tracking information */
- (BOOL) shouldOpenWithTrackResult:(BOOL)tracked position:(NSPoint)position at:(NSDate*)time {
  BOOL open = [self.behaviour shouldOpenWithTrackResult:tracked position:position at:time];
  
  if(open) {
    open = [self shouldOpenForPos:position];
  }
  
  return open;
}

-(BOOL)shouldOpenForPos:(NSPoint)point {
  
  BOOL retVal = false;
//  int major = MAX(self.width, self.height);
  int xImg = [self getMatrixPositionFor:point.x];
  int yImg = [self getMatrixPositionFor:point.y];
  
  NSLog(@"%f x %f -> %d x %d", point.x, point.y, xImg, yImg);
  
  float origVal = [self matrixValueAtX:xImg y:yImg];
  
  float val = [self quadricEase:origVal
                           peak:DITHER_PEAK
                   stdDeviation:DITHER_STD_DEVIATION];
  
  if(origVal > 0) {
    NSLog(@"point(%d, %d): orig: %f new: %f", xImg, yImg, origVal, val);
  }

  [self setMatrixValueAtX:xImg y:yImg to:origVal+val];
  
  if(val > DITHER_MAX_TRESHOLD) {
    retVal = false;
  } else {
    retVal = true;
  }
  
  return retVal;
}

-(float) quadricEase:(float)value peak:(float)peak  stdDeviation:(float)stdDev{
  return( 1.0 / (sqrt(2 * M_PI) * stdDev) *
         exp(-(value - peak) * (value - peak) / (2 * stdDev * stdDev)));
}



/* optional method to show current state */
- (void) visualizeInRect:(NSRect)rect {
  [self.behaviour visualizeInRect:rect];
}

- (int) getMatrixPositionFor:(float) val {
  int ret = val / self.stepsize;
  return ret;
}

- (float) matrixValueAtX:(unsigned int)x y:(unsigned int)y {
  if ((x >= self.width) || (y >= self.height)) {
    return 0.0f;
  }
  float* base = (float*)(self.matrixData.mutableBytes);
  return base[y*self.width+x];
}

- (void) setMatrixValueAtX:(unsigned int)x y:(unsigned int)y to:(float)val {
  if ((x < self.width) && (y < self.height)) {
    float* base = (float*)(self.matrixData.mutableBytes);
    base[y*self.width+x] = val;
  }
}

@end
