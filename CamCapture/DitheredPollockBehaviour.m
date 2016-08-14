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
//    self.stepsize = floorf(self.stepsize * ROUND_VAL) / ROUND_VAL;
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
    
    int xImg = [self getMatrixPositionFor:point.x];
    int yImg = [self getMatrixPositionFor:point.y];
    float origVal = [self matrixValueAtX:xImg y:yImg];
    
    BOOL retVal = (origVal < 1.0);
    NSLog(@"drop blocked due to dither: %i",retVal);
    if (retVal) {
        [self drawBlobAtX:xImg Y:yImg radius:DITHER_RADIUS height:pow(2,DITHER_DEAD_TIME_MIN)];
    }

  return retVal;
}

- (void) regularService {
    [self decayArray];
    [self decayArray];
    [self decayArray];
}

- (void)drawBlobAtX:(int)x Y:(int)y radius:(int)rad height:(float)height {
    int minx = MAX(0, x-rad);
    int miny = MAX(0, y-rad);
    int maxx = MIN(self.width-1, x+rad);
    int maxy = MIN(self.height-1, y+rad);
    for (int yy=miny; yy<=maxy; yy++) {
        for (int xx=minx; xx<=maxx; xx++) {
            float dist = sqrt((xx-x)*(xx-x) + (yy-y)*(yy-y));
            float ease = height * [self ease:dist / rad];
            float val = [self matrixValueAtX:xx y:yy];
            val += ease;
            [self setMatrixValueAtX:xx y:xx to:val];
        }
    }
}

- (void)decayArray {
    //array should half its values about once per minute
    static int currentRow = 0;
    static float decayFactor = 1;
    currentRow = (currentRow+1) % self.height;
    if (currentRow == 0) {
        NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
        static NSTimeInterval lastTime = 0;
        if (lastTime > 0) {
            double timeDiff = now - lastTime;   //last full scan pass duration in s
            decayFactor = pow (0.5, timeDiff / 60.0);
            NSLog(@"array decay %f",decayFactor);

        }
        lastTime = now;
    }
    for (int x=0; x<self.width; x++) {
        [self setMatrixValueAtX:x y:currentRow to:[self matrixValueAtX:x y:currentRow] * decayFactor];
    }
}

-(float) ease:(float)stepSum{
  //  e^(-(x/.006)^2)/33.3
  return expf(-powf( (stepSum/(self.stepsize*3)), 2.0)) / 33.3f;
}

-(void) drawMatrixInRect:(NSRect) rect {
  
  float cellWidth = 2;
  float cellHeight = 2;
  
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
