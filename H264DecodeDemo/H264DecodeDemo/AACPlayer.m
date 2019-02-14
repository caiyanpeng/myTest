//
//  AACPlayer.m
//  H264DecodeDemo
//
//  Created by Chengguangfa on 2019/2/14.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "AACPlayer.h"
#import <AudioToolbox/AudioToolbox.h>

const uint32_t CONST_BUFFER_COUNT = 3;
const uint32_t CONST_BUFFER_SIZE = 0x10000;

@interface AACPlayer()

@end

@implementation AACPlayer
{
    AudioFileID audioFileID; // An opaque data type that represents an audio file object.
    AudioStreamBasicDescription audioStreamBasicDescription;//An audio data format specification for a stream of audio.
    AudioStreamPacketDescription *audioStreamPacketDescription;//Describes one packet in a buffer of audio data where the sizes of the packets differ or where there is non-audio data between audio packets.
    AudioQueueRef audioQueueRef;//Defines an opaque data type that represents an audio queue.
    AudioQueueBufferRef audioBuffer[CONST_BUFFER_SIZE]; // an audio queue buffer Array.
    SInt32 readPacket;
    u_int32_t packetNumber;
    
}

-(instancetype)init
{
    if (self = [super init]) {
        
    }
    return self;
}

-(void)preAudioConfiguration{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"" withExtension:@"aac"];
    //Open an existing audio file specified by a URL.
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID);
    
    if (status != noErr) {
        NSLog(@"打开文件失败 : error code %d", (int)status);
        return;
    }
    
    uint32_t size  = sizeof(AudioStreamBasicDescription);
    // Gets the value of an audio file property.
    status  = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioStreamBasicDescription);
    
    NSAssert(status == noErr, @"error");
     // Creates a new playback audio queue object.
    status = AudioQueueNewOutput(&audioStreamBasicDescription,
                                 audioQueueOutputCallback,
                                 (__bridge void *)self,
                                 NULL,
                                 NULL,
                                 0,
                                 &audioQueueRef);
    
    NSAssert(status == noErr, @"create AudioQueue error");
    // need to specify AudioStreamPacketDescription
    if (audioStreamBasicDescription.mBytesPerFrame == 0 && audioStreamBasicDescription.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        // The theoretical maximum packet size in the file.
        AudioFileGetProperty(audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize);
        
        if (maxSize > CONST_BUFFER_SIZE) {
            maxSize = CONST_BUFFER_SIZE;
        }
        packetNumber = CONST_BUFFER_SIZE/maxSize;
        audioStreamPacketDescription = malloc(sizeof(AudioStreamPacketDescription) * packetNumber);
    }
    else{
        packetNumber = CONST_BUFFER_SIZE/audioStreamBasicDescription.mBytesPerPacket;
        audioStreamPacketDescription = nil;
    }
    
    char cookies[200];
    memset(cookies, 0, sizeof(cookies));
    // Some file types require that a magic cookie be provided before packets can be written to an audio file.
    AudioFileGetProperty(audioFileID,
                         kAudioFilePropertyMagicCookieData,
                         &size,
                         cookies);
    
    if (size > 0) {
        // Sets an audio queue property value.
        AudioQueueSetProperty(audioQueueRef, kAudioQueueProperty_MagicCookie, cookies, size);
    }
    
    readPacket = 0;
    
    for (int i = 0; i < CONST_BUFFER_COUNT; ++i) {
        //Asks an audio queue object to allocate an audio queue buffer.
        AudioQueueAllocateBuffer(audioQueueRef, CONST_BUFFER_SIZE, &audioBuffer[i]);
        
        if ([self fillBuffer:audioBuffer[i]]) {
            break;
        }
        
        NSLog(@"buffer%d full",i);
    }
    
    
}
void audioQueueOutputCallback( void * __nullable       inUserData,
                                         AudioQueueRef           inAQ,
                                         AudioQueueBufferRef     inBuffer)
{
    NSLog(@"refresh buffer");
    AACPlayer *player = (__bridge AACPlayer *)inUserData;
    
    if (player) {
        NSLog(@"player is nil");
        return;
    }
    
    if (![player fillBuffer:inBuffer]) {
        NSLog(@"play end");
    }
    
}

-(BOOL)fillBuffer:(AudioQueueBufferRef)buffer
{
    BOOL full = NO;
    
    uint32_t bytes = 0, packets = (uint32_t)packetNumber;

    OSStatus status = AudioFileReadPacketData(audioFileID,
                                              false,
                                              &bytes,//On input, the size of the outBuffer parameter, in bytes. On output, the number of bytes actually read.
                                              audioStreamPacketDescription,
                                              readPacket,
                                              &packets,//On input, the number of packets to read. On output, the number of packets actually read.
                                              buffer->mAudioData);//Reads packets of audio data from an audio file.
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error from read packet with error code:%d",(int)status]));
    
    if (packets > 0) {
        buffer->mAudioDataByteSize = bytes;
        AudioQueueEnqueueBuffer(audioQueueRef,
                                buffer,
                                packets,//The number of packets of audio data in the inBuffer parameter. 
                                audioStreamPacketDescription);
        readPacket += packets;
    }
    else{
        AudioQueueStop(audioQueueRef, NO);
        full = YES;
    }
    
    return full;
}
-(void)play
{
    AudioQueueSetParameter(audioQueueRef, kAudioQueueParam_Volume, 1);
    AudioQueueStart(audioQueueRef, NULL);
}

-(double)getCurrentTime
{
    Float64 timeInterval = 0.0;
    if (audioQueueRef) {
        AudioQueueTimelineRef timeLine;
        AudioTimeStamp timeStamp;
        OSStatus status = AudioQueueCreateTimeline(audioQueueRef, &timeLine);
        
        if (status == noErr) {
            AudioQueueGetCurrentTime(audioQueueRef, timeLine, &timeStamp, NULL);
            /*
             outTimelineDiscontinuity
             On output, true if there has been a timeline discontinuity, or false if there has been no discontinuity. If the audio queue does not have an associated timeline object, this parameter is always NULL.
             */
            timeInterval = timeStamp.mSampleTime*1000000/audioStreamBasicDescription.mSampleRate; // The number of sample frames per second of the data in the stream.
        }
    }
    
    
    return timeInterval;
}

@end






