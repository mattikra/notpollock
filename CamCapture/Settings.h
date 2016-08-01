//
//  Settings.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define BEHAVIOUR_CLASS SimplePollockBehaviour
#define BEHAVIOUR_HEADER "SimplePollockBehaviour.h"

//tracking parameters
#define THRESHOLD_PERCENT 80 /* threshold with x percent of brightest pixel */
#define WINDOW_MIN 2         /* minimum valid BBOX size for each segment */
#define WINDOW_MAX 15         /* maximum valid BBOX size for each segment */
#define MAX_RAW_SEGMENTS 10000 /* maximum number of unfiltered segments (any size) */
#define MIN_SEGMENTS 3      /* minimum number of segments */
#define MAX_SEGMENTS 20      /* maximum number of segments */
#define MIN_RADIUS 10
#define MAX_RADIUS 100
#define MIN_CIRCLES 1

#define CAN_HEIGHT 1         /* can height above canvas */
#define VALVE_LATENCY 0.15   /* valve release latency (e.g. BLE / physical) */
#define TEMPLATE_SCALE 0.5   /* target scale */
