//
//  HTStateAwareRasterImageView.m
//  HotelTonight
//
//  Created by Jacob Jennings on 11/29/12.
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//

#import "HTStateAwareRasterImageView.h"
#import "NSObject+HTPropertyHash.h"
#import "MSCachedAsyncViewDrawing.h"
#import "UIView+HTDrawInContext.h"

@interface HTStateAwareRasterImageView ()

@property (nonatomic, assign) BOOL capped;
@property (nonatomic, assign) BOOL implementsShouldRasterize;
@property (nonatomic, assign) BOOL implementsUseMinimumSizeForCaps;
@property (nonatomic, strong) NSOperation *drawingOperation;

@end

@implementation HTStateAwareRasterImageView

- (id)initWithFrame:(CGRect)frame
{
    self = ([super initWithFrame:frame]);
    if (self)
    {
        _kvoEnabled = YES;
        _drawsOnMainThread = YES;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
}

- (void)layoutRasterizableView;
{
    if (!(self.implementsUseMinimumSizeForCaps && [self.rasterizableView useMinimumFrameForCaps]))
    {
        self.rasterizableView.frame = self.bounds;
    }
}

- (void)dealloc
{
    [self removeAllObservers];
    self.delegate = nil;
}

- (void)setRasterizableView:(UIView<HTRasterizableView> *)rasterizableView
{
    [self removeAllObservers];
    _rasterizableView = rasterizableView;
    [self layoutRasterizableView];
    
    self.capped = [self.rasterizableView respondsToSelector:@selector(capEdgeInsets)];
    self.implementsShouldRasterize = [self.rasterizableView respondsToSelector:@selector(shouldRegenerateRasterForKeyPath:change:)];
    self.implementsUseMinimumSizeForCaps = [self.rasterizableView respondsToSelector:@selector(useMinimumFrameForCaps)];
    
    for (NSString *propertyName in [rasterizableView keyPathsThatAffectState])
    {
        [rasterizableView addObserver:self forKeyPath:propertyName options:NSKeyValueObservingOptionNew context:nil];
    }
    [self regenerateImage:nil];
}

- (void)removeAllObservers;
{
    for (NSString *propertyName in [self.rasterizableView keyPathsThatAffectState])
    {
        [_rasterizableView removeObserver:self forKeyPath:propertyName];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.kvoEnabled)
    {
        return;
    }
    if (self.implementsShouldRasterize)
    {
        if (![self.rasterizableView shouldRegenerateRasterForKeyPath:keyPath change:change])
        {
            return;
        }
    }
    
    [self regenerateImage:nil];
}

- (void)regenerateImage:(HTSARIVVoidBlock)complete
{
    CGSize size = self.bounds.size;
    BOOL useMinimumCapSize = self.implementsUseMinimumSizeForCaps && [self.rasterizableView useMinimumFrameForCaps];
    if (CGSizeEqualToSize(size, CGSizeZero) && !useMinimumCapSize)
    {
        return;
    }
    
    if (useMinimumCapSize)
    {
        UIEdgeInsets edgeInsets = [self.rasterizableView capEdgeInsets];
        size = CGSizeMake(edgeInsets.left + edgeInsets.right + 1, edgeInsets.top + edgeInsets.bottom + 1);
    }
    
    self.rasterizableView.frame = (CGRect){.origin = CGPointZero, .size = size};
    NSString *cacheKey = [self cacheKey];
    __unsafe_unretained HTStateAwareRasterImageView *bSelf = self;
    
    [self performSelector:@selector(checkImageGenerated) withObject:nil afterDelay:2];

    MSCachedAsyncViewDrawingDrawBlock drawBlock = ^(CGRect frame)
    {
        if ([bSelf.delegate respondsToSelector:@selector(rasterImageViewWillRegenerateImage:)])
        {
            [bSelf.delegate rasterImageViewWillRegenerateImage:bSelf];
        }
        bSelf.rasterizableView.frame = frame;
        [bSelf.rasterizableView drawRect:frame inContext:UIGraphicsGetCurrentContext()];
        //                        NSLog(@"Key: %@\n", [cacheKey stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
    };
    
    MSCachedAsyncViewDrawingCompletionBlock completionBlock = ^(UIImage *drawnImage)
    {
        if ([bSelf capped])
        {
            bSelf.image = [drawnImage resizableImageWithCapInsets:[bSelf.rasterizableView capEdgeInsets]];
        }
        else
        {
            bSelf.image = drawnImage;
        }
        
        if ([bSelf.delegate respondsToSelector:@selector(rasterImageViewImageLoaded:)])
        {
            [bSelf.delegate rasterImageViewImageLoaded:bSelf];
        }
        
//        NSString *fileName = [NSString stringWithFormat:@"/%@-%u.png", NSStringFromClass([bSelf.rasterizableView class]), [cacheKey hash]];
//        NSData *imageData = UIImageJPEGRepresentation(bSelf.image, 1);
//        NSString *imagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
//                               stringByAppendingPathComponent:fileName];
//        [imageData writeToFile:imagePath atomically:YES];
        
        if (complete) complete();
    };
    
    [[MSCachedAsyncViewDrawing sharedInstance] drawViewSynchronous:self.drawsOnMainThread
                                                      withCacheKey:cacheKey
                                                              size:size
                                                   backgroundColor:[UIColor clearColor]
                                                         drawBlock:drawBlock
                                                   completionBlock:completionBlock];
}

- (NSString *)cacheKey
{
    return [self.rasterizableView hashStringForKeyPaths:[self.rasterizableView keyPathsThatAffectState]];
}

- (void)checkImageGenerated
{
    if (!self.image)
    {
        NSLog(@"Blukubluku");
    }
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [self regenerateImage:nil];
}

@end
