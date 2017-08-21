//
//  MTIGPUImageFilter.h
//  Pods
//
//  Created by YuAo on 11/08/2017.
//
//

@import GPUImage;
@import MetalPetal;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT MTIContext * MTIGPUImageGetMetalPetalContext(void);

@interface MTIGPUImageFilter : GPUImageFilter

@property (atomic, copy, nullable) MTIImage *(^processor)(MTIImage *inputImage);

@end

#warning Todo: @implementation
@interface MTIGPUImageTwoInputFilter : GPUImageTwoInputFilter

@property (atomic, copy, nullable) MTIImage *(^processor)(MTIImage *firstInputImage, MTIImage *secondInputImage);

@end

NS_ASSUME_NONNULL_END
