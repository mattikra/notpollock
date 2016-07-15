//
//  Settings.h
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define DITHER_CLASS DitheredPollockBehaviour
#define DITHER_HEADER "DitheredPollockBehaviour.h"

#define BEHAVIOUR_CLASS SimplePollockBehaviour
#define BEHAVIOUR_HEADER "SimplePollockBehaviour.h"

//tracking parameters
#define THRESHOLD_PERCENT 90 /* threshold with x percent of brightest pixel */
#define WINDOW_MIN 3         /* minimum valid BBOX size */
#define WINDOW_MAX 20        /* maximum valid BBOX size */

#define CAN_HEIGHT 1         /* can height above canvas */
#define VALVE_LATENCY 0.15   /* valve release latency (e.g. BLE / physical) */
#define TEMPLATE_SCALE 0.5   /* target scale */

/* DITHERING */

#define DITHER_MATRIX_HEIGHT 100   /* Dithering Matrix height */
#define DITHER_MATRIX_WIDTH 100    /* Dithering Matrix height */
#define DITHER_GRID_MAX_VALUE 1.0   /* Max value to build the grid */
#define DITHER_GRID_MIN_VALUE -1.0  /* Min value to build the grid */

#define DITHER_VALUE_ADD 0.3             /* Value to add to a field */
#define DITHER_MAX_TRESHOLD 1.0     /* if x >= value is reached do not fire/open */
