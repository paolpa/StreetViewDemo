//
//  JCTiledScrollView.m
//  
//  Created by Jesse Collis on 1/2/2012.
//  Copyright (c) 2012, Jesse Collis JC Multimedia Design. <jesse@jcmultimedia.com.au>
//  All rights reserved.
//
//  * Redistribution and use in source and binary forms, with or without 
//   modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright 
//   notice, this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright 
//   notice, this list of conditions and the following disclaimer in the 
//   documentation and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY 
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
//

#import "JCTiledScrollView.h"
#import "JCTiledView.h"
#import "JCAnnotation.h"
#import "JCAnnotationView.h"
#import "JCVisibleAnnotationTuple.h"

#define kStandardUIScrollViewAnimationTime (int64_t)0.10

@interface JCTiledScrollView () <JCTiledBitmapViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, retain) UITapGestureRecognizer *singleTapGestureRecognizer;
@property (nonatomic, retain) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (nonatomic, retain) UITapGestureRecognizer *twoFingerTapGestureRecognizer;
@property (nonatomic, assign) BOOL muteAnnotationUpdates;
@end

@implementation JCTiledScrollView

@synthesize tiledScrollViewDelegate = _tiledScrollViewDelegate;
@synthesize dataSource = _dataSource;

@synthesize levelsOfZoom = _levelsOfZoom;
@synthesize levelsOfDetail = _levelsOfDetail;
@dynamic zoomScale;

@synthesize tiledView = _tiledView;
@synthesize scrollView = _scrollView;
@synthesize canvasView = _canvasView;

@synthesize singleTapGestureRecognizer = _singleTapGestureRecognizer;
@synthesize doubleTapGestureRecognizer = _doubleTapGestureRecognizer;
@synthesize twoFingerTapGestureRecognizer = _twoFingerTapGestureRecognizer;

@synthesize zoomsOutOnTwoFingerTap = _zoomsOutOnTwoFingerTap;
@synthesize zoomsInOnDoubleTap = _zoomsInOnDoubleTap;
@synthesize centerSingleTap = _centerSingleTap;

@synthesize muteAnnotationUpdates = _muteAnnotationUpdates;

@synthesize contentSize = _contentSize;

+ (Class)tiledLayerClass
{
  return [JCTiledView class];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self setupScrollView];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame contentSize:(CGSize)contentSize
{
	if ((self = [super initWithFrame:frame]))
  {
      [self setupScrollView];
      [self setContentSize:contentSize];
  }
	return self;
}

- (void)dealloc
{	
  [_scrollView release];
  [_tiledView release];
  [_canvasView release];
  [_singleTapGestureRecognizer release];
  [_doubleTapGestureRecognizer release];
  [_twoFingerTapGestureRecognizer release];
  
  [_annotations release];
  [_visibleAnnotations release];
  [_recycledAnnotationViews release];

	[super dealloc];
}

#pragma mark - Setup

- (void) setContentSize:(CGSize)contentSize {
    _scrollView.zoomScale = 1.0;

    _contentSize = contentSize;
    _scrollView.contentSize = contentSize;

    CGRect canvas_frame = CGRectMake(0.0f, 0.0f, _scrollView.contentSize.width, _scrollView.contentSize.height);

    _canvasView.frame = canvas_frame;
    _tiledView.frame = canvas_frame;
    
    [self setNeedsLayout];
    [_scrollView setNeedsDisplay];
    [_canvasView setNeedsDisplay];
    [_tiledView setNeedsDisplay];
}

- (void) setupScrollView {
    if (_scrollView) return;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    _scrollView.delegate = self;
    _scrollView.bouncesZoom = YES;
    _scrollView.bounces = YES;
    _scrollView.minimumZoomScale = 1.0;
    
    self.levelsOfZoom = 2;
    
    self.zoomsInOnDoubleTap = YES;
    self.zoomsOutOnTwoFingerTap = YES;
    self.centerSingleTap = YES;
    
    _canvasView = [[UIView alloc] initWithFrame:CGRectZero];
    _canvasView.userInteractionEnabled = NO;
    
    _tiledView = [[[[self class] tiledLayerClass] alloc] initWithFrame:CGRectZero];
    _tiledView.delegate = self;
    
    [_scrollView addSubview:self.tiledView];
    
    [self addSubview:_scrollView];
    [self addSubview:_canvasView];
    
    _singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapReceived:)];
    _singleTapGestureRecognizer.numberOfTapsRequired = 1;
    [_tiledView addGestureRecognizer:_singleTapGestureRecognizer];
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapReceived:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [_tiledView addGestureRecognizer:_doubleTapGestureRecognizer];
    
    [_singleTapGestureRecognizer requireGestureRecognizerToFail:_doubleTapGestureRecognizer];
    
    _twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerTapReceived:)];
    _twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2;
    _twoFingerTapGestureRecognizer.numberOfTapsRequired = 1;
    [_tiledView addGestureRecognizer:_twoFingerTapGestureRecognizer];
    
    _annotations = [[NSMutableSet alloc] init];
    _visibleAnnotations = [[NSMutableSet alloc] init];
    _recycledAnnotationViews = [[NSMutableSet alloc] init];
    
    _muteAnnotationUpdates = NO;

}


#pragma mark - UIScrolViewDelegate

- (UIView *)viewForZoomingInScrollView:(__unused UIScrollView *)scrollView
{
  return self.tiledView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self centerContentInScrollView:scrollView];
    
    if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollViewDidZoom:)])
  {
    [self.tiledScrollViewDelegate tiledScrollViewDidZoom:self];
  }
}

- (void)scrollViewDidScroll:(__unused UIScrollView *)scrollView
{
  [self correctScreenPositionOfAnnotations];

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollViewDidScroll:)])
  {
    [self.tiledScrollViewDelegate tiledScrollViewDidScroll:self];
  }
}

- (void)centerContentInScrollView:(UIScrollView*)scrollView {
    UIView *subView = [scrollView.subviews objectAtIndex:0];
    
    CGFloat offsetX = (CGFloat)((scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0);
    
    CGFloat offsetY = (CGFloat)((scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0);
    
    subView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                                 scrollView.contentSize.height * 0.5 + offsetY);
}

- (void) adjustMinimumZoomScale:(UIScrollView*)scrollView {
    if (!CGSizeEqualToSize(_contentSize, CGSizeZero)) {
        CGFloat ratio = MIN(scrollView.bounds.size.width/_contentSize.width,scrollView.bounds.size.height/_contentSize.height);
        scrollView.minimumZoomScale = ratio;
    }
}

- (void) layoutSubviews {
    [super layoutSubviews];
//    [self adjustMinimumZoomScale:_scrollView];
    [self centerContentInScrollView:_scrollView];
}

#pragma mark - 

//FIXME: Jesse C - I don't like overloading this here, but the logic is in one place
- (void)setMuteAnnotationUpdates:(BOOL)muteAnnotationUpdates
{
  _muteAnnotationUpdates = muteAnnotationUpdates;
  _scrollView.userInteractionEnabled = !_muteAnnotationUpdates;

  if (!muteAnnotationUpdates)
  {
    [self correctScreenPositionOfAnnotations];
  }
}

#pragma mark - Gesture Suport

- (void)singleTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.centerSingleTap)
  {
    [self setContentCenter:[gestureRecognizer locationInView:self.tiledView] animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveSingleTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveSingleTap:gestureRecognizer];
  }
}

- (void)doubleTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.zoomsInOnDoubleTap)
  {
    float newZoom = MIN(powf(2, (log2f(_scrollView.zoomScale) + 1.0f)), _scrollView.maximumZoomScale); //zoom in one level of detail

    self.muteAnnotationUpdates = YES;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, kStandardUIScrollViewAnimationTime * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
      [self setMuteAnnotationUpdates:NO];
    });

    CGPoint touch = [gestureRecognizer locationInView:self.tiledView];
      
    CGFloat newWidth = _scrollView.bounds.size.width/newZoom;
    CGFloat newHeight = _scrollView.bounds.size.height/newZoom;
    CGRect newRect = CGRectMake(touch.x - newWidth/2, touch.y - newHeight/2, newWidth, newHeight);
      
    [_scrollView zoomToRect:newRect animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveDoubleTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveDoubleTap:gestureRecognizer];
  }
}

- (void)twoFingerTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.zoomsOutOnTwoFingerTap)
  {
    float newZoom = MAX(powf(2, (log2f(_scrollView.zoomScale) - 1.0f)), _scrollView.minimumZoomScale); //zoom out one level of detail

    self.muteAnnotationUpdates = YES;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, kStandardUIScrollViewAnimationTime * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
      [self setMuteAnnotationUpdates:NO];
    });

    [_scrollView setZoomScale:newZoom animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveTwoFingerTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveTwoFingerTap:gestureRecognizer];
  }
}

- (CGPoint)screenPositionForAnnotation:(id<JCAnnotation>)annotation
{
  CGPoint position;
  position.x = (annotation.contentPosition.x * self.zoomScale) - _scrollView.contentOffset.x;
  position.y = (annotation.contentPosition.y * self.zoomScale) - _scrollView.contentOffset.y;
  return position;
}

- (void)correctScreenPositionOfAnnotations
{
  [CATransaction begin];
  [CATransaction setAnimationDuration:0.0];

  if ((_scrollView.isZoomBouncing || _muteAnnotationUpdates) && !_scrollView.isZooming)
  {
    for (JCVisibleAnnotationTuple *t in _visibleAnnotations)
    {
      t.view.position = [self screenPositionForAnnotation:t.annotation];
    }
  }
  else
  {
    for (id<JCAnnotation> annotation in _annotations)
    {
      [CATransaction begin];
      
      CGPoint screenPosition = [self screenPositionForAnnotation:annotation];
      JCVisibleAnnotationTuple *t = [_visibleAnnotations visibleAnnotationTupleForAnnotation:annotation];

      if ([self point:screenPosition isWithinBounds:self.bounds])
      {
        if (nil == t)
        {
          JCAnnotationView *view = [_tiledScrollViewDelegate tiledScrollView:self viewForAnnotation:annotation];
          if (nil == view) continue;
          view.position = screenPosition;

          t = [JCVisibleAnnotationTuple instanceWithAnnotation:annotation view:view];
          [_visibleAnnotations addObject:t];
          [_canvasView addSubview:t.view];

          [CATransaction begin];
          [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
          CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
          theAnimation.duration = 0.3;
          theAnimation.repeatCount = 1;
          theAnimation.fromValue = [NSNumber numberWithFloat:0.0];
          theAnimation.toValue = [NSNumber numberWithFloat:1.0];
          [t.view.layer addAnimation:theAnimation forKey:@"animateOpacity"];
          [CATransaction commit];
        }
        else
        {
          t.view.position = screenPosition;
        }
      }
      else
      {
        if (nil != t)
        {
          [t.view removeFromSuperview];
          [_recycledAnnotationViews addObject:t.view];
          [_visibleAnnotations removeObject:t];
        }
      }
      [CATransaction commit];
    }
  }
  [CATransaction commit];
}

#pragma mark - JCTiledScrollView

- (float)zoomScale
{
  return _scrollView.zoomScale;
}

- (void)setZoomScale:(float)zoomScale
{
  [self setZoomScale:zoomScale animated:NO];
}

- (void)setZoomScale:(float)zoomScale animated:(BOOL)animated
{
  [_scrollView setZoomScale:zoomScale animated:animated];
}

- (void) zoomToFitAnimated:(BOOL)animated {
  CGFloat ratio = MIN(_scrollView.bounds.size.width/_contentSize.width,_scrollView.bounds.size.height/_contentSize.height);
  [self setZoomScale:ratio animated:animated];
}

- (void)setLevelsOfZoom:(size_t)levelsOfZoom
{
  _levelsOfZoom = levelsOfZoom - (size_t)floor([[UIScreen mainScreen] scale]/2);
  _scrollView.maximumZoomScale = (float)powf(2.0f, MAX(0.0f, _levelsOfZoom));
}

- (void)setLevelsOfDetail:(size_t)levelsOfDetail
{
  _levelsOfDetail = levelsOfDetail - (size_t)floor([[UIScreen mainScreen] scale]/2);
  [self.tiledView setNumberOfZoomLevels:_levelsOfDetail];
}

- (void)setContentCenter:(CGPoint)center animated:(BOOL)animated
{
  CGPoint new_contentOffset = _scrollView.contentOffset;
  
  if (_scrollView.contentSize.width > _scrollView.bounds.size.width)
  {
    new_contentOffset.x = MAX(0.0f, (center.x * _scrollView.zoomScale) - (_scrollView.bounds.size.width / 2.0f));
    new_contentOffset.x = MIN(new_contentOffset.x, (_scrollView.contentSize.width - _scrollView.bounds.size.width));
  }

  if (_scrollView.contentSize.height > _scrollView.bounds.size.height)
  {
    new_contentOffset.y = MAX(0.0f, (center.y * _scrollView.zoomScale) - (_scrollView.bounds.size.height / 2.0f));
    new_contentOffset.y = MIN(new_contentOffset.y, (_scrollView.contentSize.height - _scrollView.bounds.size.height));
  }
  [_scrollView setContentOffset:new_contentOffset animated:animated];
}

#pragma mark - JCTileSource

- (UIImage *)tiledView:(__unused JCTiledView *)tiledView imageForRow:(NSInteger)row column:(NSInteger)column scale:(NSInteger)scale
{
  return [self.dataSource tiledScrollView:self imageForRow:row column:column scale:scale];
}

#pragma mark - Annotation Recycling

- (JCAnnotationView *)dequeueReusableAnnotationViewWithReuseIdentifier:(NSString *)reuseIdentifier
{
  id view = nil;

  for (JCAnnotationView *obj in _recycledAnnotationViews)
  {
    if ([[obj reuseIdentifier] isEqualToString:reuseIdentifier])
    {
      view = obj;
      break;
    }
  }
  
  if (nil != view)
  {
    [view retain];
    [_recycledAnnotationViews removeObject:view];
    return [view autorelease];
  }
  return nil;
}

#pragma mark - Annotations

- (BOOL)point:(CGPoint)point isWithinBounds:(CGRect)bounds
{
  return CGRectContainsPoint(CGRectInset(bounds, -25.,-25.), point);
}

- (void)refreshAnnotations
{
  [self correctScreenPositionOfAnnotations];
}

- (void)addAnnotation:(id<JCAnnotation>)annotation
{
  [_annotations addObject:annotation];

  CGPoint screenPosition = [self screenPositionForAnnotation:annotation];

  if ([self point:screenPosition isWithinBounds:self.bounds])
  {
    JCAnnotationView *view = [_tiledScrollViewDelegate tiledScrollView:self viewForAnnotation:annotation];
    view.position = screenPosition;

    JCVisibleAnnotationTuple *t = [JCVisibleAnnotationTuple instanceWithAnnotation:annotation view:view];
    [_visibleAnnotations addObject:t];

    [_canvasView addSubview:view];
  }
}

- (void)addAnnotations:(NSArray *)annotations
{
  for (id annotation in annotations)
  {
    [self addAnnotation:annotation];
  }
}

- (void)removeAnnotation:(id<JCAnnotation>)annotation
{
  if ([_annotations containsObject:annotation])
  {
    JCVisibleAnnotationTuple *t = [_visibleAnnotations visibleAnnotationTupleForAnnotation:annotation];
    if (t)
    {
      [t.view removeFromSuperview];
      [_visibleAnnotations removeObject:t];
    }

    [_annotations removeObject:annotation];
  }
}

- (void)removeAnnotations:(NSArray *)annotations
{
  for (id annotation in annotations)
  {
    [self removeAnnotation:annotation];
  }
}

- (void)removeAllAnnotations
{
  [self removeAnnotations:[_annotations allObjects]];
}

@end
