
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/9/13.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import "LYPlayer.h"


@interface ViewController () <LYPlayerDelegate>
@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) UILabel *mCurrentTimeLabel;
@property (nonatomic , strong) UIButton *mPlayBtn;
@end

@implementation ViewController
{
    LYPlayer *player;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 100)];
    self.mLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mLabel];
    self.mLabel.text = @"测试ACC/m4a/mp3播放";
    [self.mLabel sizeToFit];
    
    self.mCurrentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, 200, 100)];
    self.mCurrentTimeLabel.textColor = [UIColor grayColor];
    [self.view addSubview:self.mCurrentTimeLabel];
    
    self.mPlayBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.mLabel.frame) + 20, 100, 100, 100)];
    [self.mPlayBtn setTitle:@"play" forState:UIControlStateNormal];
    [self.mPlayBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.mPlayBtn sizeToFit];
    [self.view addSubview:self.mPlayBtn];
    [self.mPlayBtn addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];
    
    

    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)onDecodeStart {
    self.mPlayBtn.hidden = YES;
    player = [[LYPlayer alloc] init];
    player.delegate = self;
    [player play];
}

#pragma mark - delegate

- (void)onPlayToEnd:(LYPlayer *)lyPlayer {
    [self mPlayBtn];
    player = nil;
    self.mPlayBtn.hidden = NO;
}






@end
