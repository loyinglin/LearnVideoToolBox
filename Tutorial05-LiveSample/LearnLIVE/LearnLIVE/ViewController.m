//
//  ViewController.m
//  LearnLIVE
//
//  Created by loyinglin on 16/9/22.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import <LFLiveKit.h>

@interface ViewController ()
@property (nonatomic, strong) LFLiveSession *session;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self requestAccessForAudio];
    [self requestAccessForVideo];
}

- (void)requestAccessForVideo{
    __weak typeof(self) weakSelf = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf startSession];
                    });
                }
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            [weakSelf startSession];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            break;
        default:
            break;
    }
}

- (void)requestAccessForAudio{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:nil];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            break;
        default:
            break;
    }
}

- (void)startSession {
    if(!self.session){
        self.session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration]];
        self.session.preView = self.view;
    }
    [self.session setRunning:YES];
}


- (IBAction)onBeaty:(id)sender {
    self.session.beautyFace = !self.session.beautyFace;
}

- (IBAction)onCameraChange:(id)sender {
    if (self.session.captureDevicePosition == AVCaptureDevicePositionBack) {
        self.session.captureDevicePosition = AVCaptureDevicePositionFront;
    }
    else {
        self.session.captureDevicePosition = AVCaptureDevicePositionBack;
    }
}

- (IBAction)onStart:(UIButton *)sender {
    if ([sender.currentTitle isEqualToString:@"开始直播"]) {
        [sender setTitle:@"结束直播" forState:UIControlStateNormal];
        LFLiveStreamInfo *stream = [LFLiveStreamInfo new];
//        stream.url = @"rtmp://172.17.44.151:1935/rtmplive/abc";
        stream.url = @"rtmp://172.17.44.151:1935/hls/abc";
        [self.session startLive:stream];
    }
    else {
        [sender setTitle:@"开始直播" forState:UIControlStateNormal];
        [self.session stopLive];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
