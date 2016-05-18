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
#define THRESHOLD_PERCENT 90 /* threshold with x percent of brightest pixel */
#define WINDOW_MIN 3         /* minimum valid BBOX size */
#define WINDOW_MAX 20        /* maximum valid BBOX size */

#define CAN_HEIGHT 1         /* can height above canvas */
#define VALVE_LATENCY 0.15   /* valve release latency (e.g. BLE / physical) */
#define TEMPLATE_SCALE 0.5   /* target scale */
