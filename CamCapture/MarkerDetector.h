//
//  MarkerDetector.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//simple CV tracker for detecting a bright marker on dark background. We assume ARGB8888, packed

@interface MarkerDetector : NSObject

@property (assign) NSPoint lastRawPoint;

/*
 detect the marker. Returns YES if marker was detected. In this case, the output position is
 returned in outPt (if non-NULL). ROI is in image pixels, can be assumed to lie entirely inside image
 Position is normalized in (-1,1) for ROI */

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame
                     roiMinX:(int)roiMinX
                     roiMaxX:(int)roiMaxX
                     roiMinY:(int)roiMinY
                     roiMaxY:(int)roiMaxY
                        sens:(double)sens
                 outPosition:(NSPoint*)pt;

@end
