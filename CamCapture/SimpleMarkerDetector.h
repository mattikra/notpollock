//
//  MarkerDetector.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MarkerDetector.h"

//simple CV tracker for detecting a bright marker on dark background. We assume ARGB8888, packed

@interface SimpleMarkerDetector : NSObject <MarkerDetector>

@end
