//
//  XYQMovieObject.m
//  FFmpeg_Test
//
//  Created by mac on 16/7/11.
//  Copyright © 2016年 xiayuanquan. All rights reserved.
//

#import "XYQMovieObject.h"

@interface XYQMovieObject()
@property (nonatomic, copy) NSString *cruutenPath;
@end

@implementation XYQMovieObject
{
    AVFormatContext     *XYQFormatCtx;
    AVCodecContext      *XYQCodecCtx;
    AVFrame             *XYQFrame;
    AVStream            *stream;
    AVPacket            packet;
    AVPicture           picture;
    int                 videoStream;
    double              fps;
    BOOL                isReleaseResources;
    CVPixelBufferPoolRef pixelBufferPool;
}

#pragma mark ------------------------------------
#pragma mark  初始化
- (instancetype)initWithVideo:(NSString *)moviePath {
    
    if (!(self=[super init])) return nil;
    if ([self initializeResources:[moviePath UTF8String]]) {
        self.cruutenPath = [moviePath copy];
        return self;
    } else {
        return nil;
    }
}
- (BOOL)initializeResources:(const char *)filePath {
    
    isReleaseResources = NO;
    AVCodec *pCodec;
    // 注册所有解码器
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    // 打开视频文件
    if (avformat_open_input(&XYQFormatCtx, filePath, NULL, NULL) != 0) {
        NSLog(@"打开文件失败");
        goto initError;
    }
    // 检查数据流
    if (avformat_find_stream_info(XYQFormatCtx, NULL) < 0) {
        NSLog(@"检查数据流失败");
        goto initError;
    }
    // 根据数据流,找到第一个视频流
    if ((videoStream =  av_find_best_stream(XYQFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"没有找到第一个视频流");
        goto initError;
    }
    // 获取视频流的编解码上下文的指针
    stream      = XYQFormatCtx->streams[videoStream];
    XYQCodecCtx  = stream->codec;
#if DEBUG
    // 打印视频流的详细信息
    av_dump_format(XYQFormatCtx, videoStream, filePath, 0);
#endif
    if(stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
        fps = av_q2d(stream->avg_frame_rate);
    } else { fps = 30; }
    // 查找解码器
    pCodec = avcodec_find_decoder(XYQCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"没有找到解码器");
        goto initError;
    }
    // 打开解码器
    if(avcodec_open2(XYQCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"打开解码器失败");
        goto initError;
    }
    // 分配视频帧
    XYQFrame = av_frame_alloc();
    _outputWidth = XYQCodecCtx->width;
    _outputHeight = XYQCodecCtx->height;
    return YES;
initError:
    return NO;
}
- (void)seekTime:(double)seconds {
    AVRational timeBase = XYQFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(XYQFormatCtx,
                       videoStream,
                       0,
                       targetFrame,
                       targetFrame,
                       AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(XYQCodecCtx);
}
- (BOOL)stepFrame {
    int frameFinished = 0;
    while (!frameFinished && av_read_frame(XYQFormatCtx, &packet) >= 0) {
        if (packet.stream_index == videoStream) {
            avcodec_decode_video2(XYQCodecCtx,
                                  XYQFrame,
                                  &frameFinished,
                                  &packet);
        }
    }
    if (frameFinished == 0 && isReleaseResources == NO) {
        [self releaseResources];
    }
    return frameFinished != 0;
}

- (void)replaceTheResources:(NSString *)moviePath {
    if (!isReleaseResources) {
        [self releaseResources];
    }
    self.cruutenPath = [moviePath copy];
    [self initializeResources:[moviePath UTF8String]];
}
- (void)redialPaly {
    [self initializeResources:[self.cruutenPath UTF8String]];
}
#pragma mark ------------------------------------
#pragma mark  重写属性访问方法
-(void)setOutputWidth:(int)newValue {
    if (_outputWidth == newValue) return;
    _outputWidth = newValue;
}
-(void)setOutputHeight:(int)newValue {
    if (_outputHeight == newValue) return;
    _outputHeight = newValue;
}
-(UIImage *)currentImage {
    if (!XYQFrame->data[0]) return nil;
    return [self imageFromAVPicture];
}
-(double)duration {
    return (double)XYQFormatCtx->duration / AV_TIME_BASE;
}
- (double)currentTime {
    AVRational timeBase = XYQFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}
- (int)sourceWidth {
    return XYQCodecCtx->width;
}
- (int)sourceHeight {
    return XYQCodecCtx->height;
}
- (double)fps {
    return fps;
}
- (uint8_t *)getYUVdata {
    return XYQFrame->data[0];
}
#pragma mark --------------------------
#pragma mark - 内部方法
- (UIImage *)imageFromAVPicture
{
    avpicture_free(&picture);
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, _outputWidth, _outputHeight);
    struct SwsContext * imgConvertCtx = sws_getContext(XYQFrame->width,
                                                       XYQFrame->height,
                                                       AV_PIX_FMT_YUV420P,
                                                       _outputWidth,
                                                       _outputHeight,
                                                       AV_PIX_FMT_RGB24,
                                                       SWS_FAST_BILINEAR,
                                                       NULL,
                                                       NULL,
                                                       NULL);
    if(imgConvertCtx == nil) return nil;
    sws_scale(imgConvertCtx,
              XYQFrame->data,
              XYQFrame->linesize,
              0,
              XYQFrame->height,
              picture.data,
              picture.linesize);
    sws_freeContext(imgConvertCtx);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  picture.data[0],
                                  picture.linesize[0] * _outputHeight);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(_outputWidth,
                                       _outputHeight,
                                       8,
                                       24,
                                       picture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

- (CVPixelBufferRef)getCurrentCVPixelBuffer {
    AVFrame *frame = XYQFrame;
    if(!frame || !frame->data[0]){
        return nil;
    }
    
    CVReturn theError;
    if (!pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:frame->width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:frame->height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(frame->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
    }
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVImageBufferYCbCrMatrixKey, kCVAttachmentMode_ShouldPropagate);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    void* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, frame->data[0], bytePerRowY * frame->height);
    base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    memcpy(base, frame->data[1], bytesPerRowUV * frame->height / 2);
    
    uint32_t size = frame->linesize[1] * frame->height;
    uint8_t* dstData = malloc(2 * size);
    for (int i = 0; i < 2 * size; i++){
        if (i % 2 == 0){
            dstData[i] = frame->data[1][i/2];
        }else {
            dstData[i] = frame->data[2][i/2];
        }
    }
    memcpy(base, dstData, bytesPerRowUV * frame->height / 2);
    /*
     这里的前提是AVFrame中yuv的格式是nv12；
     但如果AVFrame是yuv420p，就需要把frame->data[1]和frame->data[2]的每一个字节交叉存储到pixelBUffer的plane1上，即把原来的uuuu和vvvv，保存成uvuvuvuv
     */
    
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}
#pragma mark --------------------------
#pragma mark - 释放资源
- (void)releaseResources {
    NSLog(@"释放资源");
//    SJLogFunc
    isReleaseResources = YES;
    // 释放RGB
    avpicture_free(&picture);
    // 释放frame
    av_packet_unref(&packet);
    // 释放YUV frame
    av_free(XYQFrame);
    // 关闭解码器
    if (XYQCodecCtx) avcodec_close(XYQCodecCtx);
    // 关闭文件
    if (XYQFormatCtx) avformat_close_input(&XYQFormatCtx);
    avformat_network_deinit();
}
@end
