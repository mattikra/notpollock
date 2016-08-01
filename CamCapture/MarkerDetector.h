//
//  PollockBehaviour.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//


#import <Cocoa/Cocoa.h>


/*Base protocol for a marker detector */

@protocol MarkerDetector <NSObject>

@required

/* detect a marker in an image. Returns YES if marker was detected. In this case, the output position is
 returned in outPt (if non-NULL). Position origin is image center, normalized in (-1,1) along major axis */
- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame outPosition:(NSPoint*)pt;

@end

