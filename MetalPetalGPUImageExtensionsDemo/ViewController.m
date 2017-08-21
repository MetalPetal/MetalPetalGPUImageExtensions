//
//  ViewController.m
//  MetalPetalGPUImageExtensionsDemo
//
//  Created by YuAo on 11/08/2017.
//  Copyright © 2017 MetalPetal. All rights reserved.
//

#import "ViewController.h"
@import GPUImage;
@import MetalPetal;
@import MetalPetalGPUImageExtensions;

@interface ViewController () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) GPUImageMovie *movie;
@property (nonatomic, strong) GPUImageContrastFilter *contrastFilter;
@property (nonatomic, strong) MTIGPUImageFilter *mtigpuImageFilter;
@property (nonatomic, strong) MTIGPUImageTwoInputFilter *mtigpuiamgeTwoInputFilter;
@property (nonatomic, strong) MTISaturationFilter *saturationFilter;
@property (nonatomic, strong) MTIColorInvertFilter *colorInvertFilter;
@property (nonatomic, strong) MTIGPUImageMTIImageOutput *output;
@property (nonatomic, strong) MTIGPUImageMTIImageInput *input;
@property (nonatomic, strong) MTIGPUImageMTIImageOutput *movieOutput;
@property (nonatomic, strong) MTIContext *context;
@property (atomic, strong) MTIImage *mtiImage;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak __typeof(self) weakSelf = self;
    
    id <MTLDevice> device = MTLCreateSystemDefaultDevice();
    
    MTKView *renderView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    renderView.delegate = self;
    renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:renderView];
    self.mtkView = renderView;
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"IMG_1762121212" withExtension:@"MOV"]];
    self.movie = [[GPUImageMovie alloc] initWithURL:asset.URL];
    self.movie.shouldRepeat = YES;
    self.movie.playAtActualSpeed = YES;

//    UIImage *uiimage = [UIImage imageNamed:@"P1040808.jpg"];
//    self.mtiImage = [[MTIImage alloc] initWithCGImage:uiimage.CGImage options:nil];
    
    self.context = [[MTIContext alloc] initWithDevice:device error:NULL];
    self.input = [[MTIGPUImageMTIImageInput alloc] initWithContext:self.context];
    self.output = [[MTIGPUImageMTIImageOutput alloc] initWithContext:self.context];
    self.movieOutput = [[MTIGPUImageMTIImageOutput alloc] initWithContext:self.context];
    
    self.contrastFilter = [[GPUImageContrastFilter alloc] init];
    self.contrastFilter.contrast = 1;
    
    self.saturationFilter = [[MTISaturationFilter alloc] init];
    self.colorInvertFilter = [[MTIColorInvertFilter alloc] init];
    
    self.mtigpuImageFilter = [[MTIGPUImageFilter alloc] init];
    self.mtigpuImageFilter.processor = ^MTIImage * _Nonnull(MTIImage * _Nonnull inputImage) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.saturationFilter.inputImage = inputImage;
        strongSelf.saturationFilter.saturation = 1.0 + sin(CFAbsoluteTimeGetCurrent() * 2.0);
        strongSelf.colorInvertFilter.inputImage = strongSelf.saturationFilter.outputImage;
        strongSelf.saturationFilter.inputImage = strongSelf.colorInvertFilter.outputImage;
        strongSelf.colorInvertFilter.inputImage = strongSelf.saturationFilter.outputImage;
        strongSelf.saturationFilter.inputImage = strongSelf.colorInvertFilter.outputImage;
        strongSelf.colorInvertFilter.inputImage = strongSelf.saturationFilter.outputImage;
        strongSelf.saturationFilter.inputImage = strongSelf.colorInvertFilter.outputImage;
        strongSelf.colorInvertFilter.inputImage = strongSelf.saturationFilter.outputImage;
        return strongSelf.colorInvertFilter.outputImage;
    };
    
    [self.input addTarget:self.contrastFilter];
    [self.contrastFilter addTarget:self.mtigpuImageFilter];
    [self.mtigpuImageFilter addTarget:self.output];
    
    [self.movie addTarget:self.movieOutput];
    [self.movieOutput setPixelBufferOutputCallback:^(MTIImage * _Nonnull image, CMTime frameTime) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [weakSelf.input processImage:image frameTime:kCMTimeZero imageOutput:strongSelf.output outputCallback:^(MTIImage * _Nonnull image, CMTime frameTime) {
            strongSelf.mtiImage = image;
        } outputCallbackQueue:NULL];
    } queue:NULL];
    [self.movie startProcessing];
    
//    self.preview = [[GPUImageView alloc] initWithFrame:self.view.bounds];
//    CGAffineTransform t = [[[asset tracksWithMediaType:AVMediaTypeVideo] firstObject] preferredTransform];
//    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
//        [self.preview setInputRotation:kGPUImageRotateRight atIndex:0];
//    } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
//        [self.preview setInputRotation:kGPUImageRotateLeft atIndex:0];
//    } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
//        [self.preview setInputRotation:kGPUImageRotate180 atIndex:0];
//    }
//    self.view = self.preview;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    if (self.mtiImage && [view currentDrawable]) {
        MTIDrawableRenderingRequest *request = [[MTIDrawableRenderingRequest alloc] init];
        request.drawableProvider = self.mtkView;
        request.resizingMode = MTIDrawableRenderingResizingModeAspect;
        [self.context renderImage:self.mtiImage toDrawableWithRequest:request error:nil];
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
