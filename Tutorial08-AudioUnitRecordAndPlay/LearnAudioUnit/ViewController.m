//
//  ViewController.m
//  LearnAudioUnit
//
//  Created by loyinglin on 2017/9/4.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define CONST_BUFFER_SIZE 2048*2*10

@implementation ViewController
{
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    AudioBufferList *otherBuffList;
    NSMutableData *recordData;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)initRemoteIO {
    NSError *error = nil;
    OSStatus status = noErr;
    
    // audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"setCategory error:%@", error);
    }
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
    if (error) {
        NSLog(@"setPreferredIOBufferDuration error:%@", error);
    }
    // buffer list
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    otherBuffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    otherBuffList->mNumberBuffers = 1;
    otherBuffList->mBuffers[0].mNumberChannels = 1;
    otherBuffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    otherBuffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    // audio unit new
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    // set format
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    status = AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
   status = AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));

    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    // enable record
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    // set callback
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));
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
    NSLog(@"result %d", result);
}



#pragma mark - callback

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    ViewController *vc = (__bridge ViewController *)inRefCon;
    AudioUnitRender(vc->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, vc->buffList);
    
    NSLog(@"size1 = %d", vc->buffList->mBuffers[0].mDataByteSize);
    [vc writePCMData:vc->buffList->mBuffers[0].mData size:vc->buffList->mBuffers[0].mDataByteSize];
    
    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    ViewController *vc = (__bridge ViewController *)inRefCon;
    NSLog(@"size2 = %d", ioData->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, vc->buffList->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}

#pragma mark - public methods

- (IBAction)startRecorder:(id)sender {
    [ self initRemoteIO];
    AudioOutputUnitStart(audioUnit);
}

- (IBAction)stopRecorder:(id)sender {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    AudioComponentInstanceDispose(audioUnit);
    
}

- (void)writePCMData:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/test.pcm"];
    if (!file) {
        file = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}






@end
