//
//  MTIGPUImageMTIImageOutput.h
//  Pods
//
//  Created by jichuan on 2017/8/17.
//
//

@import GPUImage;
@import MetalPetal;

NS_ASSUME_NONNULL_BEGIN

typedef void(^MTIGPUImageMTIImageOutputCallback)(MTIImage *image, CMTime frameTime);

@interface MTIGPUImageMTIImageOutput : NSObject <GPUImageInput>

@property (nonatomic, strong, readonly) MTIContext *context;

@property (nonatomic, copy) void (^endProcessingSignalHandler)(void);

@property (atomic) BOOL forcesGLFinish;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithContext:(MTIContext *)context NS_DESIGNATED_INITIALIZER;

- (void)setPixelBufferOutputCallback:(nullable MTIGPUImageMTIImageOutputCallback)callback
                               queue:(nullable dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
