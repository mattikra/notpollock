//
//  MarkerDetector.m
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "MarkerDetector.h"
#import "Settings.h"

@implementation MarkerDetector

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame
                     roiMinX:(int)roiMinX
                     roiMaxX:(int)roiMaxX
                     roiMinY:(int)roiMinY
                     roiMaxY:(int)roiMaxY
                        sens:(double)sens
                 outPosition:(NSPoint*)pt {
    
    uint8_t* irBase = [frame bitmapData];
    int width = (int)[frame pixelsWide];
    int height = (int)[frame pixelsHigh];
    int bytesPerRow = (int)[frame bytesPerRow];

    
    //detect brightest pixel
    uint16_t maxBrightness = 0;
    for (int y=roiMinY; y<=roiMaxY; y++) {
        for (int x=roiMinX; x<=roiMaxX; x++) {
            uint8_t r = irBase[bytesPerRow*y+4*x+1];
            uint8_t g = irBase[bytesPerRow*y+4*x+2];
            uint8_t b = irBase[bytesPerRow*y+4*x+3];
            uint16_t brightness = r+g+b;
            if (brightness > maxBrightness) {
                maxBrightness = brightness;
            }
        }
    }

    //detect bbox of pixels with at least THRESHOLD_PERCENT of max brightness
    uint16_t thresholdBrightness = (maxBrightness * sens);
    int minX = (int)width;
    int maxX = 0;
    int minY = (int)height;
    int maxY = 0;
    for (int y=roiMinY; y<=roiMaxY; y++) {
        for (int x=roiMinX; x<=roiMaxX; x++) {
            uint8_t r = irBase[bytesPerRow*y+4*x+1];
            uint8_t g = irBase[bytesPerRow*y+4*x+2];
            uint8_t b = irBase[bytesPerRow*y+4*x+3];
            uint16_t brightness = r+g+b;
            if (brightness > thresholdBrightness) {
                if (x > maxX) maxX = x;
                if (x < minX) minX = x;
                if (y > maxY) maxY = y;
                if (y < minY) minY = y;
#ifdef SHOW_THRES
                irBase[bytesPerRow*y+4*x+1] = 255;
                irBase[bytesPerRow*y+4*x+2] = 0;
                irBase[bytesPerRow*y+4*x+3] = 255;
#endif
            }
        }
    }
    int detectW = maxX - minX;
    int detectH = maxY - minY;
//    NSLog(@"window %i %i",detectW, detectH);
    BOOL detect =   (detectW >= WINDOW_MIN) && (detectW <= WINDOW_MAX) &&
                    (detectH >= WINDOW_MIN) && (detectH <= WINDOW_MAX);
    if (detect) {
        self.lastRawPoint = NSMakePoint(
                                        (maxX + minX) / (double)width - 1.0,
                                        (maxY + minY) / (double)height - 1.0
                                        );
    }
    
    if (detect && pt) {
        pt->x = (((0.5 * (maxX + minX)) - roiMinX) / (roiMaxX-roiMinX)) * 2.0 - 1.0;
        pt->y = (((0.5 * (maxY + minY)) - roiMinY) / (roiMaxY-roiMinY)) * 2.0 - 1.0;
    }
    
    return detect;
}

@end
