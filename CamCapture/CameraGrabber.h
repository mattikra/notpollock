//
//  CameraGrabber.h
//  CamCapture
//
//  Created by Matthias Krauß on 04.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol CameraGrabberDelegate

- (void) handleCameraFrame:(NSBitmapImageRep*)frame timestamp:(NSDate*)timestamp;

@end

@interface CameraGrabber : NSObject

@property (strong, readonly) NSArray* availableCameras;
@property (strong) AVCaptureDevice* currentCamera;

@property (weak) id<CameraGrabberDelegate> delegate;

- (void) run;


@end
