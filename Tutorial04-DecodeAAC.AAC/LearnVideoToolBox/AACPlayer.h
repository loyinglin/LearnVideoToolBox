//
//  AACPlayer.h
//  LearnVideoToolBox
//
//  Created by 林伟池 on 16/9/9.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACPlayer : NSObject

- (void)play;

- (double)getCurrentTime;


@end
