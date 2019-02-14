//
//  AACEncoder.h
//  VTBoxEncoding
//
//  Created by Chengguangfa on 2019/2/12.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACEncoder : NSObject
@property (nonatomic) dispatch_queue_t  encodeQueue;
@property (nonatomic) dispatch_queue_t  callBackQueue;
-(void)encodeSamplerBuffer:(CMSampleBufferRef)samplerBuffer completion:(void (NSData *encodedData, NSError *error))completionBlock;
@end


