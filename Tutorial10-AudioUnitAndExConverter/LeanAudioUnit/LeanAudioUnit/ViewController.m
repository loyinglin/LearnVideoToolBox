
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/10/26.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import "LYPlayer.h"


@interface ViewController () <LYPlayerDelegate>
@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) UILabel *mCurrentTimeLabel;
@property (nonatomic , strong) UIButton *mButton;
@property (nonatomic , strong) UIButton *mDecodeButton;
@property (nonatomic , strong) CADisplayLink *mDispalyLink;
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
    
    self.mDecodeButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.mLabel.frame) + 20, 100, 100, 100)];
    [self.mDecodeButton setTitle:@"play" forState:UIControlStateNormal];
    [self.mDecodeButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.mDecodeButton sizeToFit];
    [self.view addSubview:self.mDecodeButton];
    [self.mDecodeButton addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];
    
    
    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDispalyLink.frameInterval = 5;
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)onDecodeStart {
    self.mDecodeButton.hidden = YES;
    player = [[LYPlayer alloc] init];
    player.delegate = self;
    [player play];
}


- (void)updateFrame {
    if (player) {
        self.mCurrentTimeLabel.text = [NSString stringWithFormat:@"当前进度:%3d%%", (int)([player getCurrentTime] * 100)];
    }
}


#pragma mark - delegate

- (void)onPlayToEnd:(LYPlayer *)lyPlayer {
    [self updateFrame];
    player = nil;
    self.mDecodeButton.hidden = NO;
}






@end
