//
//  ViewController.m
//  VTBoxEncoding
//
//  Created by Chengguangfa on 2019/1/30.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
@interface ViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate>
//视频捕捉
@property (strong, nonatomic) AVCaptureSession  *captureSession;
//输入
@property (strong, nonatomic) AVCaptureDeviceInput  *deviceInput;
//输出
@property (strong, nonatomic) AVCaptureVideoDataOutput  *output;
//阅览图
@property (strong, nonatomic) AVCaptureVideoPreviewLayer  *previewLayer;
@end

@implementation ViewController
{
    int frameID;
    dispatch_queue_t m_CaptureQueue;
    dispatch_queue_t m_EndcodeQueue;
    VTCompressionSessionRef _encodingSession;
    CMFormatDescriptionRef _format;
    NSFileHandle *_fileHandle;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
}

-(void)startCapture{
    self.captureSession = [[AVCaptureSession alloc] init];
    // 视频设置
    self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    //设置捕捉队列 -- 串行 DISPATCH_QUEUE_SERIAL 或者 0
    m_CaptureQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, DISPATCH_QUEUE_SERIAL);
    m_EndcodeQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //设备获取
    AVCaptureDevice *camera  = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        //后置摄像头
        if ([device position] == AVCaptureDevicePositionBack) {
            camera = device;
        }
        
    }
    
    self.deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:NULL];
    
    //添加输入
    if ([self.captureSession canAddInput:self.deviceInput]) {
        [self.captureSession addInput:self.deviceInput];
    }
    
    //添加输出
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    //是否丢弃没有及时的视频帧 -- 这里设置不丢弃
    [self.output setAlwaysDiscardsLateVideoFrames:NO];
    
    [self.output setVideoSettings:@{
                                    (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                    }];
    [self.output setSampleBufferDelegate:self queue:m_CaptureQueue];
    
    if ([self.captureSession canAddOutput:self.output]) {
        [self.captureSession addOutput:self.output];
    }
    
    //更改输出时的方向
    AVCaptureConnection *connection = [self.output connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    
    //创建预览图
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.previewLayer setFrame:self.view.bounds];
    
    [self.view.layer addSublayer:self.previewLayer];
    
    NSString *file = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"abc.h264"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
    }
    [[NSFileManager defaultManager] createFileAtPath:file contents:NULL attributes:NULL];
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    
    
    //设置编码
    [self initVTBox];
    //开始录制
    [self.captureSession startRunning];
    
    
}
-(void)endCapture{
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    [_fileHandle closeFile];
    _fileHandle = nil;
}


-(void)initVTBox{
    
    dispatch_sync(m_EndcodeQueue, ^{
        
        frameID = 0;
        
        int width = 480 , height = 960;
        
        OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)self,
                                                     &_encodingSession);
        
        
        if (status != 0) {
            NSLog(@"创建硬编码session失败");
            return ;
        }
        
        //设置实时编码
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        //设置关键帧间隔
        int frameInterLevel = 10;
        CFNumberRef frameInterLevelRef = CFNumberCreate(NULL, kCFNumberIntType, &frameInterLevel);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameInterLevelRef);
        
        //设置帧率
        int fps = 10;
        CFNumberRef fpsRef = CFNumberCreate(NULL, kCFNumberIntType, &fps);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        /*
         极低码率  (宽 * 高 * 3)/4
         低码率    (宽 * 高 * 3)/2
         中码率    (宽 * 高 * 3)
         高码率    (宽 * 高 * 3)*2
         极高码率  (宽 * 高 * 3)*4
         */
        
        //设置码率 bps
        int bitRate = width * height * 3 * 4 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(NULL, kCFNumberIntType, &bitRate);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        //设置均码率 单位是byte 8个b
        int bitRateLimit = width * height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(NULL, kCFNumberIntType, &bitRateLimit);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        //准备开始硬编码
        VTCompressionSessionPrepareToEncodeFrames(_encodingSession);
        
    });
    
    
}
-(void)endVTBox{
    VTCompressionSessionCompleteFrames(_encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_encodingSession);
    CFRelease(_encodingSession);
    _encodingSession = NULL;
}

#pragma mark --AVCaptureAudioDataOutputSampleBufferDelegate--
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(m_EndcodeQueue, ^{
        [self encodeWithSamplerBuffer:sampleBuffer];
    });
}

-(void)encodeWithSamplerBuffer:(CMSampleBufferRef)sampleBuffer
{
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    //帧时间, 如果不设置会导致时间轴过长
    CMTime presentationTimeStamp = CMTimeMake(frameID++ , 1000);
    
    VTEncodeInfoFlags flags;
    
    OSStatus statusCode = VTCompressionSessionEncodeFrame(
                                                          _encodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL,
                                                          NULL,
                                                          &flags);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame fail with code %d",statusCode);
        VTCompressionSessionInvalidate(_encodingSession);
        CFRelease(_encodingSession);
        _encodingSession = NULL;
        return;
    }
      NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    
}

void didCompressH264(void * CM_NULLABLE outputCallbackRefCon,
                 void * CM_NULLABLE sourceFrameRefCon,
                 OSStatus status,
                 VTEncodeInfoFlags infoFlags,
                 CM_NULLABLE CMSampleBufferRef sampleBuffer)
{
    NSLog(@"didCompresssH264 call with status = %d ;flags = %d", (int)status, (int)infoFlags);
    if (status != 0) {
        return;
    }
    
    //Determines if the sample buffer's data is ready.
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"the sample buffer's data is not ready.");
        return;
    }
    
    ViewController *encoder = (__bridge ViewController *)outputCallbackRefCon;
    
    //如果不是P帧和B帧, 就是关键帧
    bool keyFrame = !CFDictionaryContainsKey(
                                             (CFArrayGetValueAtIndex(
                                                                     CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,                      true),
                                                                     0))
                                             ,
                                             kCMSampleAttachmentKey_NotSync);
    
    
    
    //关键帧保存 sps 和 pps
    if (keyFrame) {
        
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t spsSetSize, spsSetCount;
        
        const uint8_t *spsSet;
        
        OSStatus status =  CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsSet, &spsSetSize, &spsSetCount, 0);
        
        if (status == noErr) {
            
            size_t ppsSetSize, ppsSetCount;
            const uint8_t *ppsSet;
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsSet, &ppsSetSize, &ppsSetCount, 0);
            
            
            if (status == noErr) {
                
                NSData *sps = [NSData dataWithBytes:spsSet length:spsSetSize];
                NSData *pps = [NSData dataWithBytes:ppsSet length:ppsSetSize];
                
                if (encoder) {
                    [encoder gotSps:sps pps:pps];
                }
                
            }
            
        }
        
        
    }
    
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t length , totalLength;
    char *dataPoint;
    
    status = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPoint);
    
    if (status == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;// 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        //循环获取NALU 数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPoint + bufferOffset, AVCCHeaderLength);
            
            //大端转化成系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData *data = [[NSData alloc] initWithBytes:(dataPoint + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            [encoder gotEncodeData:data isKeyFrame:keyFrame];
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
        
        
    }
    
    
    
    
}

-(void)gotSps:(NSData *)sps pps:(NSData *)pps
{
    NSLog(@"got sps pps %d -- %d", (int)sps.length, (int)pps.length);
    
    const char bytes[] = "\x00\x00\x00\x01";
    
    size_t length = sizeof(bytes) - 1;
    
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
    [_fileHandle writeData:byteHeader];
    [_fileHandle writeData:sps];
    [_fileHandle writeData:byteHeader];
    [_fileHandle writeData:pps];
    
}

-(void)gotEncodeData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"got data %d", (int)data.length);
    const char bytes[] = "\x00\x00\x00\x01";
    
    size_t length = sizeof(bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [_fileHandle writeData:byteHeader];
    [_fileHandle writeData:data];
    
}

@end
