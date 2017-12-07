//
//  LYPlayer.h
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/12/6.
//  Copyright © 2017年 loyinglin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

@class LYPlayer;
@protocol LYPlayerDelegate <NSObject>

- (AudioBufferList *)onRequestAudioData;
- (void)onPlayToEnd:(LYPlayer *)player;

@end


@interface LYPlayer : NSObject

@property (nonatomic, weak) id<LYPlayerDelegate> delegate;

- (void)prepareForPlayWithOutputASBD:(AudioStreamBasicDescription)outputFormat;

- (void)play;

- (double)getCurrentTime;

@end
