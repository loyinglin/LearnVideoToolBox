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
#import "LYOpenGLView.h"
#import "XYQMovieObject.h"

@interface ViewController () <LYPlayerDelegate>

// about ui
@property (nonatomic, strong) IBOutlet UIButton *mPlayButton;

// avfoudation
@property (nonatomic , strong) AVAsset *mAsset;
@property (nonatomic , strong) AVAssetReader *mReader;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderAudioTrackOutput;
@property (nonatomic , assign) AudioStreamBasicDescription fileFormat;


@property (nonatomic, strong) LYPlayer *mLYPlayer;
@property (nonatomic, assign) CMBlockBufferRef blockBufferOut;
@property (nonatomic, assign) AudioBufferList audioBufferList;


// gl
@property (nonatomic, strong) IBOutlet LYOpenGLView *mGLView;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderVideoTrackOutput;
@property (nonatomic , strong) CADisplayLink *mDisplayLink;

// 时间戳
@property (nonatomic, assign) long mAudioTimeStamp;
@property (nonatomic, assign) long mVideoTimeStamp;


@property (nonatomic, strong) XYQMovieObject *video;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.mGLView setupGL];
    [self.view addSubview:self.mGLView];
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    self.mDisplayLink.preferredFramesPerSecond = 20;
    [[self mDisplayLink] addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//    [[self mDisplayLink] setPaused:YES];
    
//    [self loadAsset];
    
    NSString *filePath;
//    filePath = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
    filePath = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"mp4"];
    self.video = [[XYQMovieObject alloc] initWithVideo:filePath];
    
    [self.video seekTime:0.0];
    
}


- (void)loadAsset {
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"test" withExtension:@"mov"] options:inputOptions];
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
        CFRelease(item);
    }
    
    outputSettings = [NSMutableDictionary dictionary];
    [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    self.mReaderVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.mAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
    self.mReaderVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderVideoTrackOutput];
    
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
        NSLog(@"Start reading success.");
        [self.mLYPlayer play];
        [self.mDisplayLink setPaused:NO];
        self.mAudioTimeStamp = self.mVideoTimeStamp = 0;
    }
}




- (IBAction)onClick:(UIButton *)sender {
    self.mPlayButton.enabled = NO;
    [self startPlay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - delegate

- (AudioBufferList *)onRequestAudioData {
    CMSampleBufferRef sampleBuffer = [self.mReaderAudioTrackOutput copyNextSampleBuffer];
    size_t bufferListSizeNeededOut = 0;
    if (self.blockBufferOut != NULL) {
        CFRelease(self.blockBufferOut);
        self.blockBufferOut = NULL;
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
    if (err) {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer error: %d", (int)err);
    }
    
    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    int timeStamp = (1000 * (int)presentationTimeStamp.value) / presentationTimeStamp.timescale;
    NSLog(@"audio timestamp %d", timeStamp);
    self.mAudioTimeStamp = timeStamp;
    
    CFRelease(sampleBuffer);
    
    return &_audioBufferList;
}


- (void)displayLinkCallback:(CADisplayLink *)sender {
//    if (self.mVideoTimeStamp < self.mAudioTimeStamp) {
//        [self renderVideo];
//    }
    [self readFrame];
}

- (void)readFrame {
    if (![self.video stepFrame]) {
        [self.mDisplayLink setPaused:YES];
        return;
    }
    
    CVPixelBufferRef pixelBuffer = [self.video getCurrentCVPixelBuffer];
    if (pixelBuffer) {
        self.mGLView.isFullYUVRange = YES;
        [self.mGLView displayPixelBuffer:pixelBuffer];
    }
    
    CFRelease(pixelBuffer);
    
}

- (CVPixelBufferRef)pixelBufferFromRGBData:(const unsigned char *)framedata width:(int)width height:(int)height
{
    NSDictionary *pixelAttributes = [NSDictionary dictionaryWithObject:@{} forKey:(NSString *)kCVPixelBufferIOSurfacePropertiesKey];
    CVPixelBufferRef pixelBuffer = NULL;
    
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          width,
                                          height,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef)pixelAttributes,
                                          &pixelBuffer);
    
    if (result != kCVReturnSuccess){
        NSLog(@"Unable to create cvpixelbuffer %d", result);
        return nil;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    if (yDestPlane == NULL)
    {
        NSLog(@"create yDestPlane failed. value is NULL");
        return nil;
    }
    memcpy(yDestPlane, framedata, width * height * 4);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}



static OSType KVideoPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
- (CVPixelBufferRef)getCVBufferFromData:(const unsigned char*)buffer toYUVPixelBufferWithWidth:(size_t)w Height:(size_t)h {
    NSDictionary *pixelBufferAttributes = @{(NSString *)kCVImageBufferYCbCrMatrixKey:(NSString *)kCVImageBufferYCbCrMatrix_ITU_R_601_4};
    CVPixelBufferRef pixelBuffer;
    CVPixelBufferCreate(NULL, w, h, KVideoPixelFormatType, (__bridge CFDictionaryRef)(pixelBufferAttributes), &pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t d = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    const unsigned char* src = buffer;
    unsigned char* dst = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    for (unsigned int rIdx = 0; rIdx < h; ++rIdx, dst += d, src += w) {
        memcpy(dst, src, w);
    }
    d = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    dst = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    h = h >> 1;
    for (unsigned int rIdx = 0; rIdx < h; ++rIdx, dst += d, src += w) {
        memcpy(dst, src, w);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return pixelBuffer;
}

- (void)renderVideo {
    CMSampleBufferRef videoSamepleBuffer = [self.mReaderVideoTrackOutput copyNextSampleBuffer];
    if (!videoSamepleBuffer) {
        return ;
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoSamepleBuffer);
    if (pixelBuffer) {
        [self.mGLView displayPixelBuffer:pixelBuffer];
        
        
        CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(videoSamepleBuffer);
        int timeStamp = (1000 * (int)presentationTimeStamp.value) / presentationTimeStamp.timescale;
        NSLog(@"video timestamp %d", timeStamp);
        self.mVideoTimeStamp = timeStamp;
    }
    
    CFRelease(videoSamepleBuffer);
}


- (void)onPlayToEnd:(LYPlayer *)player {
    self.mPlayButton.enabled = YES;
    self.mDisplayLink.paused = YES;
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
