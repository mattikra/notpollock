//
//  DitheringBaseGrid.m
//  CamCapture
//
//  Created by Omid Hashemi on 26/05/16.
//  Copyright © 2016 Matthias Krauß. All rights reserved.
//

#import "FloydSteinbergDithering.h"

@interface FloydSteinbergDithering(private)

@property (assign) int width;
@property (assign) int height;
@property (strong) NSMutableData* matrixData;
- (float) matrixValueAtX:(unsigned int)x y:(unsigned int)y;
- (void) setMatrixValueAtX:(unsigned int)x y:(unsigned int)y to:(float)val;

@end

@implementation FloydSteinbergDithering {
  NSMutableArray *_matrix;
//  float *_matrix2;
}

-(instancetype)initWithWidth:(int)width Height:(int)height {
  if([super initWithWidth:width Height:height]) {
    
    self.matrixData = [NSMutableData dataWithLength:sizeof(float)*width*height];
    self.width = width;
    self.height = height;
    
    _matrix = [NSMutableArray arrayWithCapacity:width];
    
    for(int x = 0; x < width; x++) {
      NSMutableArray *subMatrix = [NSMutableArray arrayWithCapacity:height];
      for(int y = 0; y < height; y++) {
        //[(NSMutableArray *)((NSMutableArray *)_matrix[x])[y] addObject:@(0)];
        [subMatrix addObject:@(0)];
      }
      _matrix[x] = subMatrix;
    }
    
    NSLog(@"%s: initialized", __PRETTY_FUNCTION__);
    
//    float _mat[width][height];
//    bzero(_mat, sizeof(_mat));
//    _matrix2 = &_mat;

  }
  return self;
}

-(BOOL)shouldOpenForPos:(NSPoint)point {
  
  float stepValue = .5;
  float quant_error = .3;
  float maxValue = 1.0;
  
  int major = MAX(self.width, self.height);
  int xImg = (point.x / 2.0) * major + (self.width / 2.0);
  int yImg = (point.y / 2.0) * major + (self.height / 2.0);
  bool retVal = false;
  
  if(_matrix.count >= xImg && ((NSArray *)_matrix[xImg]).count >= yImg) {
    float val = ((NSNumber*)(NSArray*)_matrix[xImg][yImg]).floatValue;
    
    if(val >= 1.0) {
      NSLog(@"1");
    }
    
    if(val < maxValue) {
      retVal = true;
      
      float newVal = val + stepValue;
      
//      NSLog(@"FS: %d/%d - %f / %f", xImg, yImg, val ,newVal);
      
      ((NSMutableArray *)_matrix[xImg])[yImg] = @(newVal);
      
      float rightVal = -1;
      float newRightVal = -1;
      float leftDownVal = -1;
      float newLeftDownVal = -1;
      float downVal = -1;
      float newDownVal = -1;
      float rightDownVal = -1;
      float newRightDownVal = -1;
      
      if(_matrix.count >= xImg+1) {
        //    pixel[x+1][y  ] := pixel[x+1][y  ] + quant_error * 7 / 16
        rightVal = ((NSNumber*)(NSArray*)_matrix[xImg+1][yImg]).floatValue;
        newRightVal = rightVal + quant_error * 7 / 16;
        ((NSMutableArray *)_matrix[xImg+1])[yImg] = @(newRightVal);
      }
      
      if(xImg > 0 && ((NSArray *)_matrix[xImg]).count >= yImg+1) {
        //    pixel[x-1][y+1] := pixel[x-1][y+1] + quant_error * 3 / 16
        leftDownVal = ((NSNumber*)(NSArray*)_matrix[xImg-1][yImg+1]).floatValue;
        newLeftDownVal = leftDownVal + quant_error * 3 / 16;
        ((NSMutableArray *)_matrix[xImg-1])[yImg+1] = @(newLeftDownVal);
      }
      
      if(((NSArray *)_matrix[xImg]).count >= yImg+1) {
        //    pixel[x  ][y+1] := pixel[x  ][y+1] + quant_error * 5 / 16
        downVal = ((NSNumber*)(NSArray*)_matrix[xImg][yImg+1]).floatValue;
        newDownVal = downVal + quant_error * 5 / 16;
        ((NSMutableArray *)_matrix[xImg])[yImg+1] = @(newDownVal);
      }
      
      if(_matrix.count >= xImg+1 && ((NSArray *)_matrix[xImg]).count >= yImg+1) {
        //    pixel[x+1][y+1] := pixel[x+1][y+1] + quant_error * 1 / 16
        rightDownVal = ((NSNumber*)(NSArray*)_matrix[xImg+1][yImg+1]).floatValue;
        newRightDownVal = rightDownVal + quant_error * 1 / 16;
        ((NSMutableArray *)_matrix[xImg+1])[yImg+1] = @(newRightDownVal);
      }
      
      
//      NSLog(@"NA\t%f\t%f", val, rightVal);
//      NSLog(@"%f\t%f\t%f\n", leftDownVal, downVal, rightDownVal);
//      
//      NSLog(@"\t%f\t%f", newVal, newRightVal);
//      NSLog(@"%f\t%f\t%f\n", newLeftDownVal, newDownVal, newRightDownVal);
      
    }
    
  }
  
  return retVal;
}

//-(BOOL)shouldOpenForPos:(NSPoint)point {
//  
//  float stepValue = .5;
//  float quant_error = .3;
//  float maxValue = 1.0;
//  
//  int major = MAX(self.width, self.height);
//  int xImg = (point.x / 2.0) * major + (self.width / 2.0);
//  int yImg = (point.y / 2.0) * major + (self.height / 2.0);
//  
//  float val = *(_matrix2 + xImg * yImg); //*(*(&_matrix2 + xImg) + yImg); //
//  
//  bool retVal = false;
//  
//  if(val < maxValue) {
//    retVal = true;
//    
//    float newVal = val + stepValue;
//    
//    NSLog(@"FS: %d/%d - %f / %f", xImg, yImg, val ,newVal);
//    
//    
//    *(_matrix2 + xImg * yImg) = newVal;
//    
//    float rightVal = *(_matrix2 + (xImg+1) * yImg);
//    float leftDownVal = *(_matrix2 + (xImg-1) * (yImg+1));
//    float downVal = *(_matrix2 + (xImg) * (yImg+1));
//    float rightDownVal = *(_matrix2 + (xImg+1) * (yImg+1));
//
//    //    pixel[x+1][y  ] := pixel[x+1][y  ] + quant_error * 7 / 16
//    //    pixel[x-1][y+1] := pixel[x-1][y+1] + quant_error * 3 / 16
//    //    pixel[x  ][y+1] := pixel[x  ][y+1] + quant_error * 5 / 16
//    //    pixel[x+1][y+1] := pixel[x+1][y+1] + quant_error * 1 / 16
//    float newRightVal = rightVal + quant_error * 7 / 16;
//    float newLeftDownVal = leftDownVal + quant_error * 3 / 16;
//    float newDownVal = downVal + quant_error * 5 / 16;
//    float newRightDownVal = rightDownVal + quant_error * 1 / 16;
//    
//    *(_matrix2 + (xImg+1) * yImg) = newRightVal;
//    *(_matrix2 + (xImg-1) * (yImg+1)) = newLeftDownVal;
//    *(_matrix2 + (xImg) * (yImg+1)) = newDownVal;
//    *(_matrix2 + (xImg+1) * (yImg+1)) = newRightDownVal;
//    
//    NSLog(@"NA\t%f\t%f", val, rightVal);
//    NSLog(@"%f\t%f\t%f\n", leftDownVal, downVal, rightDownVal);
//    
//    NSLog(@"\t%f\t%f", newVal, newRightVal);
//    NSLog(@"%f\t%f\t%f\n", newLeftDownVal, newDownVal, newRightDownVal);
//    
//    
//  }
//  
//  return retVal;
//}


- (float) matrixValueAtX:(unsigned int)x y:(unsigned int)y {
  if ((x >= self.width) || (y >= self.height)) {
    return 0.0f;
  }
  float* base = (float*)(self.matrixData.mutableBytes);
  return base[y*self.width+x];
}

- (void) setMatrixValueAtX:(unsigned int)x y:(unsigned int)y to:(float)val {
  if ((x < self.width) && (y < self.height)) {
    float* base = (float*)(self.matrixData.mutableBytes);
    base[y*self.width+x] = val;
  }
}


@end