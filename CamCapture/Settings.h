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

#define TEMPLATE_NAME @"ernst1"

//tracking parameters
#define THRESHOLD_PERCENT 61.6 /* threshold with x percent of brightest pixel */
#define WINDOW_MIN 10          /* minimum valid BBOX size */
#define WINDOW_MAX 50          /* maximum valid BBOX size */
#define SHOW_ROI YES
#define SHOW_THRES YES
#define ROI_SIZE 0.439

//path estimation properties
#define MIN_TRACK_SEQUENCE 20
//#define ESTIMATE_QUADRATIC YES
#define ESTIMATE_SINUSOIDAL YES

//latencies / physical properties
#define PENDULUM_LENGTH 4.81  /* length of pendulum in m */
#define CAN_HEIGHT 0.07       /* can height above canvas in m */
#define CANVAS_SIZE_M 2.72    /* canvas size (one edge of square) in m */
#define VALVE_LATENCY 0.185   /* valve release latency in s (e.g. BLE / physical) */
#define VALVE_ON_TIME_S 0.066 /* valve on time in s */
#define DROP_DEAD_TIME_S 0.5  /* dead time after each drop in s */

/* DITHERING */

#define DITHER_MATRIX_HEIGHT 400    /* Dithering Matrix height */
#define DITHER_MATRIX_WIDTH 400     /* Dithering Matrix height */
#define DITHER_GRID_MAX_VALUE 1.0   /* Max value to build the grid */
#define DITHER_GRID_MIN_VALUE -1.0  /* Min value to build the grid */

#define DITHER_MAX_TRESHOLD 1.0          /* if x >= value is reached do not fire/open */

#define DITHER_RADIUS 8
#define DITHER_DEAD_TIME_MIN 1