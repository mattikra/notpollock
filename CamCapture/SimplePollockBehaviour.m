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
    double sinXCoeffs[3];    //only for viz
    double sinYCoeffs[3];    //only for viz
    
}

@property (strong) NSMutableDictionary<NSDate*,NSValue*>* lastTrackPoints;
@property (strong) NSBitmapImageRep* template;
@property (assign) BOOL wasOpen;                   //only for viz
@property (assign) NSPoint lastProjectionPoint;    //only for viz



/** do a quadratic least squares fit with given samples. coeffs are returned as y = c2*x*x + c1*x + c0 */
- (BOOL) lsQuadraticFitForSampleCount:(int)numSamples x:(double[])xx y:(double[])yy out:(double[])coeffs;

/** do a sinusoidal least squares fit with given samples, fixed center at origin (no offset), fixed frequency (one full oscillation in period s). coeffs are returned as y = c0*sin(x) + c1*cos(x) */
- (BOOL) lsSinusoidalFitForSampleCount:(int)numSamples period:(double)period x:(double[])xx y:(double[])yy out:(double[])coeffs;


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
        bzero(sinXCoeffs,sizeof(sinXCoeffs));
        bzero(sinYCoeffs,sizeof(sinYCoeffs));
        self.template = (NSBitmapImageRep*)[NSImageRep imageRepWithContentsOfURL:url];
        self.wasOpen = NO;
        self.idlePoint = NSMakePoint(0,0);
        self.idleHeight = CAN_HEIGHT;
        self.releaseDelay = VALVE_LATENCY;
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
    double displacementH = 0.5 * CANVAS_SIZE_M * sqrt(releasePoint.x * releasePoint.x + releasePoint.y * releasePoint.y);
    double displacementV = PENDULUM_LENGTH - sqrt(PENDULUM_LENGTH*PENDULUM_LENGTH - displacementH*displacementH);
    double fallHeight = self.idleHeight + displacementV;
    double fallTime = sqrt(2.0 * fallHeight / 9.81);
    projectionPoint = NSMakePoint(
                                  releasePoint.x + fallTime * releaseMotion.x,
                                  releasePoint.y + fallTime * releaseMotion.y
                                  );
    
#elif defined (ESTIMATE_SINUSOIDAL)
    double gravity = 9.81;
    double period = 2.0 * M_PI * sqrt(PENDULUM_LENGTH / gravity);
    double tFactor = 2.0 * M_PI / period;
    //estimate motion path
    BOOL ok = [self lsSinusoidalFitForSampleCount:MIN_TRACK_SEQUENCE period:period x:times y:xx out:sinXCoeffs];
    if (!ok) {
        return NO;
    }
    ok = [self lsSinusoidalFitForSampleCount:MIN_TRACK_SEQUENCE period:period x:times y:yy out:sinYCoeffs];
    if (!ok) {
        return NO;
    }
    //do our drip prediction
    
    //point where the can would actually release paint if we trigger open now (RF / mechanical delay)
    double releaseT = self.releaseDelay * tFactor;
    NSPoint releasePoint = NSMakePoint(sinXCoeffs[0] * sin(releaseT) + sinXCoeffs[1]*cos(releaseT),
                                       sinYCoeffs[0] * sin(releaseT) + sinYCoeffs[1]*cos(releaseT));

    //motion vector of can at actual release point (derivative at release point)
    NSPoint releaseMotion = NSMakePoint(sinXCoeffs[0] * cos(releaseT) - sinXCoeffs[1]*sin(releaseT),
                                        sinYCoeffs[0] * cos(releaseT) - sinYCoeffs[1]*sin(releaseT));
    //can displacement from idle position
    double displacementH = 0.5 * CANVAS_SIZE_M * sqrt(releasePoint.x * releasePoint.x + releasePoint.y * releasePoint.y);
    double displacementV = PENDULUM_LENGTH - sqrt(PENDULUM_LENGTH*PENDULUM_LENGTH - displacementH*displacementH);
    double fallHeight = self.idleHeight + displacementV;
    double fallTime = sqrt(2.0 * fallHeight / 9.81);
    projectionPoint = NSMakePoint(
                                  releasePoint.x + fallTime * releaseMotion.x,
                                  releasePoint.y + fallTime * releaseMotion.y
                                  );
    
    
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

- (BOOL) lsSinusoidalFitForSampleCount:(int)numSamples period:(double)period x:(double[])xx y:(double[])yy out:(double[])coeffs {
    //Least squares fitting of a sinusoidal curve
    double tFactor = 2.0*M_PI / period;
    double sumSS   = 0;
    double sumSC   = 0;
    double sumCC   = 0;
    double sumSY   = 0;
    double sumCY   = 0;
    //see calculation at end of file

    for (int i=0; i<numSamples; i++) {
        double t = xx[i] * tFactor;
        double y = yy[i];
        double s = sin(t);
        double c = cos(t);
        sumSS   += s * s;
        sumSC   += s * c;
        sumCC   += c * c;
        sumSY   += s * y;
        sumCY   += c * y;
    }
    if (sumCC == 0.0) {
        return NO;
    }
    if ((sumSS - sumSC*sumSC/sumCC) == 0.0) {
        return NO;
    }
    double a = (sumSY - sumCY*sumSC/sumCC) / (sumSS - sumSC*sumSC/sumCC);
    double b = (sumCY - sumSC*a) / sumCC;
    coeffs[0] = a;
    coeffs[1] = b;
    return YES;
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

    NSBezierPath* path = nil;
    NSArray<NSDate*>* dates = [self.lastTrackPoints.allKeys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [a compare:b];
    }];
    for (NSDate* date in dates) {
        NSPoint pt = [[self.lastTrackPoints objectForKey:date] pointValue];
        if (path) {
            [path lineToPoint:pt];
        } else {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:pt];
        }
    }
    path.lineWidth = 0.01;
    [[NSColor yellowColor] set];
    [path stroke];

    
#if defined ESTIMATE_QUADRATIC

    path = [NSBezierPath bezierPath];
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

#elif defined ESTIMATE_SINUSOIDAL
    
    double gravity = 9.81;
    double period = 2.0 * M_PI * sqrt(PENDULUM_LENGTH / gravity);
    double tFactor = 2.0 * M_PI / period;

    path = [NSBezierPath bezierPath];
    for (double t=-1.0; t < 1.0; t+= 0.1) {
        double x = (sinXCoeffs[0]*sin(t*tFactor) + sinXCoeffs[1]*cos(t*tFactor));
        double y = (sinYCoeffs[0]*sin(t*tFactor) + sinYCoeffs[1]*cos(t*tFactor));
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
    
#endif
    
    [(self.wasOpen ? [NSColor greenColor] : [NSColor redColor]) set];
    [NSBezierPath fillRect:NSMakeRect(self.lastProjectionPoint.x - 0.025,
                                      self.lastProjectionPoint.y - 0.025,
                                      0.05, 0.05)];
}

@end

/* sinusoidal approximation using LSQ:
 
 f(t) = a * sin(t) + b * cos(t)
 
 (scale t to period -> 2*PI)
 
 e(t) = SUM(i=0..n)( (f(ti) - yi)^2 )
 e(t) = SUM(i=0..n)( (a*sin(ti) + b*cos(ti) - yi)^2 )
 
 
 (a*sin(ti) + b*cos(ti) - yi)^2
 = (a*sin(ti) + b*cos(ti) - yi) * (a*sin(ti) + b*cos(ti) - yi)
 = a^2*sin(ti)^2 + b^2*cos(ti)^2 + yi^2 + 2*a*b*sin(ti)cos(ti) - 2*a*sin(ti)*yi  - 2*b*cos(ti)*yi
 
 
 e(t) = SUM(i=0..n)( a^2*sin(ti)^2 + b^2*cos(ti)^2 + yi^2 + 2*a*b*sin(ti)cos(ti) - 2*a*sin(ti)*yi  - 2*b*cos(ti)*yi )
 
 e'(t)da = SUM(i=0..n)( 2*a*sin(ti)^2 + 2*b*sin(ti)cos(ti) - 2*sin(ti)*yi) = 0
 e'(t)db = SUM(i=0..n)( 2*b*cos(ti)^2 + 2*a*sin(ti)cos(ti) - 2*cos(ti)*yi) = 0
 
 SUM(i=0..n)( a*sin(ti)^2 + b*sin(ti)cos(ti) - sin(ti)*yi) = 0
 SUM(i=0..n)( b*cos(ti)^2 + a*sin(ti)cos(ti) - cos(ti)*yi) = 0
 
 ss = SUM(i=0..n) ( sin(ti)^2 )
 cc = SUM(i=0..n) ( cos(ti)^2 )
 sc = SUM(i=0..n) ( sin(ti)*cos(ti) )
 sy = SUM(i=0..n) ( sin(ti)*yi )
 cy = SUM(i=0..n) ( cos(ti)*yi )

 (1) ss*a + sc*b - sy = 0
 (2) cc*b + sc*a - cy = 0
 
 (2) -> cc*b = cy - sc*a
 b = (cy - sc*a) / cc
 
 (1) -> ss*a + sc*(cy - sc*a)/cc - sy = 0
 ss*a + (cy - sc*a)*sc/cc - sy = 0
 ss*a + cy*sc/cc - sc*a*sc/cc - sy = 0
 a*ss - a*sc*sc/cc + cy*sc/cc - sy = 0
 a*(ss - sc*sc/cc) = sy - cy*sc/cc
 a = (sy - cy*sc/cc) / (ss - sc*sc/cc)
 
 b = (cy - sc*a) / cc
 
*/
