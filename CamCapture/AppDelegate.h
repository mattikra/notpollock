//
//  AppDelegate.h
//  CamCapture
//
//  Created by Matthias Krauß on 04.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign, nonatomic) BOOL fakeTracking;
@property (assign, nonatomic) BOOL doDrop;          //enable actual drops
@property (assign, nonatomic) double centerX;       //center x (-1..1) for marker detection transform
@property (assign, nonatomic) double centerY;       //center y (-1..1) for marker detection transform
@property (assign, nonatomic) double roiSize;       //region of interest (0..1) for marker detection transform
@property (assign, nonatomic) double thresSens;     //threshold sensitivity (0..1) for marker detection


@end

