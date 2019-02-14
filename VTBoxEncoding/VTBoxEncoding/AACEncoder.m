//
//  AACEncoder.m
//  VTBoxEncoding
//
//  Created by Chengguangfa on 2019/2/12.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "AACEncoder.h"
@interface AACEncoder()
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@property (nonatomic) char *pcmBuffer;
@property (nonatomic) size_t pcmBufferSize;
@end
@implementation AACEncoder

-(instancetype)init
{
    if (self = [super init]) {
        _encodeQueue = dispatch_queue_create("AAC Encode Queue", DISPATCH_QUEUE_SERIAL);
        _callBackQueue = dispatch_queue_create("AAC Call Back Queue", DISPATCH_QUEUE_SERIAL);
        
        _audioConverter = NULL;
        _pcmBuffer = NULL;
        _pcmBufferSize = 0;
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
        
    }
    return self;
}

-(void)setupEncoderFromSamplerBuffer:(CMSampleBufferRef)samplerBuffer
{
    AudioStreamBasicDescription inAudioStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(samplerBuffer));
    //设置初始输出 为 0
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    // 音频流，在正常播放情况下的帧率。如果是压缩的格式，这个属性表示解压缩后的帧率。帧率不能为0。
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
    //设置编码格式
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    //无损压缩  0 表示没有
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    //每个音频packet的大小. 如果是动态大小, 设置为0.动态大小的格式，需要用AudioStreamPacketDescription 来确定每个packet的大小。
    outAudioStreamBasicDescription.mBytesPerPacket = 0;
    // 每个packet的帧数。如果是未压缩的音频数据，值是1。动态帧率格式，这个值是一个较大的固定数字，比如说AAC的1024。如果是动态大小帧数（比如Ogg格式）设置为0。
    outAudioStreamBasicDescription.mFramesPerPacket = 1024;
    //  每帧的大小。每一帧的起始点到下一帧的起始点。如果是压缩格式，设置为0 。
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    // 声道数
    outAudioStreamBasicDescription.mChannelsPerFrame = 1;
    // 压缩格式设置为0
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    // 8字节对其, 填0
    outAudioStreamBasicDescription.mReserved = 0;
    
    AudioClassDescription *audioClass = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    //创建转化器
    OSStatus status = AudioConverterNewSpecific(
                                                &inAudioStreamBasicDescription,
                                                &outAudioStreamBasicDescription,
                                                1,
                                                audioClass,
                                                &_audioConverter);
    
    if (status !=  0) {
        NSLog(@"set up converter : %d", (int)status);
    }
    
}
  
/**
 获取编码器

 @param type 编码格式
 @param manufacturer 软/硬编码
 @return 返回指定编码器
 
  编解码器（codec）指的是一个能够对一个信号或者一个数据流进行变换的设备或者程序。这里指的变换既包括将 信号或者数据流进行编码（通常是为了传输、存储或者加密）或者提取得到一个编码流的操作，也包括为了观察或者处理从这个编码流中恢复适合观察或操作的形式的操作。编解码器经常用在视频会议和流媒体等应用中。
 */
-(AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer
{
    
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    UInt32 size;
    OSStatus status;
    
    status = AudioFormatGetPropertyInfo(
                                        kAudioFormatProperty_Encoders,
                                        sizeof(encoderSpecifier),
                                        &encoderSpecifier,
                                        &size);
    if (status) {
        NSLog(@"error getting audio format property info : %d", status);
        return NULL;
    }
    
    unsigned int count = size/sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descriptions);
    
    if (status) {
        NSLog(@"error getting audio format property : %d",status);
        return NULL;
    }
    
    //找到对应的解码器
    for (unsigned int i = 0; i < count; ++i) {
        
        if (type == descriptions[i].mSubType && manufacturer == descriptions[i].mManufacturer) {
            memcpy(&desc, &descriptions[i], sizeof(desc));
            return &desc;
        }
        
    }
    
    return NULL;
}

-(void)encodeSamplerBuffer:(CMSampleBufferRef)samplerBuffer completion:(void (NSData *encodedData, NSError *error))completionBlock
{
    CFRetain(samplerBuffer);
    
    dispatch_async(_encodeQueue, ^{
       
        if (!_audioConverter) {
            [self setupEncoderFromSamplerBuffer:samplerBuffer];
        }
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(samplerBuffer);
        CFRetain(blockBuffer);
        
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
        NSError *error = nil;
        
        if (status != kCMBlockBufferNoErr) {
            error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        
        memset(self->_aacBuffer, 0, self->_aacBufferSize);
        
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = 1;
        outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
        outAudioBufferList.mBuffers[0].mData = _aacBuffer;
        
        AudioStreamPacketDescription *outPacketDescription = NULL;
        UInt32 ioOutputDataPacketSize = 1;
        // Converts data supplied by an input callback function, supporting non-interleaved and packetized formats.
        // Produces a buffer list of output data from an AudioConverter. The supplied input callback function is called whenever necessary.
        status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge  void *)self, &ioOutputDataPacketSize, &outAudioBufferList, outPacketDescription);
        
        NSData *data = nil;
        
        if (status == noErr) {
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
            NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
            [fullData appendData:rawAAC];
            
            data = fullData;
        }
        else
        {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        
        if (completionBlock) {
            dispatch_async(_callBackQueue, ^{
                completionBlock(data, error);
            });
        }
        
        CFRelease(samplerBuffer);
        CFRelease(blockBuffer);
    });
    

}
/**
 *  A callback function that supplies audio data to convert. This callback is invoked repeatedly as the converter is ready for new input data.
 
 */

OSStatus inInputDataProc(  AudioConverterRef               inAudioConverter,
          UInt32 *                        ioNumberDataPackets,
          AudioBufferList *               ioData,
          AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
          void * __nullable               inUserData)
{
    
    AACEncoder *encoder = (__bridge AACEncoder *)inUserData;
    
    UInt32 requestedPacket = *ioNumberDataPackets;
    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPacket) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    return noErr;
}

/**
 填充PCM到缓冲区

 @param ioData 缓冲区
 @return 返回写入缓冲区的大小
 */
-(size_t)copyPCMSamplesIntoBuffer:(AudioBufferList *)ioData
{
    size_t originBufferSize = _pcmBufferSize;
    if (!originBufferSize) {
        return 0;
    }
    
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = (int)_pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    
    return originBufferSize;
}


/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}
@end
