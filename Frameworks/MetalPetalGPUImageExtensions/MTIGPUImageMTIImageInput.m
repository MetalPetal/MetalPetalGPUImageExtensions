//
//  MTIGPUImageMTIImageInput.m
//  Pods
//
//  Created by jichuan on 2017/8/17.
//
//

#import "MTIGPUImageMTIImageInput.h"

static void MTIGPUImageMTIImageInputCheckGLErrors()
{
    GLenum error;
    BOOL hadError = NO;
    do {
        error = glGetError();
        if (error != 0) {
            NSLog(@"OpenGL error: %@", @(error));
            hadError = YES;
        }
    } while (error != 0);
    NSCAssert(!hadError, @"OpenGL Error");
}

@implementation MTIGPUImageMTIImageInput {
    dispatch_group_t frameProcessingGroup;
    BOOL applicationIsForeground;
    GLProgram *passthroughProgram;
    GLint filterPositionAttribute;
    GLint filterTextureCoordinateAttribute;
    GLint filterInputTextureUniform;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithContext:(MTIContext *)context
{
    self = [super init];
    if (self) {
        _context = context;
        frameProcessingGroup = dispatch_group_create();
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationWillBecomeActive:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        UIApplicationState applicationState = [UIApplication sharedApplication].applicationState;
        if (applicationState == UIApplicationStateActive || UIApplicationStateInactive) {
            applicationIsForeground = YES;
        } else {
            applicationIsForeground = NO;
        }
    }
    return self;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    @synchronized (self) {
        applicationIsForeground = NO;
    }
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        glFinish();
    });
}

- (void)applicationWillBecomeActive:(NSNotification *)notification
{
    @synchronized (self) {
        applicationIsForeground = YES;
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    @synchronized (self) {
        applicationIsForeground = YES;
    }
}

- (BOOL)processImage:(MTIImage *)image
{
    return [self processImage:image frameTime:kCMTimeIndefinite];
}

- (BOOL)processImage:(MTIImage *)image frameTime:(CMTime)frameTime
{
    return [self processImage:image frameTime:frameTime prepareForProcessing:NULL completion:NULL];
}

- (BOOL)processImage:(MTIImage *)image frameTime:(CMTime)frameTime prepareForProcessing:(void (^)(void))prepareForProcessing completion:(void (^)(void))completion
{
    NSParameterAssert(image);
    
    @synchronized (self) {
        
        if (!applicationIsForeground) {
            return NO;
        }
        
        if (!self.isReadyForMorePixelBuffer) {
            return NO;
        }
        
        dispatch_group_enter(frameProcessingGroup);
        
        runAsynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];
            
            if (prepareForProcessing) {
                prepareForProcessing();
            }
            
            outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(image.extent.size.width, image.extent.size.height) textureOptions:self.outputTextureOptions onlyTexture:NO];
            
            CVPixelBufferRef pixelBuffer = outputFramebuffer.pixelBuffer;
            
            CVOpenGLESTextureRef coreVideoOpenGLESTexture = NULL;
            CVReturn ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                        [GPUImageContext sharedImageProcessingContext].coreVideoTextureCache,
                                                                        pixelBuffer,
                                                                        NULL,
                                                                        GL_TEXTURE_2D,
                                                                        GL_RGBA,
                                                                        (GLsizei)image.extent.size.width,
                                                                        (GLsizei)image.extent.size.height,
                                                                        GL_BGRA,
                                                                        GL_UNSIGNED_BYTE,
                                                                        0,
                                                                        &coreVideoOpenGLESTexture);
            NSAssert(ret == kCVReturnSuccess, @"CVOpenGLESTextureCacheCreateTextureFromImage failed ()", @(ret));
            if (ret == kCVReturnSuccess && coreVideoOpenGLESTexture) {
                NSError *error = nil;
                [self.context renderImage:image toCVPixelBuffer:pixelBuffer error:&error];
                if (error) {
                    if (coreVideoOpenGLESTexture) {
                        CFRelease(coreVideoOpenGLESTexture);
                    }
                    NSAssert(NO, @"Render MTIImage to CVPixelBuffer failed: %@", error.localizedDescription);
                    return;
                }
                
                if (!passthroughProgram) {
                    [self setupPassthroughProgram];
                }
                
                [outputFramebuffer activateFramebuffer];
                
                [GPUImageContext setActiveShaderProgram:passthroughProgram];
                
                glActiveTexture(GL_TEXTURE4);
                glBindTexture(CVOpenGLESTextureGetTarget(coreVideoOpenGLESTexture), CVOpenGLESTextureGetName(coreVideoOpenGLESTexture));
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                
                glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
                
                static const GLfloat vertices[] = {
                    -1.0f, -1.0f,
                    1.0f, -1.0f,
                    -1.0f,  1.0f,
                    1.0f,  1.0f,
                };
                
                glUniform1i(filterInputTextureUniform, 4);
                
                glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
                glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation]);
                
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
                
                MTIGPUImageMTIImageInputCheckGLErrors();
                
                [self informTargetsAboutNewFrameAtTime:frameTime];
                
                [outputFramebuffer unlock];
            }
            
            if (coreVideoOpenGLESTexture) {
                CFRelease(coreVideoOpenGLESTexture);
            }
            
            if (completion) {
                completion();
            }
            
            dispatch_group_leave(frameProcessingGroup);
        });
        
        return YES;
    }
}

- (void)setupPassthroughProgram
{
    passthroughProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
    
    if (!passthroughProgram.initialized) {
        [passthroughProgram addAttribute:@"position"];
        [passthroughProgram addAttribute:@"inputTextureCoordinate"];
        
        if (![passthroughProgram link]) {
            NSString *progLog = [passthroughProgram programLog];
            NSLog(@"Program link log: %@", progLog);
            NSString *fragLog = [passthroughProgram fragmentShaderLog];
            NSLog(@"Fragment shader compile log: %@", fragLog);
            NSString *vertLog = [passthroughProgram vertexShaderLog];
            NSLog(@"Vertex shader compile log: %@", vertLog);
            passthroughProgram = nil;
            NSAssert(NO, @"Filter shader link failed");
        }
    }
    
    filterPositionAttribute = [passthroughProgram attributeIndex:@"position"];
    filterTextureCoordinateAttribute = [passthroughProgram attributeIndex:@"inputTextureCoordinate"];
    filterInputTextureUniform = [passthroughProgram uniformIndex:@"inputImageTexture"];
    
    [GPUImageContext setActiveShaderProgram:passthroughProgram];
    
    glEnableVertexAttribArray(filterPositionAttribute);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime
{
    for (id<GPUImageInput> currentTarget in targets) {
        if ([currentTarget enabled]) {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            if (currentTarget != self.targetToIgnoreForUpdates) {
                [currentTarget setInputSize:outputFramebuffer.size atIndex:targetTextureIndex];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
                [currentTarget newFrameReadyAtTime:frameTime atIndex:targetTextureIndex];
            } else {
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            }
        }
    }
}

- (BOOL)isReadyForMorePixelBuffer
{
    if (dispatch_group_wait(frameProcessingGroup, DISPATCH_TIME_NOW) != 0) {
        return NO;
    } else {
        return YES;
    }
}

- (void)waitUntilReadyForMorePixelBuffer
{
    dispatch_group_wait(frameProcessingGroup, DISPATCH_TIME_FOREVER);
}

@end


@implementation MTIGPUImageMTIImageInput (MTIGPUImageMTIImageOutput)

- (BOOL)processImage:(MTIImage *)image frameTime:(CMTime)frameTime imageOutput:(MTIGPUImageMTIImageOutput *)imageOutput outputCallback:(MTIGPUImageMTIImageOutputCallback)outputCallback outputCallbackQueue:(dispatch_queue_t)outputCallbackQueue
{
    return [self processImage:image frameTime:frameTime prepareForProcessing:^{
        [imageOutput setPixelBufferOutputCallback:outputCallback queue:outputCallbackQueue];
    } completion:^{
        [imageOutput setPixelBufferOutputCallback:NULL queue:NULL];
    }];
}

@end
