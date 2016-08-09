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

#define TEMPLATE_NAME @"Slice"

//tracking parameters
#define THRESHOLD_PERCENT 90 /* threshold with x percent of brightest pixel */
#define WINDOW_MIN 50         /* minimum valid BBOX size */
#define WINDOW_MAX 160        /* maximum valid BBOX size */
#define SHOW_ROI YES
#define SHOW_THRES YES

//path estimation properties
#define MIN_TRACK_SEQUENCE 10
#define ESTIMATE_QUADRATIC YES
//#define ESTIMATE_SINUSOIDAL YES

//latencies / physical properties
#define PENDULUM_LENGTH 1.95  /* length of pendulum in m */
#define CAN_HEIGHT 1.0        /* can height above canvas in m */
#define CANVAS_SIZE_M 1.4     /* canvas size (one edge of square) in m */
#define VALVE_LATENCY 0.3     /* valve release latency in s (e.g. BLE / physical) */
#define TEMPLATE_SCALE 0.5    /* target scale */
#define VALVE_ON_TIME_S 0.1   /* valve on time in s */
#define DROP_DEAD_TIME_S 1.0  /* dead time after each drop in s */


/* DITHERING */

#define DITHER_MATRIX_HEIGHT 750   /* Dithering Matrix height */
#define DITHER_MATRIX_WIDTH 750    /* Dithering Matrix height */
#define DITHER_GRID_MAX_VALUE 1.0   /* Max value to build the grid */
#define DITHER_GRID_MIN_VALUE -1.0  /* Min value to build the grid */

#define DITHER_VALUE_ADD 0.3             /* Value to add to a field */
#define DITHER_MAX_TRESHOLD 1.0     /* if x >= value is reached do not fire/open */
