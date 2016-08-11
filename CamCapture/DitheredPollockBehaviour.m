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

#define ROUND_VAL 1000000

@interface DitheredPollockBehaviour() {

double _releaseDelay;

}

@property (strong) BEHAVIOUR_CLASS* behaviour;

@property (assign) int width;
@property (assign) int height;
@property (assign) float stepsize;
@property (assign) float coordMove;
@property (assign) float showArray;

@property (strong) NSMutableData* matrixData;

- (float) matrixValueAtX:(unsigned int)x y:(unsigned int)y;
- (void) setMatrixValueAtX:(unsigned int)x y:(unsigned int)y to:(float)val;

@end

@implementation DitheredPollockBehaviour

//PollockBehaviour properties
@synthesize idlePoint;     //tracked center point when pendulum is idle
@synthesize idleHeight;    //height above canvas in m when pendulum is idle
@synthesize showArray;


/* initialize with a given template image URL */
- (id) initWithTemplateURL:(NSURL*)url {
  self = [super init];
  if (self) {
    
    self.showArray = false;
    
    self.width = DITHER_MATRIX_WIDTH;
    self.height = DITHER_MATRIX_HEIGHT;
    self.matrixData = [NSMutableData dataWithLength:sizeof(float) * self.width * self.height];
    self.stepsize = (ABS(DITHER_GRID_MAX_VALUE) + ABS(DITHER_GRID_MIN_VALUE)) / ABS(MAX(DITHER_MATRIX_WIDTH, DITHER_MATRIX_HEIGHT));  // calculate the step size for our matrix
    self.stepsize = floorf(self.stepsize * ROUND_VAL) / ROUND_VAL;
    float max_val = MAX(ABS(DITHER_GRID_MIN_VALUE), ABS(DITHER_GRID_MAX_VALUE));
    self.coordMove = max_val;
    
    NSLog(@"matrix: %d x %d, step size: %f, coord move: %f", self.width, self.height, self.stepsize, self.coordMove);
    
    self.behaviour = [[BEHAVIOUR_CLASS alloc] initWithTemplateURL:url];
    self.behaviour.idleHeight = CAN_HEIGHT;
    self.behaviour.releaseDelay = VALVE_LATENCY;
  }
  return self;
}

- (double) releaseDelay {
    return _releaseDelay;
}

- (void) setReleaseDelay:(double)releaseDelay {
    [self willChangeValueForKey:@"releaseDelay"];
    _releaseDelay = releaseDelay;
    self.behaviour.releaseDelay = releaseDelay;
    [self didChangeValueForKey:@"releaseDelay"];
}

/* determine whether the valve should be open or not based on most recent tracking information */
- (BOOL) shouldOpenWithTrackResult:(BOOL)tracked position:(NSPoint)position at:(NSDate*)time canOpen:(BOOL)canOpen outPos:(NSPoint *)out_projectionPoint {
  
//  // early exit
//  if(!canOpen)
//    return false;
  
  NSPoint pp;
    BOOL open = [self.behaviour shouldOpenWithTrackResult:tracked position:position at:time canOpen:canOpen outPos:&pp];
  
  if(open) {
    open = [self shouldOpenForPos:pp];
  }
  
  return open;
}

-(BOOL)shouldOpenForPos:(NSPoint)point {
  
  BOOL retVal = false;
//  int major = MAX(self.width, self.height);
  int xImg = [self getMatrixPositionFor:point.x];
  int yImg = [self getMatrixPositionFor:point.y];
  
//  NSLog(@"%f x %f -> %d x %d", point.x, point.y, xImg, yImg);
  
  float origVal = [self matrixValueAtX:xImg y:yImg];
  
  //    float testval = 1.3f;
  //    NSLog(@"0: %.5f", testval);
  //    for (int x = 1; x < 1000; x++) {
  //      testval = testval * DITHER_VALUE_ADD_FAKTOR;
  //      if(testval < 1.0) {
  //        testval += 1 + DITHER_VALUE_ADD;
  //        NSLog(@"%d: %.5f", x, testval);
  //      }
  //    }
  
  if(origVal < DITHER_MAX_TRESHOLD) {
    retVal = true;
    origVal += DITHER_MAX_TRESHOLD + DITHER_VALUE_ADD;
  } else {
    retVal = false;
    origVal = origVal * DITHER_VALUE_ADD_FAKTOR;
  }
  
  [self setMatrixValueAtX:xImg y:yImg to:origVal];
  
  for(int x = 1; x <= 3; x++) {
    float addFieldValue = [self ease:self.stepsize * x];
    [self addValue:addFieldValue toXPlus:x x:xImg y:yImg];
  }
  
//  float addFieldValue = [self ease:self.stepsize];
//  [self addValue:addFieldValue toXPlus:1 x:xImg y:yImg];
//
//  addFieldValue = [self ease:self.stepsize * 2];
//  [self addValue:addFieldValue toXPlus:2 x:xImg y:yImg];
//  
//  addFieldValue = [self ease:self.stepsize * 3];
//  [self addValue:addFieldValue toXPlus:3 x:xImg y:yImg];
//  
//  addFieldValue = [self ease:self.stepsize * 4];
//  [self addValue:addFieldValue toXPlus:4 x:xImg y:yImg];
//  
//  addFieldValue = [self ease:self.stepsize * 5];
//  [self addValue:addFieldValue toXPlus:5 x:xImg y:yImg];

  NSLog(@"(%d / %d) -> %f -> %@", xImg, yImg, origVal, (retVal)?@"true":@"false");
  
  return retVal;
}

-(void) addValue:(float)val toXPlus:(int)diff_val x:(int)x y:(int)y {
  for(int xpos = x - diff_val; xpos <= x + diff_val; xpos++) {
    if(xpos >= 0) {
      for(int ypos = y - diff_val; ypos <= y + diff_val; ypos++) {
        if(ypos >= 0) {
          if(xpos == x && ypos == y)
            continue;
          
          float origVal = [self matrixValueAtX:xpos y:ypos];
          if(origVal < DITHER_MAX_TRESHOLD) {
            origVal += (DITHER_MAX_TRESHOLD / (ABS(xpos - x) + ABS(ypos - y))) + val;
          } else {
            origVal = (origVal + val) * DITHER_VALUE_ADD_FAKTOR;
          }
          [self setMatrixValueAtX:xpos y:ypos to:origVal];
        }
      }
    }
  }
}

-(float) ease:(float)stepSum{
  //  e^(-(x/.006)^2)/33.3
  return expf(-powf(2, (stepSum/(self.stepsize*3))))/33.3f;
}

-(void) drawMatrixInRect:(NSRect) rect {
  
  float cellWidth = 1;
  float cellHeight = 1;
  
  for(int x = 0; x < self.width; x++) {
    for(int y = 0; y < self.height; y++) {
      float val = [self matrixValueAtX:x y:y];
      
      //rotate x/y by 90°
      int xx = y * -1 + self.width;
      int yy = x;
      
      if(val > 0) {
        [[NSColor colorWithRed:1.0 green:0 blue:0 alpha:val] set];
        NSRectFill(NSMakeRect(cellWidth * yy,cellHeight * xx, cellWidth, cellHeight));
      }
//      else {
//        [[NSColor colorWithRed:0.0 green:0 blue:0 alpha:1.0] set];
//        NSRectFill(NSMakeRect(cellWidth * yy,cellHeight * xx, cellWidth, cellHeight));
//      }
    }
  }
}

/* optional method to show current state */
- (void) visualizeInRect:(NSRect)rect {
  [self.behaviour visualizeInRect:rect];
  if(self.showArray)
    [self drawMatrixInRect: rect];
}

- (int) getMatrixPositionFor:(float) val {
  int ret = (val + self.coordMove) / self.stepsize;
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
