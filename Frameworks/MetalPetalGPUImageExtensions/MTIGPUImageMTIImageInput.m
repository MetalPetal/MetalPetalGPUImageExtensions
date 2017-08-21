//
//  MTIGPUImageMTIImageInput.m
//  Pods
//
//  Created by jichuan on 2017/8/17.
//
//

#import "MTIGPUImageMTIImageInput.h"

@implementation MTIGPUImageMTIImageInput {
    dispatch_group_t frameProcessingGroup;
    BOOL applicationIsForeground;
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
            if (prepareForProcessing) {
                prepareForProcessing();
            }
            
            outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(image.extent.size.width, image.extent.size.height) textureOptions:self.outputTextureOptions onlyTexture:NO];
            
            CVPixelBufferRef pixelBuffer = outputFramebuffer.pixelBuffer;
            
            NSError *error = nil;
            [self.context renderImage:image toCVPixelBuffer:pixelBuffer error:&error];
            NSAssert(!error, error.localizedDescription);
            
            [self informTargetsAboutNewFrameAtTime:frameTime];
            
            [outputFramebuffer unlock];
            
            if (completion) {
                completion();
            }
            
            dispatch_group_leave(frameProcessingGroup);
        });
        
        return YES;
    }
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
