//
//  MTIGPUImageMTIImageOutput.m
//  Pods
//
//  Created by jichuan on 2017/8/17.
//
//

#import "MTIGPUImageMTIImageOutput.h"

static NSInteger MTIGPUImageMTIImageOutputPixelBufferPoolMinimumBufferCount = 60;

static void MTIGPUImageMTIImageOutputCVPixelBufferPoolIsOutOfBuffer(MTIGPUImageMTIImageOutput *output)
{
#if DEBUG
    NSLog(@"%@: Pool is out of buffers. Create a symbolic breakpoint of MTIGPUImageMTIImageOutputCVPixelBufferPoolIsOutOfBuffer to debug.", output);
#endif
}

@interface MTIGPUImageMTIImageOutput ()
@property (atomic, copy) MTIGPUImageMTIImageOutputCallback callback;
@property (atomic, strong) dispatch_queue_t callbackQueue;
@property (atomic) GPUImageRotationMode inputRotation;
@property (atomic) GPUImageFramebuffer *inputFrameBuffer;
@property (atomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic) CGSize inputSize;
@end

@implementation MTIGPUImageMTIImageOutput {
    GLProgram *filterProgram;
    GLuint frameBuffer;
    GLint filterPositionAttribute;
    GLint filterTextureCoordinateAttribute;
    GLint filterInputTextureUniform;
}

- (void)dealloc
{
    if (self.pixelBufferPool) {
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        glDeleteFramebuffers(1, &frameBuffer);
    });
}

- (instancetype)initWithContext:(MTIContext *)context
{
    self = [super init];
    if (self) {
        _context = context;
        self.inputRotation = kGPUImageNoRotation;
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];
            
            GLuint gl_frameBuffer = 0;
            glGenFramebuffers(1, &gl_frameBuffer);
            glBindFramebuffer(GL_FRAMEBUFFER, gl_frameBuffer);
            frameBuffer = gl_frameBuffer;
            
            filterProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
            
            if (!filterProgram.initialized) {
                [filterProgram addAttribute:@"position"];
                [filterProgram addAttribute:@"inputTextureCoordinate"];
                
                if (![filterProgram link]) {
                    NSString *progLog = [filterProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [filterProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [filterProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    filterProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            
            filterPositionAttribute = [filterProgram attributeIndex:@"position"];
            filterTextureCoordinateAttribute = [filterProgram attributeIndex:@"inputTextureCoordinate"];
            filterInputTextureUniform = [filterProgram uniformIndex:@"inputImageTexture"];
            
            [GPUImageContext setActiveShaderProgram:filterProgram];
            
            glEnableVertexAttribArray(filterPositionAttribute);
            glEnableVertexAttribArray(filterTextureCoordinateAttribute);
        });
        
    }
    return self;
}

- (void)setPixelBufferOutputCallback:(MTIGPUImageMTIImageOutputCallback)callback queue:(dispatch_queue_t)queue
{
    self.callback = callback;
    self.callbackQueue = queue;
}

- (void)createPixelBufferPoolWithPixelBufferSizeIfNeeded:(CGSize)size
{
    if (self.pixelBufferPool) {
        NSDictionary *pixelBufferPoolAttributes = (__bridge NSDictionary *)CVPixelBufferPoolGetPixelBufferAttributes(self.pixelBufferPool);
        if ([pixelBufferPoolAttributes[(id)kCVPixelBufferWidthKey] integerValue] == (NSInteger)size.width &&
            [pixelBufferPoolAttributes[(id)kCVPixelBufferHeightKey] integerValue] == (NSInteger)size.height) {
            return;
        }
    }
    
    if (self.pixelBufferPool) {
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
    
    CVPixelBufferPoolRef outputPool = NULL;
    NSDictionary *sourcePixelBufferOptions = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                (id)kCVPixelBufferWidthKey : @(size.width),
                                                (id)kCVPixelBufferHeightKey : @(size.height),
                                                (id)kCVPixelFormatOpenGLESCompatibility : @(YES),
                                                (id)kCVPixelBufferIOSurfacePropertiesKey : @{ } };
    NSDictionary *pixelBufferPoolOptions = @{ (id)kCVPixelBufferPoolMinimumBufferCountKey : @(MTIGPUImageMTIImageOutputPixelBufferPoolMinimumBufferCount) };
    CVReturn ret = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                           (__bridge CFDictionaryRef)(pixelBufferPoolOptions),
                                           (__bridge CFDictionaryRef)(sourcePixelBufferOptions),
                                           &outputPool);
    NSAssert(ret == kCVReturnSuccess, @"CVPixelBufferPoolCreate Failed ()", @(ret));
    self.pixelBufferPool = outputPool;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates
{
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    glViewport(0, 0, (GLsizei)self.inputSize.width, (GLsizei)self.inputSize.height);
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, self.inputFrameBuffer.texture);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex
{
    if (!self.inputFrameBuffer) {
        return;
    }
    
    [GPUImageContext useImageProcessingContext];
    
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *auxAttributes = @{ (id)kCVPixelBufferPoolAllocationThresholdKey : @(MTIGPUImageMTIImageOutputPixelBufferPoolMinimumBufferCount) };
    CVReturn ret = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,
                                                                       self.pixelBufferPool,
                                                                       (__bridge CFDictionaryRef)(auxAttributes),
                                                                       &pixelBuffer);
    if (ret != kCVReturnSuccess || pixelBuffer == NULL) {
        pixelBuffer = NULL;
        if (ret == kCVReturnWouldExceedAllocationThreshold) {
            CVOpenGLESTextureCacheFlush([GPUImageContext sharedImageProcessingContext].coreVideoTextureCache, 0);
            MTIGPUImageMTIImageOutputCVPixelBufferPoolIsOutOfBuffer(self);
        } else {
            NSAssert(NO, @"%@: Error at CVPixelBufferPoolCreatePixelBuffer %@", self, @(ret));
        }
        [self.inputFrameBuffer unlock];
        return;
    }
    
    id<MTLTexture> metalTexture = nil;
#if COREVIDEO_SUPPORTS_METAL
    CVMetalTextureRef coreVideoMetalTexture = NULL;
    ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                    self.context.coreVideoTextureCache,
                                                    pixelBuffer,
                                                    NULL,
                                                    MTLPixelFormatBGRA8Unorm,
                                                    (size_t)self.inputSize.width,
                                                    (size_t)self.inputSize.height,
                                                    0,
                                                    &coreVideoMetalTexture);
    NSAssert(ret == kCVReturnSuccess, @"CVMetalTextureCacheCreateTextureFromImage failed ()", @(ret));
    if (ret == kCVReturnSuccess) {
        metalTexture = CVMetalTextureGetTexture(coreVideoMetalTexture);
    }
#endif
    
    CVOpenGLESTextureRef coreVideoOpenGLESTexture = NULL;
    ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       [GPUImageContext sharedImageProcessingContext].coreVideoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RGBA,
                                                       (GLsizei)self.inputSize.width,
                                                       (GLsizei)self.inputSize.height,
                                                       GL_BGRA,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &coreVideoOpenGLESTexture);
    NSAssert(ret == kCVReturnSuccess, @"CVOpenGLESTextureCacheCreateTextureFromImage failed ()", @(ret));
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(coreVideoOpenGLESTexture));
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(coreVideoOpenGLESTexture), 0);
    
    static const GLfloat vertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    [self renderToTextureWithVertices:vertices textureCoordinates:[GPUImageFilter textureCoordinatesForRotation:self.inputRotation]];
    
    if (self.forcesGLFinish) {
        glFinish();
    } else {
        glFlush();
    }
    
    [self.inputFrameBuffer unlock];
    
#if COREVIDEO_SUPPORTS_METAL
    if (coreVideoMetalTexture) {
        CFRelease(coreVideoMetalTexture);
    }
    CVMetalTextureCacheFlush(self.context.coreVideoTextureCache, 0);
#endif
    
    if (coreVideoOpenGLESTexture) {
        CFRelease(coreVideoOpenGLESTexture);
    }
    
    MTIImage *image = nil;
    if (metalTexture) {
        image = [[MTIImage alloc] initWithTexture:metalTexture];
    } else {
        image = [[MTIImage alloc] initWithCVPixelBuffer:pixelBuffer];
    }
    CVPixelBufferRelease(pixelBuffer);
    
    MTIGPUImageMTIImageOutputCallback callback = self.callback;
    dispatch_queue_t callbackQueue = self.callbackQueue;
    if (callback) {
        if (callbackQueue) {
            dispatch_async(callbackQueue, ^{
                callback(image, frameTime);
            });
        } else {
            callback(image, frameTime);
        }
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex
{
    self.inputFrameBuffer = newInputFramebuffer;
    [self.inputFrameBuffer lock];
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex
{
    self.inputSize = newSize;
    [self createPixelBufferPoolWithPixelBufferSizeIfNeeded:newSize];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex
{
    self.inputRotation = newInputRotation;
}

- (CGSize)maximumOutputSize
{
    return self.inputSize;
}

- (void)endProcessing
{
    if (self.endProcessingSignalHandler) {
        self.endProcessingSignalHandler();
    }
}

- (BOOL)shouldIgnoreUpdatesToThisTarget
{
    return NO;
}

- (BOOL)enabled
{
    return YES;
}

- (BOOL)wantsMonochromeInput
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue
{
    
}


@end
