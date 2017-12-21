//
//  LYPlayer.m
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/12/6.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "LYPlayer.h"
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation LYPlayer
{
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    UInt32 readedSize;
}

- (void)play {
    AudioOutputUnitStart(audioUnit);
}

- (double)getCurrentTime {
    Float64 timeInterval = 0;
    
    return timeInterval;
}



- (void)prepareForPlayWithOutputASBD:(AudioStreamBasicDescription)outputFormat {
    // open pcm stream
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    // set audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    [audioSession setPreferredIOBufferDuration:0.1 error:&error];
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    //audio property
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status:%d", (int)status);
    }
    
    // format
    [self printAudioStreamBasicDescription:outputFormat];

    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", (int)status);
    }
    
    
    // callback
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", (int)result);
}


static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    LYPlayer *player = (__bridge LYPlayer *)inRefCon;
    
    if (!player->bufferList || player->readedSize + ioData->mBuffers[0].mDataByteSize > player->bufferList->mBuffers[0].mDataByteSize) {
        player->bufferList = [player.delegate onRequestAudioData];
        player->readedSize = 0;
    }
    
    if (!player->bufferList || player->bufferList->mNumberBuffers == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    else {
        for (int i = 0; i < player->bufferList->mNumberBuffers; ++i) {
            memcpy(ioData->mBuffers[i].mData, player->bufferList->mBuffers[i].mData + player->readedSize, ioData->mBuffers[i].mDataByteSize);
            player->readedSize += ioData->mBuffers[i].mDataByteSize;
        }
    }
    return noErr;
}


- (void)stop {
    AudioOutputUnitStop(audioUnit);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)]) {
        __strong typeof (LYPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
}

- (void)dealloc {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
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
