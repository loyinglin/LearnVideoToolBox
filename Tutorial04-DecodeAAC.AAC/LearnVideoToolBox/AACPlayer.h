//
//  AACPlayer.h
//  LearnVideoToolBox
//
//  Created by loyinglin on 16/9/9.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACPlayer : NSObject

- (void)play;

- (double)getCurrentTime;


@end
