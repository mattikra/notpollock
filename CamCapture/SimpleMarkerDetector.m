//
//  MarkerDetector.m
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "SimpleMarkerDetector.h"
#import "Settings.h"

@implementation SimpleMarkerDetector

- (BOOL) detectMarkerInFrame:(NSBitmapImageRep*)frame outPosition:(NSPoint*)pt {
    const uint8_t* irBase = [frame bitmapData];
    int width = (int)[frame pixelsWide];
    int height = (int)[frame pixelsHigh];
    int bytesPerRow = (int)[frame bytesPerRow];
    
    //detect brightest pixel
    uint16_t maxBrightness = 0;
    for (int y=0; y<height; y++) {
        for (int x=0; x<width; x++) {
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
    uint16_t thresholdBrightness = (maxBrightness * THRESHOLD_PERCENT) / 100;
    int minX = (int)width;
    int maxX = 0;
    int minY = (int)height;
    int maxY = 0;
    for (int y=0; y<height; y++) {
        for (int x=0; x<width; x++) {
            uint8_t r = irBase[bytesPerRow*y+4*x+1];
            uint8_t g = irBase[bytesPerRow*y+4*x+2];
            uint8_t b = irBase[bytesPerRow*y+4*x+3];
            uint16_t brightness = r+g+b;
            if (brightness > thresholdBrightness) {
                if (x > maxX) maxX = x;
                if (x < minX) minX = x;
                if (y > maxY) maxY = y;
                if (y < minY) minY = y;
            }
        }
    }
    int detectW = maxX - minX;
    int detectH = maxY - minY;
    BOOL detect =   (detectW >= WINDOW_MIN) && (detectW <= WINDOW_MAX) &&
                    (detectH >= WINDOW_MIN) && (detectH <= WINDOW_MAX);

    if (detect && pt) {
        double major = MAX(width, height);
        pt->x = ((maxX + minX) - width) / major;
        pt->y = ((maxY + minY) - height) / major;
    }

    return detect;
}

@end
