//
//  MTIGPUImageMTIImageInput.h
//  Pods
//
//  Created by jichuan on 2017/8/17.
//
//

@import GPUImage;
@import MetalPetal;
#import "MTIGPUImageMTIImageOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTIGPUImageMTIImageInput : GPUImageOutput

@property (nonatomic, strong, readonly) MTIContext *context;

@property (readonly, getter=isReadyForMorePixelBuffer) BOOL readyForMorePixelBuffer;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithContext:(MTIContext *)context NS_DESIGNATED_INITIALIZER;

- (BOOL)processImage:(MTIImage *)image;

- (BOOL)processImage:(MTIImage *)image frameTime:(CMTime)frameTime;

- (BOOL)processImage:(MTIImage *)image
           frameTime:(CMTime)frameTime
prepareForProcessing:(nullable void (^)(void))prepareForProcessing
          completion:(nullable void (^)(void))completion;

- (void)waitUntilReadyForMorePixelBuffer;

@end

@interface MTIGPUImageMTIImageInput (MTIGPUImageMTIImageOutput)

- (BOOL)processImage:(MTIImage *)image
           frameTime:(CMTime)frameTime
         imageOutput:(MTIGPUImageMTIImageOutput *)imageOutput
      outputCallback:(MTIGPUImageMTIImageOutputCallback)outputCallback
 outputCallbackQueue:(nullable dispatch_queue_t)outputCallbackQueue;

@end

NS_ASSUME_NONNULL_END

