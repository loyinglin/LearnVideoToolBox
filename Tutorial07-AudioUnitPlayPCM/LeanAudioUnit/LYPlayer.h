//
//  LYPlayer.h
//  LeanAudioUnit
//
//  Created by loyinglin on 2017/9/13.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LYPlayer;
@protocol LYPlayerDelegate <NSObject>

- (void)onPlayToEnd:(LYPlayer *)player;

@end


@interface LYPlayer : NSObject

@property (nonatomic, weak) id<LYPlayerDelegate> delegate;

- (void)play;

- (double)getCurrentTime;

@end
