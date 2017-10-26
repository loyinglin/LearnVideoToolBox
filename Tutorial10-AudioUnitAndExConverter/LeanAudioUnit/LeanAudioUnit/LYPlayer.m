
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/10/26.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "LYPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define OUTPUT_BUS (0)

@implementation LYPlayer
{
    ExtAudioFileRef exAudioFile;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamBasicDescription outputFormat;
    
    SInt64 readedFrame; // 已读的frame数量
    UInt64 totalFrame; // 总的Frame数量
    
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    
    AudioConverterRef audioConverter;
}


- (instancetype)init {
    self = [super init];
    
    return self;
}

- (void)play {
    [self initPlayer]; // 初始化
    AudioOutputUnitStart(audioUnit);
}


- (double)getCurrentTime {
    Float64 timeInterval = (readedFrame * 1.0) / totalFrame;
    return timeInterval;
}

- (void)setupAudioUnit {
    OSStatus status = noErr;
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    NSAssert(!status, @"AudioComponentInstanceNew error");
    
    //initAudioProperty
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
        NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    NSAssert(!status, @"AudioUnitSetProperty error");
    
    status = AudioUnitInitialize(audioUnit);
    NSAssert(!status, @"AudioUnitInitialize error");
}



- (void)initPlayer {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil]; // 只有播放
    
    // BUFFER
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    
    // Extend Audio File
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"pcm"];
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &exAudioFile);
    CheckError(status, "");
    NSAssert(!status, @"打开文件失败");
    
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = ExtAudioFileGetProperty(exAudioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat); // 读取文件格式
    NSAssert1(status == noErr, @"ExtAudioFileGetProperty error status %d", status);
    
    //initFormat
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    NSLog(@"input format:");
    [self printAudioStreamBasicDescription:audioFileFormat];
    NSLog(@"output format:");
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = ExtAudioFileSetProperty(exAudioFile, kExtAudioFileProperty_ClientDataFormat, size, &outputFormat);
    NSAssert1(!status, @"ExtAudioFileSetProperty eror with status:%d", status);

    // 初始化不能太前，如果未设置好输入输出格式，获取的总frame数不准确
    size = sizeof(totalFrame);
    status = ExtAudioFileGetProperty(exAudioFile,
                                     kExtAudioFileProperty_FileLengthFrames,
                                     &size,
                                     &totalFrame);
    readedFrame = 0;
    NSAssert(!status, @"ExtAudioFileGetProperty error");
    
    // audio unit
    [self setupAudioUnit];
}





OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    LYPlayer *player = (__bridge LYPlayer *)inRefCon;
    
    player->buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    OSStatus status = ExtAudioFileRead(player->exAudioFile, &inNumberFrames, player->buffList);
    
    if (status) NSLog(@"转换格式失败");
    if (!inNumberFrames) NSLog(@"播放结束");
    
    NSLog(@"out size: %d", player->buffList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, player->buffList->mBuffers[0].mData, player->buffList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = player->buffList->mBuffers[0].mDataByteSize;
    
    player->readedFrame += player->buffList->mBuffers[0].mDataByteSize / player->outputFormat.mBytesPerFrame; //Bytes per Frame = 2，所以是每2bytes一帧
    
    fwrite(player->buffList->mBuffers[0].mData, player->buffList->mBuffers[0].mDataByteSize, 1, [player pcmFile]);
    
    if (player->buffList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player onPlayEnd];
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

- (void)onPlayEnd {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        
        free(buffList);
        buffList = NULL;
    }
    
    AudioConverterDispose(audioConverter);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)]) {
        __strong typeof (LYPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
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



void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}
@end
