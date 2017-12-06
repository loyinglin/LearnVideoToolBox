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

@interface ViewController ()

// about ui
@property (nonatomic, strong) UIButton *mPlayButton;
@property (nonatomic, strong) UILabel *mTimeLabel;
@property (nonatomic , strong) NSDate *mStartDate;

// avfoudation
@property (nonatomic , strong) AVAsset *mAsset;
@property (nonatomic , strong) AVAssetReader *mReader;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderAudioTrackOutput;

// timer
@property (nonatomic , strong) CADisplayLink *mDisplayLink;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    self.mDisplayLink.frameInterval = 2; //FPS=30
    [self.mDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.mDisplayLink setPaused:YES];
    
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
    
    self.mReaderAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.mAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] outputSettings:outputSettings];
    self.mReaderAudioTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderAudioTrackOutput];
    
    return assetReader;
}

- (void)startPlay
{
    self.mReader = [self createAssetReader];
    
    if ([self.mReader startReading] == NO)
    {
        NSLog(@"Error reading from file at URL: %@", self.mAsset);
        return;
    }
    else {
        self.mStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
        [self.mDisplayLink setPaused:NO];
        NSLog(@"Start reading success.");
    }
}


- (void)displayLinkCallback:(CADisplayLink *)sender
{
    CMSampleBufferRef sampleBuffer = [self.mReaderAudioTrackOutput copyNextSampleBuffer];
    CMItemCount numberOfFrames = CMSampleBufferGetNumSamples(sampleBuffer); // corresponds to the number of CoreAudio audio frames
    AudioBufferList audioBufferList;
    size_t bufferListSizeNeededOut;
    CMBlockBufferRef blockBufferOut = nil;
    OSStatus err = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                           &bufferListSizeNeededOut,
                                                                           &audioBufferList,
                                                                           sizeof(audioBufferList),
                                                                           kCFAllocatorSystemDefault,
                                                                           kCFAllocatorSystemDefault,
                                                                           kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                           &blockBufferOut);
    
    if (blockBufferOut) {
//        [self.mGLView displayPixelBuffer:pixelBuffer];
    }
    else {
        NSLog(@"播放完成");
        [self.mDisplayLink setPaused:YES];
    }
    if (blockBufferOut != NULL) {
        self.mTimeLabel.text = [NSString stringWithFormat:@"播放%.f秒", [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSinceDate:self.mStartDate]];
        [self.mTimeLabel sizeToFit];
        
        CFRelease(blockBufferOut);
    }
}




- (IBAction)onClick:(UIButton *)sender {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
