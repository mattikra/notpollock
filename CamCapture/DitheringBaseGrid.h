//
//  DitheringBaseGrid.h
//  CamCapture
//
//  Created by Omid Hashemi on 26/05/16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DitheringBaseGrid : NSObject

@property int width;
@property int height;

-(instancetype)initWithWidth:(int) width Height:(int)height;
-(BOOL) shouldOpenForPos:(NSPoint)point;

@end
