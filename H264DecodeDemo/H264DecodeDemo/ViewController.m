//
//  ViewController.m
//  H264DecodeDemo
//
//  Created by Chengguangfa on 2019/2/12.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"
#import <VideoToolbox/VideoToolbox.h>

const uint8_t lyStartCode[4] = {0,0,0,1};

@interface ViewController ()

@end

@implementation ViewController
{
    dispatch_queue_t _decodeQueue;
    VTDecompressionSessionRef _decompressionSession;
    CMFormatDescriptionRef _format;
    
    //参数集
    uint8_t *_sps;
    long _spsSize;
    uint8_t *_pps;
    long _ppsSize;
    
    //输入
    NSInputStream *_inputStream;
    uint8_t *_packetBuffer;
    long _packetSize;
    uint8_t *_inputBuffer;
    long _inputSize;
    long _maxInputSize;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
}

-(void)onInputStart{
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"qwe" ofType:@"h264"];
    _inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    [_inputStream open];
    _inputSize = 0;
    _maxInputSize = 640 * 480 * 3 * 4;
    _inputBuffer = malloc(_maxInputSize);
    
}

-(void)onInputEnd
{
    [_inputStream close];
    _inputStream = nil;
    
    if (_inputBuffer) {
        free(_inputBuffer);
        _inputBuffer = NULL;
    }
}

-(void)updateFrame
{
    if (_inputStream) {
        dispatch_sync(_decodeQueue, ^{
            [self readPacket];
            
            if (_packetBuffer == NULL || _packetSize == 0) {
                [self onInputEnd];
                return ;
            }
            uint32_t nalSize = (uint32_t)(_packetSize - 4);
            uint32_t *pNalSize = (uint32_t *)_packetBuffer;
            *pNalSize = CFSwapInt32HostToBig(nalSize);
            
            CVPixelBufferRef pixelBuffer = NULL;
            int nalType = _packetBuffer[4] & 0x1f;
            
            switch (nalType) {
                case 0x05:
                    NSLog(@"Nal type is IDR frame");
                    [self initVTBox];
                    pixelBuffer = [self decode];
                    break;
                case 0x07:
                    _spsSize = _packetSize - 4;
                    _sps = malloc(_spsSize);
                    memcpy(_sps, _packetBuffer + 4, _spsSize);
                    NSLog(@"Nal type is sps");
                    break;
                case 0x08:
                    NSLog(@"Nal type is pps");
                    _ppsSize = _packetSize - 4;
                    _pps = malloc(_ppsSize);
                    memcpy(_pps, _packetBuffer + 4, _ppsSize);
                    break;
                default:
                    NSLog(@"Nal type is B/P frame");
                    pixelBuffer = [self decode];
                    break;
            }
            
            if (pixelBuffer) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    //1.使用pixelBuffer
                    //2.释放
                    CVPixelBufferRelease(pixelBuffer);
                });
            }
            
            NSLog(@"read NALU size %d", _packetSize);
            
        });
    }
}

-(void)readPacket
{
    if (_packetSize && _packetBuffer) {
        _packetSize = 0;
        free(_packetBuffer);
        _packetBuffer = NULL;
    }
    //继续读数据
    if (_inputSize < _maxInputSize && _inputStream.hasBytesAvailable) {
        _inputSize += [_inputStream read:_inputBuffer + _inputSize maxLength:_maxInputSize - _inputSize];
    }
    //判断起始码
    if (memcmp(_inputBuffer, lyStartCode, 4) == 0) {
        if (_inputSize > 4) { //除了起始码还有其他数据
            uint8_t *pStart = _inputBuffer + 4;
            uint8_t *pEnd = _inputBuffer +  _inputSize;
            
            while (pStart != pEnd) { // 通过查找下个起始码 -- 来确定
                if (memcmp(pStart - 3, lyStartCode, 4) == 0) {
                    _packetSize = pStart - _inputBuffer - 3;
                    
                    if (_packetBuffer) {
                        free(_packetBuffer);
                        _packetBuffer = NULL;
                    }
                    _packetBuffer  = malloc(_packetSize);
                    //复制数据
                    memcpy(_packetBuffer, _inputBuffer, _packetSize);
                    //数据移动
                    memmove(_inputBuffer, _inputBuffer+_packetSize, _inputSize - _packetSize);
                    //缩小输入大小
                    _inputSize -= _packetSize;
                    
                }
                else
                {
                    pStart++;
                }
            }
            
        }
    }
    
}

-(CVPixelBufferRef)decode{
    
    CVPixelBufferRef outputBuffer = NULL;
    
    if (_decompressionSession) {
        CMBlockBufferRef blockBuffer = NULL;
        
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                             (void *)_packetBuffer,
                                                             _packetSize,
                                                             kCFAllocatorNull,
                                                             NULL,
                                                             0,
                                                             _packetSize,
                                                             0,
                                                             &blockBuffer);
        
        
        if (status == kCMBlockBufferNoErr) {
            
            CMSampleBufferRef sampler = NULL;
            const size_t samplerSizeArray = {_packetSize};
            
            status = CMSampleBufferCreateReady(NULL,
                                               blockBuffer,
                                               _format,
                                               1,
                                               0,
                                               NULL,
                                               1,
                                               &samplerSizeArray,
                                               &sampler);
            
            if (status == kCMBlockBufferNoErr && sampler) {
                
                VTDecodeInfoFlags flags = 0;
                VTDecodeFrameFlags frameFlags = 0;
                
                //默认是同步 , 调用 didDecompress, 返回后在调用
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(
                                                                          _decompressionSession,
                                                                          sampler,
                                                                          frameFlags,
                                                                          &outputBuffer,
                                                                          &flags);
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
                }
                
                CFRelease(sampler);
            }
            CFRelease(blockBuffer);
        }
        
    }
    
    return outputBuffer;
    
}

 void didDecompress(
                                              void * CM_NULLABLE decompressionOutputRefCon,
                                              void * CM_NULLABLE sourceFrameRefCon,
                                              OSStatus status,
                                              VTDecodeInfoFlags infoFlags,
                                              CM_NULLABLE CVImageBufferRef imageBuffer,
                                              CMTime presentationTimeStamp,
                                              CMTime presentationDuration )
{
    //sourceFrameRefCon: 是VTDecompressionSessionDecodeFrame函数的sourceFrameRefCon参数的引用。
    CVPixelBufferRef *outputBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputBuffer = CVPixelBufferRetain(imageBuffer);
}
-(void)initVTBox
{
    if (!_decompressionSession) {
        const uint8_t * parameterSetPoints[2] = {_sps,_pps};
        const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
        //创建 formatDescription
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                                                                              kCFAllocatorDefault,
                                                                              2,//parameter count
                                                                              parameterSetPoints,
                                                                              parameterSetSizes,
                                                                              4,//NALUnitHeaderLength
                                                                              &_format);
        if (status == noErr) {
            CFDictionaryRef attr = NULL;
            /*
             Planar: 平面；BiPlanar：双平面
             平面／双平面主要应用在yuv上。uv分开存储的为Planar，反之是BiPlanar。所以，kCVPixelFormatType_420YpCbCr8PlanarFullRange是420p，kCVPixelFormatType_420YpCbCr8BiPlanarFullRange是nv12.
             */
            const void *key[] = {kCVPixelBufferPixelFormatTypeKey};
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            const void *value[] = {CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &v)};
            attr  = CFDictionaryCreate(NULL, key, value, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBack;
            callBack.decompressionOutputRefCon = NULL;
            callBack.decompressionOutputCallback = didDecompress;
            
            //创建_decompressionSession
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  _format,
                                                  attr,
                                                  NULL,
                                                  &callBack,
                                                  &_decompressionSession);
            
            
            CFRelease(attr);
            
        }
    }
}
-(void)endVTBox
{
    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        free(_decompressionSession);
        _decompressionSession = NULL;
    }
    
    if (_format) {
        CFRelease(_format);
        _format = NULL;
    }
    
    free(_sps);
    free(_pps);
    
    _spsSize = _ppsSize = 0;
}
@end
