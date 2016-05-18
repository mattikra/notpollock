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

/*
 detect the marker. Returns YES if marker was detected. In this case, the output position is
 returned in outPt (if non-NULL). Position origin is image center, normalized in (-1,1) along major axis */

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame outPosition:(NSPoint*)pt;

@end
