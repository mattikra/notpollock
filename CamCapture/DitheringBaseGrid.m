//
//  DitheringBaseGrid.m
//  CamCapture
//
//  Created by Omid Hashemi on 26/05/16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "DitheringBaseGrid.h"


@implementation DitheringBaseGrid

-(instancetype)initWithWidth:(int) width Height:(int)height {
  if(self = [super init]) {
    self.width = width;
    self.height = height;
  }
  
  return self;
}

-(BOOL) shouldOpenForPos:(NSPoint)point {
  NSLog(@"Not Implemented.");
  return false;
}

@end