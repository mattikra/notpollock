//
//  MarkerDetector.m
//  CamCapture
//
//  Created by Matthias Krauß on 15.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "MultipointMarkerDetector.h"
#import "Settings.h"
#include <math.h>

#define SEGMENT_ID 0xffffffff
#define NO_SEGMENT_ID 0xfffffffe

// some basic C-style bitmap and geometry tools


typedef struct SegmentInfo {
    int seedX;			//seedX/Y points to one pixel of that element. -1/-1 means no seed point found
    int seedY;
    int pixelCount;		//number of pixels in that segment
    int minX;			//bounds
    int minY;
    int maxX;
    int maxY;
    double weightX;		//weight point
    double weightY;
} SegmentInfo;

typedef struct Circle {
    double cx;
    double cy;
    double rad;
} Circle;

void seedfill(uint32_t* base, int width, int height, int seedX, int seedY, uint32_t	from, uint32_t to) {
    if (base[width*seedY+seedX] != from) return;
    int minX,maxX;
    for (minX = seedX-1; minX>=0; minX--) {
        if (base[width*seedY+minX] != from) break;
    }
    minX++;
    for (maxX = seedX+1; maxX<width; maxX++) {
        if (base[width*seedY+maxX] != from) break;
    }
    maxX--;
    for (int x = minX; x <= maxX; x++) {
        base[width*seedY+x] = to;
    }
    for (int x = minX; x <= maxX; x++) {
        if (seedY>0) seedfill(base,width,height,x,seedY-1,from,to);
        if (seedY<height-1) seedfill(base,width,height,x,seedY+1,from,to);
    }
}

int segmentize(uint32_t* base, int width, int height, uint32_t segmentColor, uint32_t baseId) {
    uint32_t currId = baseId;
    for (int y=0;y<height;y++) {
        for (int x=0;x<width;x++) {
            uint32_t val = base[width*y+x];
            if (val==segmentColor) {
                seedfill(base,width,height,x,y,segmentColor,currId++);
            }
        }
    }
    return currId;
}

void fillSegmentInfo(uint32_t* base, int width, int height, SegmentInfo* infos, int infoCount) {
    //clear info entries
    for (int i=0;i<infoCount;i++) {
        infos[i].seedX = -1;
        infos[i].seedY = -1;
        infos[i].pixelCount = 0;
        infos[i].minX=-1;
        infos[i].minY=-1;
        infos[i].maxX=-2;
        infos[i].maxY=-2;
        infos[i].weightX = -1;
        infos[i].weightY = -1;
    }
    //collect info
    for (int y=0;y<height;y++) {
        for (int x=0;x<width;x++) {
            uint32_t pixSegId = base[width*y+x];
            if (pixSegId<infoCount) {
                infos[pixSegId].pixelCount++;
                if (infos[pixSegId].pixelCount == 1) { //first pixel of segment
                    infos[pixSegId].seedX = x;
                    infos[pixSegId].seedY = y;
                    infos[pixSegId].minX = x;
                    infos[pixSegId].maxX = x;
                    infos[pixSegId].minY = y;
                    infos[pixSegId].maxY = y;
                    infos[pixSegId].weightX = x;
                    infos[pixSegId].weightY = y;
                } else {
                    if (x<infos[pixSegId].minX) infos[pixSegId].minX = x;
                    if (x>infos[pixSegId].maxX) infos[pixSegId].maxX = x;
                    if (y<infos[pixSegId].minY) infos[pixSegId].minY = y;
                    if (y>infos[pixSegId].maxY) infos[pixSegId].maxY = y;
                    infos[pixSegId].weightX += x;
                    infos[pixSegId].weightY += y;
                }
            }
        }
    }
    //fix info stats
    for (int i=0;i<infoCount;i++) {
        int pixCount = infos[i].pixelCount;
        infos[i].weightX = (pixCount > 0) ? infos[i].weightX / infos[i].pixelCount : 0.0;
        infos[i].weightY = (pixCount > 0) ? infos[i].weightY / infos[i].pixelCount : 0.0;
    }
}

//find line intersection in 2D given start and direction
bool intersectLines(double s1x, double s1y, double d1x, double d1y, double s2x, double s2y, double d2x, double d2y,
                    double* ix, double* iy) {
    //normal form
    double c1 = d1y*s1x + d1x*s1y;
    double c2 = d2y*s2x + d2x*s2y;
    
    float delta = d1y*d2x - d2y*d1x;
    if (delta == 0.0) { //lines parallel
        return false;
    }
    if (ix) {
        *ix = (d2x*c1 - d1x*c2) / delta;
    }
    if (iy) {
        *iy = (d1y*c2 - d2y*c1) / delta;
    }
    return true;
}

double pointDistance(double x1, double y1, double x2, double y2) {
    return sqrt ((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1));
}

bool findCircleFromPoints(double x1, double y1, double x2, double y2, double x3, double y3, Circle* outCircle) {
    Circle c;
    //find lines through midpoints A-B and A-C and perpendicular to triangle edges
    double mid1x = (x1 + x2) / 2.0;
    double mid1y = (y1 + y2) / 2.0;
    double dir1x = (y2-y1);
    double dir1y = (x1-x2);

    double mid2x = (x1 + x3) / 2.0;
    double mid2y = (y1 + y3) / 2.0;
    double dir2x = (y3-y1);
    double dir2y = (x1-x3);

    if (intersectLines(mid1x, mid1y, dir1x, dir1y, mid2x, mid2y, dir2x, dir2y, &(c.cx), &(c.cy))) {
        c.rad = pointDistance(c.cx, c.cy, x1, y1);
        if (outCircle) {
            memcpy(outCircle, &c, sizeof(Circle));
        }
        return true;
    }
    return false;
}

// end C bitmap tools

@implementation MultipointMarkerDetector

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

    //threshold image to workArea
    NSMutableData* workData = [NSMutableData dataWithLength:width*height*sizeof(uint32_t)];
    uint32_t* workArea = [workData mutableBytes];

    uint16_t thresholdBrightness = (maxBrightness * THRESHOLD_PERCENT) / 100;
    for (int y=0; y<height; y++) {
        for (int x=0; x<width; x++) {
            uint8_t r = irBase[bytesPerRow*y+4*x+1];
            uint8_t g = irBase[bytesPerRow*y+4*x+2];
            uint8_t b = irBase[bytesPerRow*y+4*x+3];
            uint16_t brightness = r+g+b;
            workArea[y*width+x] = (brightness > thresholdBrightness) ? SEGMENT_ID : NO_SEGMENT_ID;
        }
    }

    //segmentize
    int numSegments = segmentize(workArea, width, height, SEGMENT_ID, 0);
    if (numSegments > MAX_RAW_SEGMENTS) {
        NSLog(@"raw segment count too high (%i, max: %i)",numSegments, MAX_RAW_SEGMENTS);
        return NO;
        
    }
    if (numSegments < MIN_SEGMENTS) {
        NSLog(@"raw segment count too low (%i, min: %i)",numSegments, MIN_SEGMENTS);
        return NO;
    }
    SegmentInfo segments[numSegments];
    fillSegmentInfo(workArea, width, height, segments, numSegments);

    //filter "good segments" with right size
    SegmentInfo goodSegments[numSegments];
    int numGoodSegments = 0;
    for (int i=0; i<numSegments; i++) {
        int segWidth = 1 + segments[i].maxX - segments[i].minX;
        int segHeight = 1 + segments[i].maxY - segments[i].minY;
        if ((segWidth >= WINDOW_MIN) && (segWidth <= WINDOW_MAX) && (segHeight >= WINDOW_MIN) && (segHeight <= WINDOW_MAX)) {
            memcpy(&(goodSegments[numGoodSegments]), &(segments[i]), sizeof(SegmentInfo));
            numGoodSegments++;
        } else {
            NSLog(@"discarding segment with seed %i %i size %i %i",
                  segments[i].seedX, segments[i].seedY, segWidth, segHeight);
        }
    }
    if (numGoodSegments < MIN_SEGMENTS) {
        NSLog(@"not enough good segments (%i, min: %i)",numGoodSegments, MIN_SEGMENTS);
        return NO;
    }
    if (numGoodSegments > MAX_SEGMENTS) {
        NSLog(@"too many good segments (%i, max: %i)",numGoodSegments, MAX_SEGMENTS);
        return NO;
    }
    
    //find circles
    int numGoodCircles = 0;
    double ccx = 0;
    double ccy = 0;
    for (int i=0; i<numGoodSegments; i++) {
        for (int j=i+1; j<numGoodSegments; j++) {
            for (int k=j+1; k<numGoodSegments; k++) {
                //three triangle points
                double x1 = goodSegments[i].weightX;
                double y1 = goodSegments[i].weightY;
                double x2 = goodSegments[j].weightX;
                double y2 = goodSegments[j].weightY;
                double x3 = goodSegments[k].weightX;
                double y3 = goodSegments[k].weightY;
                Circle c;
                if (findCircleFromPoints(x1, y1, x2, y2, x3, y3, &c)) {
                    NSLog(@"found circle %f %f %f",c.cx, c.cy, c.rad);
                    if ((c.rad >= MIN_RADIUS) && (c.rad <= MAX_RADIUS)) {
                        ccx += c.cx;
                        ccy += c.cy;
                        numGoodCircles++;
                    }
                }
            }
        }
    }

    //see if we have enough circles
    if (numGoodCircles > MIN_CIRCLES) {
        NSLog(@"raw detect position: %f %f",ccx / numGoodCircles,ccy / numGoodCircles);
        if (pt) {
            double major = MAX(width, height);
            pt->x = ((ccx / numGoodCircles) * 2.0 - width) / major;
            pt->y = ((ccy / numGoodCircles) * 2.0 - height) / major;
        }
        return YES;
    }
    return NO;
}

@end
