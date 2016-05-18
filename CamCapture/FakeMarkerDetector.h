//
//  FakeMarkerDetector.h
//  CamCapture
//
//  Created by Matthias Krauß on 16.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* does fake marker detection for testing */
@interface FakeMarkerDetector : NSObject

/*
 detect the marker. Returns YES if marker was detected. In this case, the output position is
 returned in outPt (if non-NULL). Position origin is image center, normalized in (-1,1) along major axis */

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame outPosition:(NSPoint*)pt;

@end

