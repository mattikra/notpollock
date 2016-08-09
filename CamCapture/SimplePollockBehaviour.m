//
//  SimplePollockBehaviour.m
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "SimplePollockBehaviour.h"
#import "Settings.h"


@interface SimplePollockBehaviour () {
    double quadXCoeffs[3];    //only for viz
    double quadYCoeffs[3];    //only for viz
}

@property (strong) NSMutableDictionary<NSDate*,NSValue*>* lastTrackPoints;
@property (strong) NSBitmapImageRep* template;
@property (assign) BOOL wasOpen;                   //only for viz
@property (assign) NSPoint lastProjectionPoint;    //only for viz



/** do a quadratic least squares fit with given samples. coeffs are returned as y = c2*x*x + c1*x + c0 */
- (BOOL) lsQuadraticFitForSampleCount:(int)numSamples x:(double[])xx y:(double[])yy out:(double[])coeffs;

@end

@implementation SimplePollockBehaviour

//PollockBehaviour properties
@synthesize idlePoint;     //tracked center point when pendulum is idle
@synthesize idleHeight;    //height above canvas in m when pendulum is idle
@synthesize releaseDelay;  //drop release latency in s

- (id) initWithTemplateURL:(NSURL*)url {
    self = [super init];
    if (self) {
        self.lastTrackPoints = [NSMutableDictionary dictionary];
        bzero(quadXCoeffs,sizeof(quadXCoeffs));
        bzero(quadYCoeffs,sizeof(quadYCoeffs));
        self.template = (NSBitmapImageRep*)[NSImageRep imageRepWithContentsOfURL:url];
        self.wasOpen = NO;
        self.idlePoint = NSMakePoint(0,0);
        self.idleHeight = 1.0;
        self.releaseDelay = 0.15;
    }
    return self;
}

- (BOOL) shouldOpenWithTrackResult:(BOOL)tracked position:(NSPoint)position at:(NSDate*)time canOpen:(BOOL)canOpen outPos:(NSPoint *)out_projectionPoint {
    self.wasOpen = NO;
    
    //collect last MIN_TRACK_SEQUENCE samples
    
    if (tracked) {
        [self.lastTrackPoints setObject:[NSValue valueWithPoint:position]
                                 forKey:time];
    } else {
        [self.lastTrackPoints removeAllObjects];
    }
    if (self.lastTrackPoints.count < MIN_TRACK_SEQUENCE) {
        return NO;
    }
    while (self.lastTrackPoints.count > MIN_TRACK_SEQUENCE) {
        NSDate* oldest = [self.lastTrackPoints.allKeys sortedArrayUsingSelector:@selector(compare:)][0];
        [self.lastTrackPoints removeObjectForKey:oldest];
    }
    /* We should have MIN_TRACK_SEQUENCE points here
     Use now as time base, find best quadratic spline fit using
     least squares. Quadratic splines are not correct, but should be good enough for
     small segments. Mainly used for jitter smoothing. */
    
    NSTimeInterval now = time.timeIntervalSinceReferenceDate;
    double times[MIN_TRACK_SEQUENCE];
    double xx[MIN_TRACK_SEQUENCE];
    double yy[MIN_TRACK_SEQUENCE];
    int idx = 0;
    for (NSDate* date in self.lastTrackPoints.allKeys) {
        NSPoint pt = [self.lastTrackPoints[date] pointValue];
        times[idx] = date.timeIntervalSinceReferenceDate - now;
        xx[idx] = pt.x;
        yy[idx] = pt.y;
        idx++;
    }
    
    //motion estimation: fill projectionPoint
    NSPoint projectionPoint = NSMakePoint(0,0);
    
#if defined ESTIMATE_QUADRATIC
    //estimate motion path
    BOOL ok = [self lsQuadraticFitForSampleCount:MIN_TRACK_SEQUENCE x:times y:xx out:quadXCoeffs];
    if (!ok) {
        return NO;
    }
    ok = [self lsQuadraticFitForSampleCount:MIN_TRACK_SEQUENCE x:times y:yy out:quadYCoeffs];
    if (!ok) {
        return NO;
    }
    //do our drip prediction
    
    //point where the can would actually release paint if we trigger open now (RF / mechanical delay)
    NSPoint releasePoint = NSMakePoint(
        quadXCoeffs[2]*self.releaseDelay*self.releaseDelay + quadXCoeffs[1]*self.releaseDelay + quadXCoeffs[0],
        quadYCoeffs[2]*self.releaseDelay*self.releaseDelay + quadYCoeffs[1]*self.releaseDelay + quadYCoeffs[0]
    );
    //motion vector of can at actual release point (derivative at release point)
    NSPoint releaseMotion = NSMakePoint(
        2.0*quadXCoeffs[2] * self.releaseDelay + quadXCoeffs[1],
        2.0*quadYCoeffs[2] * self.releaseDelay + quadYCoeffs[1]
    );
    //point where paint would land
    double fallTime = sqrt(2.0 * self.idleHeight / 9.81);
    projectionPoint = NSMakePoint(
        releasePoint.x + fallTime * releaseMotion.x,
        releasePoint.y + fallTime * releaseMotion.y
    );
    
#elif defined (ESTIMATE_SINUSOIDAL)
    //TODO ***********************
    
#else
#error ("No path estimation method defined")
#endif

    //check if we're in the region where we should paint at all
    if ((projectionPoint.x < -1.0) || (projectionPoint.x > 1.0) ||
        (projectionPoint.y < -1.0) || (projectionPoint.y > 1.0)) {
        return NO;
    }

    self.lastProjectionPoint = projectionPoint;
    *out_projectionPoint = projectionPoint;

    //look up in template bitmap
    int lookX = (int)(((projectionPoint.x) / 2.0 + 0.5) * self.template.pixelsWide);
    int lookY = (int)(((projectionPoint.y) / 2.0 + 0.5) * self.template.pixelsHigh);
//    NSLog(@"mapping %f %f to %i %i",projectionPoint.x, projectionPoint.y, lookX, lookY);
  
    NSColor* color = [self.template colorAtX:lookX y:lookY];
    BOOL open = [color brightnessComponent] < 0.5;
    self.wasOpen = open;
    
    return open && canOpen;
}


- (BOOL) lsQuadraticFitForSampleCount:(int)numSamples x:(double[])xx y:(double[])yy out:(double[])coeffs {
    //Least squares fitting of a quadratic curve into a sample set
    double sumX    = 0;
    double sumXX   = 0;
    double sumXXX  = 0;
    double sumXXXX = 0;
    double sumY    = 0;
    double sumXY   = 0;
    double sumXXY  = 0;
    for (int i=0; i<numSamples; i++) {
        double x = xx[i];
        double y = yy[i];
        sumX    += x;
        sumXX   += x*x;
        sumXXX  += x*x*x;
        sumXXXX += x*x*x*x;
        sumY    += y;
        sumXY   += x*y;
        sumXXY  += x*x*y;
    }
    
    double denom = (numSamples*sumXX*sumXXXX - sumX*sumX*sumXXXX - numSamples*sumXXX*sumXXX + 2*sumX*sumXX*sumXXX - sumXX*sumXX*sumXX);
    if (denom == 0.0) {
        return NO;
    }
    double a = (sumY*sumX*sumXXX - sumXY*numSamples*sumXXX - sumY*sumXX*sumXX
                + sumXY*sumX*sumXX + sumXXY*numSamples*sumXX - sumXXY*sumX*sumX) / denom;
    
    double b = (sumXY*numSamples*sumXXXX - sumY*sumX*sumXXXX + sumY*sumXX*sumXXX
                - sumXXY*numSamples*sumXXX - sumXY*sumXX*sumXX + sumXXY*sumX*sumXX) / denom;
    
    double c = (sumY*sumXX*sumXXXX - sumXY*sumX*sumXXXX - sumY*sumXXX*sumXXX
                + sumXY*sumXX*sumXXX + sumXXY*sumX*sumXXX - sumXXY*sumXX*sumXX) / denom;

    if (coeffs) {
        coeffs[2] = a;
        coeffs[1] = b;
        coeffs[0] = c;
    }
    return YES;
}

- (void) visualizeInRect:(NSRect)rect {
    
    NSRect templateRect = NSMakeRect(-1,-1,2,2);
    
    [self.template drawInRect:templateRect
                     fromRect:NSMakeRect(0,0,self.template.pixelsWide,self.template.pixelsHigh)
                    operation:NSCompositeMultiply
                     fraction:0.5
               respectFlipped:YES
                        hints:NULL];

//    NSBezierPath* path = [NSBezierPath bezierPath];
//    NSArray* dates = [self.lastTrackPoints.allKeys sortedArrayUsingSelector:@selector(compare:)];
//    BOOL first = YES;
//    for (NSDate* date in dates) {
//        NSPoint pt = [self.lastTrackPoints[date] pointValue];
//        double x = pt.x * scale + (width/2.0);
//        double y = pt.y * scale + (height/2.0);
//        pt = NSMakePoint(x,height-y);
//        if (first) {
//            [path moveToPoint:pt];
//            first = NO;
//        } else {
//            [path lineToPoint:pt];
//        }
//    }

    NSBezierPath* path = [NSBezierPath bezierPath];
    for (double t=-1.0; t < 1.0; t+= 0.1) {
        double x = (quadXCoeffs[2]*t*t + quadXCoeffs[1]*t + quadXCoeffs[0]);
        double y = (quadYCoeffs[2]*t*t + quadYCoeffs[1]*t + quadYCoeffs[0]);
        NSPoint pt = NSMakePoint(x,y);
        if (t == -1.0) {
            [path moveToPoint:pt];
        } else {
            [path lineToPoint:pt];
        }
    }
    path.lineWidth = 0.01;
    [[NSColor greenColor] set];
    [path stroke];
    
    [(self.wasOpen ? [NSColor greenColor] : [NSColor redColor]) set];
    [NSBezierPath fillRect:NSMakeRect(self.lastProjectionPoint.x,
                                      self.lastProjectionPoint.y,
                                      0.05, 0.05)];
}

@end
