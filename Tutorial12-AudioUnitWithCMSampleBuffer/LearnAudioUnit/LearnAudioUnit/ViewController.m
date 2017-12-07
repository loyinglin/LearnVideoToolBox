//
//  ViewController.m
//  LearnAudioUnit
//
//  Created by loyinglin on 2017/12/6.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import "LYPlayer.h"

@interface ViewController () <LYPlayerDelegate>

// about ui
@property (nonatomic, strong) UIButton *mPlayButton;
@property (nonatomic, strong) UILabel *mTimeLabel;
@property (nonatomic , strong) NSDate *mStartDate;

// avfoudation
@property (nonatomic , strong) AVAsset *mAsset;
@property (nonatomic , strong) AVAssetReader *mReader;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderAudioTrackOutput;
@property (nonatomic , assign) AudioStreamBasicDescription fileFormat;
// timer
@property (nonatomic , strong) CADisplayLink *mDisplayLink;

@property (nonatomic, strong) LYPlayer *mLYPlayer;
@property (nonatomic, assign) CMBlockBufferRef blockBufferOut;
@property (nonatomic, assign) AudioBufferList audioBufferList;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self loadAsset];
}


- (void)loadAsset {
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"mp4"] options:inputOptions];
    __weak typeof(self) weakSelf = self;
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus != AVKeyValueStatusLoaded)
            {
                NSLog(@"error %@", error);
                return;
            }
            weakSelf.mAsset = inputAsset;
            [weakSelf startPlay];
        });
    }];
}

- (AVAssetReader*)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.mAsset error:&error];
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    
    [outputSettings setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [outputSettings setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsBigEndianKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsFloatKey];
    [outputSettings setObject:@(YES) forKey:AVLinearPCMIsNonInterleaved];
    [outputSettings setObject:@(44100.0) forKey:AVSampleRateKey];
    [outputSettings setObject:@(1) forKey:AVNumberOfChannelsKey];
    
    AudioStreamBasicDescription inputFormat;
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mChannelsPerFrame = 1;
    inputFormat.mBytesPerPacket = 2;
    inputFormat.mBytesPerFrame = 2;
    inputFormat.mBitsPerChannel = 16;
    self.fileFormat = inputFormat;
    
    NSArray<AVAssetTrack *>* audioTracks = [self.mAsset tracksWithMediaType:AVMediaTypeAudio];
    self.mReaderAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTracks[0] outputSettings:outputSettings];
    self.mReaderAudioTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderAudioTrackOutput];
    
    NSArray *formatDesc = audioTracks[0].formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge_retained CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if(fmtDesc ) {
            [self printAudioStreamBasicDescription:*fmtDesc];
        }
    }
    
    
    
    return assetReader;
}

- (void)startPlay
{
    self.mReader = [self createAssetReader];
    self.mLYPlayer = [LYPlayer new];
    self.mLYPlayer.delegate = self;
    [self.mLYPlayer prepareForPlayWithOutputASBD:self.fileFormat];
    if ([self.mReader startReading] == NO)
    {
        NSLog(@"Error reading from file at URL: %@", self.mAsset);
        return;
    }
    else {
        self.mStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
        NSLog(@"Start reading success.");
        [self.mLYPlayer play];
    }
}




- (IBAction)onClick:(UIButton *)sender {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - delegate

- (AudioBufferList *)onRequestAudioData {
    CMSampleBufferRef sampleBuffer = [self.mReaderAudioTrackOutput copyNextSampleBuffer];
//    CMItemCount numberOfFrames = CMSampleBufferGetNumSamples(sampleBuffer); // corresponds to the number of CoreAudio audio frames
    size_t bufferListSizeNeededOut = 0;
    if (self.blockBufferOut != nil) {
        CFRelease(self.blockBufferOut);
    }
    if (!sampleBuffer) {
        return NULL;
    }
    OSStatus err = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                           &bufferListSizeNeededOut,
                                                                           &_audioBufferList,
                                                                           sizeof(self.audioBufferList),
                                                                           kCFAllocatorSystemDefault,
                                                                           kCFAllocatorSystemDefault,
                                                                           kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                           &_blockBufferOut);
    NSMutableData *data;
    if (err) {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer error: %d", err);
    }
    if (self.blockBufferOut != NULL) {
        self.mTimeLabel.text = [NSString stringWithFormat:@"播放%.f秒", [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSinceDate:self.mStartDate]];
        [self.mTimeLabel sizeToFit];
        
    }
    return &_audioBufferList;
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
