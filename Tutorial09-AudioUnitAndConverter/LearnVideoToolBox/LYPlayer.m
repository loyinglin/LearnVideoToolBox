//
//  LYPlayer.m
//  LearnVideoToolBox
//
//  Created by loyinglin on 2017/9/13.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import "LYPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation LYPlayer
{
    AudioFileID audioFileID;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamPacketDescription *audioPacketFormat;
    
    SInt64 readedPacket; //参数类型
    UInt64 packetNums; // 总的packet数量
    UInt64 packetNumsInBuffer; // buffer中最多的buffer数量
    
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    Byte *convertBuffer;
    
    AudioConverterRef audioConverter;
}


- (instancetype)init {
    self = [super init];
    [self customAudioConfig];
    
    return self;
}

- (void)customAudioConfig {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"aac"];
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID);
    if (status) {
        NSLog(@"打开文件失败 %@", url);
    }
    
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioFileFormat); // 读取文件格式
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    
    size = sizeof(packetNums);
    status = AudioFileGetProperty(audioFileID,
                                  kAudioFilePropertyAudioDataPacketCount,
                                  &size,
                                  &packetNums);
    readedPacket = 0;
    
    audioPacketFormat = malloc(sizeof(AudioStreamPacketDescription) * packetNums);
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    
    audioConverter = NULL;
}


- (void)play {
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}


- (double)getCurrentTime {
    Float64 timeInterval = (readedPacket * 1.0) / packetNums;
    return timeInterval;
}



- (void)initPlayer {
    NSError *error = nil;
    OSStatus status = noErr;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    // BUFFER
    UInt32 flag = 0;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    
    convertBuffer = malloc(CONST_BUFFER_SIZE);
    
    
    //initAudioProperty
    
    flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status:%d", status);
    }
    
    
    //initFormat
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    [self printAudioStreamBasicDescription:audioFileFormat];
    [self printAudioStreamBasicDescription:outputFormat];
    status = AudioConverterNew(&audioFileFormat, &outputFormat, &audioConverter);
    if (status) {
        NSLog(@"AudioConverterNew eror with status:%d", status);
    }
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    [self initPlayCallback];
    
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
}

OSStatus lyInInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    LYPlayer *player = (__bridge LYPlayer *)(inUserData);
    
    UInt32 byteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioFileReadPacketData(player->audioFileID, NO, &byteSize, player->audioPacketFormat, player->readedPacket, ioNumberDataPackets, player->convertBuffer);
    
    if (outDataPacketDescription) {
        *outDataPacketDescription = player->audioPacketFormat;
    }
    
    
    if(status) {
        NSLog(@"读取文件失败");
    }
    
    if (!status && ioNumberDataPackets > 0) {
        ioData->mBuffers[0].mDataByteSize = byteSize;
        ioData->mBuffers[0].mData = player->convertBuffer;
        player->readedPacket += *ioNumberDataPackets;
        return noErr;
    }
    else {
        return -12306; // NoMoreData
    }
    
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    LYPlayer *player = (__bridge LYPlayer *)inRefCon;
    
    player->buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioConverterFillComplexBuffer(player->audioConverter, lyInInputDataProc, inRefCon, &inNumberFrames, player->buffList, NULL);
    
    if (status) {
        NSLog(@"转换格式失败 %d", status);
    }
    
    NSLog(@"out size: %d", player->buffList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, player->buffList->mBuffers[0].mData, player->buffList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = player->buffList->mBuffers[0].mDataByteSize;
    
    fwrite(player->buffList->mBuffers[0].mData, player->buffList->mBuffers[0].mDataByteSize, 1, [player pcmFile]);
    
    if (player->buffList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}

- (FILE *)pcmFile {
    static FILE *_pcmFile;
    if (!_pcmFile) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.pcm"];
        _pcmFile = fopen(filePath.UTF8String, "w");
        
    }
    return _pcmFile;
}


- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
}


- (void)stop {
    AudioOutputUnitStop(audioUnit);
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)]) {
        __strong typeof (LYPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
}

- (void)dealloc {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
    if (convertBuffer != NULL) {
        free(convertBuffer);
        convertBuffer = NULL;
    }
    AudioConverterDispose(audioConverter);
}


- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}
@end
