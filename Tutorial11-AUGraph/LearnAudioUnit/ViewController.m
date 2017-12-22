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

// 这里的InputBus和OutputBus 是针对RemoteI/O而言
#define REMOTE_IO_UNIT_INPUT_BUS 1
#define REMOTE_IO_UNIT_OUTPUT_BUS 0

// mix的bus
#define MIX_UNIT_OUTPUT_BUS 0
#define MIX_UNIT_INPUT_BUS0 0
#define MIX_UNIT_INPUT_BUS1 1

#define CONST_BUFFER_SIZE 2048*2*10

#define startTag 10
#define stopTag 20

@implementation ViewController
{
    AudioUnit outputUnit;
    AudioUnit mixUnit;
    AudioBufferList *buffList;
    
    NSInputStream *inputSteam;
    Byte *buffer;
    
    AUGraph auGraph;
    AudioStreamBasicDescription audioFormat;
}


- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)start:(UIView *)sender {
    sender.hidden = YES;
    [[self.view viewWithTag:stopTag] setHidden:NO];
    
    [ self initAudioUnit];
}

- (IBAction)stop:(UIView *)sender {
    sender.hidden = YES;
    [[self.view viewWithTag:startTag] setHidden:NO];
    
    CheckError(AUGraphStop(auGraph), "stop graph fail");
    CheckError(AUGraphUninitialize(auGraph), "uninit graph fail");
    
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    
    [inputSteam close];
    CheckError(DisposeAUGraph(auGraph), "dispose fail");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initBufferAndFormat {
    // open file
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam) {
        NSLog(@"打开文件失败 %@", url);
    }
    else {
        [inputSteam open];
    }
    
    // audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.02 error:nil];
    
    // buffer
    uint32_t numberBuffers = 1;
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = numberBuffers;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    buffer = malloc(CONST_BUFFER_SIZE);
    
    
    // audio format
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBitsPerChannel = 16;
}

- (void)initAudioUnit {
    [self initBufferAndFormat];
    
    // augraph
    CheckError(NewAUGraph(&auGraph), "NewAUGraph error");
    CheckError(AUGraphOpen(auGraph), "open graph fail");
    
    // output audio unit
    AudioComponentDescription outputAudioDesc;
    outputAudioDesc.componentType = kAudioUnitType_Output;
    outputAudioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputAudioDesc.componentFlags = 0;
    outputAudioDesc.componentFlagsMask = 0;
    AUNode outputNode;
    CheckError(AUGraphAddNode(auGraph, &outputAudioDesc, &outputNode), "add node fail");
    CheckError(AUGraphNodeInfo(auGraph, outputNode, NULL, &outputUnit), "get audio unit fail");
    
    // mix audio unit
    AudioComponentDescription mixAudioDesc;
    mixAudioDesc.componentType = kAudioUnitType_Mixer;
    mixAudioDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixAudioDesc.componentFlags = 0;
    mixAudioDesc.componentFlagsMask = 0;
    AUNode mixNode;
    CheckError(AUGraphAddNode(auGraph, &mixAudioDesc, &mixNode), "add node fail");
    CheckError(AUGraphNodeInfo(auGraph, mixNode, NULL, &mixUnit), "get audio unit fail");
    
    // connect
    CheckError(AUGraphConnectNodeInput(auGraph, mixNode, MIX_UNIT_OUTPUT_BUS, outputNode, REMOTE_IO_UNIT_OUTPUT_BUS), "connect fail"); // 这里很好奇为何mixUnit和outputUnit的bus都是outputBus，而不是inputBus？mixUnit就只有一个outputBus；这里是把Mix的输出，作为I/O Unit的element 0的输入

    // set format
    CheckError(AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, REMOTE_IO_UNIT_INPUT_BUS, &audioFormat, sizeof(audioFormat)), "set format fail");
    CheckError(AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, REMOTE_IO_UNIT_OUTPUT_BUS, &audioFormat, sizeof(audioFormat)), "set fomat fail");
    
    // enable record
    UInt32 flag = 1;
    CheckError(AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, REMOTE_IO_UNIT_INPUT_BUS, &flag,sizeof(flag)), "set flag fail");
    
    [self setupMixUnit];
    
    // set callback
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    
//    CheckError(AUGraphSetNodeInputCallback(auGraph, outputNode, INPUT_BUS, &recordCallback), "record callback set fail");  // 这个不行，因为scope不一致
    CheckError(AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, REMOTE_IO_UNIT_INPUT_BUS, &recordCallback, sizeof(recordCallback)), "set property fail");

    CheckError(AUGraphInitialize(auGraph), "init augraph fail");
    CheckError(AUGraphStart(auGraph), "start graph fail");
}

- (void)setupMixUnit {
    // setup mix unit
    UInt32 busCount = 2;
    CheckError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS0, &busCount, sizeof(UInt32)), "set property fail");
    
    UInt32 size = sizeof(UInt32);
    CheckError(AudioUnitGetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS0, &busCount, &size), "get property fail");
    CheckError(AudioUnitGetProperty(outputUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Global, REMOTE_IO_UNIT_INPUT_BUS, &busCount, &size), "get property fail");
    
    AURenderCallbackStruct callback0;
    callback0.inputProc = mixCallback0;
    callback0.inputProcRefCon = (__bridge void *)self;
    CheckError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS0, &callback0, sizeof(AURenderCallbackStruct)), "add mix callback fail");
    CheckError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS0, &audioFormat, sizeof(AudioStreamBasicDescription)), "set mix format fail");
    
    
    AURenderCallbackStruct callback1;
    callback1.inputProc = mixCallback1;
    callback1.inputProcRefCon = (__bridge void *)self;
    CheckError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS1, &callback1, sizeof(AURenderCallbackStruct)), "add mix callback fail");
    CheckError(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, MIX_UNIT_INPUT_BUS1, &audioFormat, sizeof(AudioStreamBasicDescription)), "set mix format fail");
}


#pragma mark - callback
static OSStatus mixCallback0(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    ViewController *vc = (__bridge ViewController *)inRefCon;
    
    NSInteger bytes = CONST_BUFFER_SIZE < ioData->mBuffers[0].mDataByteSize * 2 ? CONST_BUFFER_SIZE : ioData->mBuffers[0].mDataByteSize * 2; //
    bytes = [vc->inputSteam read:vc->buffer maxLength:bytes];
    
    for (int i = 0; i < bytes; ++i) {
        ((Byte*)ioData->mBuffers[0].mData)[i/2] = vc->buffer[i];
    }
    ioData->mBuffers[1].mDataByteSize = (UInt32)bytes / 2;
    
    return noErr;
}

static OSStatus mixCallback1(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    ViewController *vc = (__bridge ViewController *)inRefCon;
    memcpy(ioData->mBuffers[0].mData, vc->buffList->mBuffers[0].mData, vc->buffList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = vc->buffList->mBuffers[0].mDataByteSize;
    
    return noErr;
}

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    ViewController *vc = (__bridge ViewController *)inRefCon;
    vc->buffList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(vc->outputUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, vc->buffList);
    if (status != noErr) {
        NSLog(@"AudioUnitRender error:%d", status);
    }
    
    NSLog(@"RecordCallback size = %d", vc->buffList->mBuffers[0].mDataByteSize);
    [vc writePCMData:vc->buffList->mBuffers[0].mData size:vc->buffList->mBuffers[0].mDataByteSize];
    
    return noErr;
}


- (void)writePCMData:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
    if (!file) {
        file = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}

static void CheckError(OSStatus error, const char *operation)
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
