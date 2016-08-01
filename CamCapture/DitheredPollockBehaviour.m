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
@synthesize releaseDelay;  //drop release latency in s
@synthesize templateScale; //arbitrary scale factor (0..1) - use full tracking range for 1
@synthesize showArray;

/* initialize with a given template image URL */
- (id) initWithTemplateURL:(NSURL*)url {
  self = [super init];
  if (self) {
    
    self.showArray = true;
    
    self.width = DITHER_MATRIX_WIDTH;
    self.height = DITHER_MATRIX_HEIGHT;
    self.matrixData = [NSMutableData dataWithLength:sizeof(float) * self.width * self.height];
    self.stepsize = (ABS(DITHER_GRID_MAX_VALUE) + ABS(DITHER_GRID_MIN_VALUE)) / ABS(MAX(DITHER_MATRIX_WIDTH, DITHER_MATRIX_HEIGHT));  // calculate the step size for our matrix
    float max_val = MAX(ABS(DITHER_GRID_MIN_VALUE), ABS(DITHER_GRID_MAX_VALUE));
    self.coordMove = 0;
    self.coordMove = ABS(max_val);
    
    NSLog(@"matrix: %d x %d, step size: %f, coord move: %f", self.width, self.height, self.stepsize, self.coordMove);

    
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
  
//  NSLog(@"%f x %f -> %d x %d", point.x + 1, point.y + 1, xImg, yImg);
  
  float origVal = [self matrixValueAtX:xImg y:yImg];
  
  if(origVal > DITHER_MAX_TRESHOLD) {
    retVal = false;
  } else {
    
    float newVal = origVal + DITHER_VALUE_ADD;
    [self setMatrixValueAtX:xImg y:yImg to:newVal];
    
    // calculate neigbours
    for(int x = 1; x <= 2; x++) {
      float addFieldValue = [self ease:self.stepsize * x];
      
      switch (x) {
        case 1:
          [self addValueToXPlusOne:addFieldValue x:xImg y:yImg];
          break;
        case 2:
          [self addValueToXPlusTwo:addFieldValue x:xImg y:yImg];
          break;
        default:
          break;
      }
    }
    
    
//    if(newVal > 0) {
//      NSLog(@"point(%d, %d): orig: %f new: %f", xImg, yImg, origVal, newVal);
//    }
    
    retVal = true;
  }
  
  return retVal;
}

-(void) addValueToXPlusOne:(float)val x:(int)x y:(int)y {
  
  // (-1/0)
  if(x-1 >= 0) {
    float newVal = [self matrixValueAtX:x-1 y:y] + val;
    [self setMatrixValueAtX:x-1 y:y to:newVal];
  }
  
  // (-1/-1)
  if(x-1 >= 0 && y-1 >= 0) {
    float newVal = [self matrixValueAtX:x-1 y:y-1] + val;
    [self setMatrixValueAtX:x-1 y:y-1 to:newVal];
  }
  
  // (-1/1)
  if(x-1 >= 0 && y+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x-1 y:y+1] + val;
    [self setMatrixValueAtX:x-1 y:y+1 to:newVal];
  }
  
  // (0/1)
  if(y+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x y:y+1] + val;
    [self setMatrixValueAtX:x y:y+1 to:newVal];
  }
  
  // (0/-1)
  if(y-1 >= 0) {
    float newVal = [self matrixValueAtX:x y:y-1] + val;
    [self setMatrixValueAtX:x y:y-1 to:newVal];
  }
  
  // (1/1)
  if(x+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))
     && y+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x+1 y:y+1] + val;
    [self setMatrixValueAtX:x+1 y:y+1 to:newVal];
  }
  
  // (1/0)
  if(x+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x+1 y:y] + val;
    [self setMatrixValueAtX:x+1 y:y to:newVal];
  }
  
  // (1/-1)
  if(x+1 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT)) && y-1 >= 0) {
    float newVal = [self matrixValueAtX:x+1 y:y-1] + val;
    [self setMatrixValueAtX:x+1 y:y-1 to:newVal];
  }
  
}

-(void) addValueToXPlusTwo:(float)val x:(int)x y:(int)y{
  
  // (-2/0)
  if(x-2 >= 0) {
    float newVal = [self matrixValueAtX:x-2 y:y] + val;
    [self setMatrixValueAtX:x-2 y:y to:newVal];
  }
  
  // (0/2)
  if(y+2 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x y:y+2] + val;
    [self setMatrixValueAtX:x y:y+2 to:newVal];
  }
  
  // (0/-2)
  if(y-2 >= 0) {
    float newVal = [self matrixValueAtX:x y:y-2] + val;
    [self setMatrixValueAtX:x y:y-2 to:newVal];
  }
  
  // (2/0)
  if(x+2 <= MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT))) {
    float newVal = [self matrixValueAtX:x+2 y:y] + val;
    [self setMatrixValueAtX:x+2 y:y to:newVal];
  }
  
}

-(float) ease:(float)stepSum{
  //  e^(-(x/.006)^2)/33.3
  return expf(-powf(2, (stepSum/(self.stepsize*3))))/33.3f;
}

-(void) drawMatrixInRect:(NSRect) rect {
  
  float minCells = MIN(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT));
  float maxCells = MAX(ABS(DITHER_MATRIX_WIDTH), ABS(DITHER_MATRIX_HEIGHT));
  float minSide = MIN(rect.size.width, rect.size.height);
  float maxSide = MAX(rect.size.width, rect.size.height);
  
  float cellWidth = maxSide / maxCells;
  float cellHeight = minSide / minCells;
  
  for(int x = 0; x < maxCells; x++) {
    for(int y = 0; y < minCells; y++) {
      float val = [self matrixValueAtX:x y:y];
      if(val > 0) {
        [[NSColor colorWithRed:1.0 green:0 blue:0 alpha:val] set];
        NSRectFill(NSMakeRect(cellWidth * x,cellHeight * y, cellWidth, cellHeight));
      }
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
