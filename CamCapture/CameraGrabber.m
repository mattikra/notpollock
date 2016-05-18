//
//  CameraGrabber.m
//  CamCapture
//
//  Created by Matthias Krauß on 04.05.16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "CameraGrabber.h"

@interface CameraGrabber () <AVCaptureVideoDataOutputSampleBufferDelegate>


@property (strong) AVCaptureSession* session;
@property (strong, readwrite) NSArray* availableCameras;

@end

@implementation CameraGrabber


- (id) init {
    self = [super init];
    if (self) {
        self.availableCameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice* device in self.availableCameras) {
            NSLog(@"camera name %@ model %@ uid %@",device.localizedName, device.modelID, device.uniqueID);
        }
        if (self.availableCameras.count < 1) {
            NSError* error = [NSError errorWithDomain:@"CamCapture"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey:@"No camera found"}];
            [[NSAlert alertWithError:error] runModal];
            [NSApp terminate:self];
        }
        self.currentCamera = self.availableCameras[0];
    }
    return self;
}

- (void) run {
    if (self.session) {
        [self.session stopRunning];
        self.session = nil;
        return;
    }
    NSLog(@"current camera name %@ model %@ uid %@",self.currentCamera.localizedName, self.currentCamera.modelID, self.currentCamera.uniqueID);
    self.session = [AVCaptureSession new];
    NSError* error = nil;
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:self.currentCamera error:&error];
    if (error) {
        NSLog(@"Error %@",error);
    }
    [self.session addInput:input];
    AVCaptureVideoDataOutput* output = [AVCaptureVideoDataOutput new];
    dispatch_queue_t queue = dispatch_get_main_queue();
    [output setSampleBufferDelegate:self queue:queue];
    [output setVideoSettings:@{(NSString*)kCVPixelBufferPixelFormatTypeKey:
                                   [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB]}];
    [self.session addOutput:output];
    [self.session startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSDate* date = [NSDate date];
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    NSBitmapImageRep* ir = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:width
                                                                   pixelsHigh:height
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSDeviceRGBColorSpace
                                                                 bitmapFormat:NSAlphaFirstBitmapFormat
                                                                  bytesPerRow:bytesPerRow
                                                                 bitsPerPixel:32];
    
    uint8_t* irBase = [ir bitmapData];
    memcpy(irBase, baseAddress, height * bytesPerRow);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    if (self.delegate) {
        [self.delegate handleCameraFrame:ir timestamp:date];
    }
}
@end
