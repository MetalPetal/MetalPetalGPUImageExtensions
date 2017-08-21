//
//  MTIGPUImageFilter.m
//  Pods
//
//  Created by YuAo on 11/08/2017.
//
//

#import "MTIGPUImageFilter.h"

MTIContext * MTIGPUImageGetMetalPetalContext(void) {
    static MTIContext * _MTIGPUImageMetalPetalContext = nil;
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = nil;
            _MTIGPUImageMetalPetalContext = [[MTIContext alloc] initWithDevice:MTLCreateSystemDefaultDevice() error:&error];
#if DEBUG
            if (error) {
                NSLog(@"MTIGPUImageGetMetalPetalContext Error: %@", error.localizedDescription);
            }
#endif
        });
    });
    return _MTIGPUImageMetalPetalContext;
}

@interface MTIGPUImageFilter ()

@property (nonatomic) CGSize outputImageSize;

@end

@implementation MTIGPUImageFilter

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates
{
    if (!self.processor) {
        [super renderToTextureWithVertices:vertices textureCoordinates:textureCoordinates];
    } else {
        MTIContext *context = MTIGPUImageGetMetalPetalContext();
        
        if (self.preventRendering) {
            [firstInputFramebuffer unlock];
            return;
        }
        
        glFlush();
        
        CVPixelBufferRef pixelBuffer = firstInputFramebuffer.pixelBuffer;
        MTIImage *inputImage = [[MTIImage alloc] initWithCVPixelBuffer:pixelBuffer];
        MTIImage *outputImage = self.processor(inputImage);
        self.outputImageSize = outputImage.extent.size;
        
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
        [outputFramebuffer activateFramebuffer];
        
        if (usingNextFrameForImageCapture) {
            [outputFramebuffer lock];
        }
        
        NSError *error = nil;
        [context renderImage:outputImage toCVPixelBuffer:outputFramebuffer.pixelBuffer error:&error];
        NSAssert(error == nil, error.localizedDescription);
        
        [firstInputFramebuffer unlock];
        
        if (usingNextFrameForImageCapture) {
            dispatch_semaphore_signal(imageCaptureSemaphore);
        }
    }
}

- (CGSize)outputFrameSize
{
    if (!self.processor) {
        return [super outputFrameSize];
    } else {
        return self.outputImageSize;
    }
}

- (CGSize)sizeOfFBO
{
    if (!self.processor) {
        return [super sizeOfFBO];
    } else {
        return self.outputImageSize;
    }
}

@end


@interface MTIGPUImageTwoInputFilter ()

@property (nonatomic) CGSize outputImageSize;

@end

@implementation MTIGPUImageTwoInputFilter

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates
{
    if (!self.processor) {
        [super renderToTextureWithVertices:vertices textureCoordinates:textureCoordinates];
    } else {
        MTIContext *context = MTIGPUImageGetMetalPetalContext();
        
        if (self.preventRendering) {
            [firstInputFramebuffer unlock];
            [secondInputFramebuffer unlock];
            return;
        }
        
        glFlush();
        
        CVPixelBufferRef firstPixelBuffer = firstInputFramebuffer.pixelBuffer;
        CVPixelBufferRef secondPixelBuffer = secondInputFramebuffer.pixelBuffer;
        MTIImage *firstInputImage = [[MTIImage alloc] initWithCVPixelBuffer:firstPixelBuffer];
        MTIImage *secondInputImage = [[MTIImage alloc] initWithCVPixelBuffer:secondPixelBuffer];
        MTIImage *outputImage = self.processor(firstInputImage, secondInputImage);
        self.outputImageSize = outputImage.extent.size;
        
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
        [outputFramebuffer activateFramebuffer];
        
        if (usingNextFrameForImageCapture) {
            [outputFramebuffer lock];
        }
        
        NSError *error = nil;
        [context renderImage:outputImage toCVPixelBuffer:outputFramebuffer.pixelBuffer error:&error];
        NSAssert(error == nil, error.localizedDescription);
     
        [firstInputFramebuffer unlock];
        [secondInputFramebuffer unlock];
        
        if (usingNextFrameForImageCapture) {
            dispatch_semaphore_signal(imageCaptureSemaphore);
        }
    }
}

//- (CGSize)outputFrameSize
//{
//    if (!self.processor) {
//        return [super outputFrameSize];
//    } else {
//        return self.outputImageSize;
//    }
//}
//
//- (CGSize)sizeOfFBO
//{
//    if (!self.processor) {
//        return [super sizeOfFBO];
//    } else {
//        return self.outputImageSize;
//    }
//}

@end



