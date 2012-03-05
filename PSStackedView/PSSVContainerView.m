//
//  PSContainerView.m
//  PSStackedView
//
//  Created by Peter Steinberger on 7/17/11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
//

#import "PSSVContainerView.h"
#import "PSStackedViewGlobal.h"
#import "UIView+YSGeometry.h"

@interface PSSVContainerView ()
@property(nonatomic, assign) CGFloat originalWidth;
@property(nonatomic, retain) CAGradientLayer *leftShadowLayer;
@property(nonatomic, retain) CAGradientLayer *innerShadowLayer;
@property(nonatomic, retain) CAGradientLayer *rightShadowLayer;
@property(nonatomic, retain) UIView *transparentView;
@end

@implementation PSSVContainerView

@synthesize shadow = shadow_;
@synthesize originalWidth = originalWidth_;
@synthesize controller = controller_;
@synthesize leftShadowLayer = leftShadowLayer_;
@synthesize innerShadowLayer = innerShadowLayer_;
@synthesize rightShadowLayer = rightShadowLayer_;
@synthesize transparentView = transparentView_;
@synthesize shadowWidth = shadowWidth_;
@synthesize shadowAlpha = shadowAlpha_;
@synthesize cornerRadius = cornerRadius_;
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark private

// creates vertical shadow
- (CAGradientLayer *)shadowAsInverse:(BOOL)inverse {
	CAGradientLayer *newShadow = [[[CAGradientLayer alloc] init] autorelease];
    newShadow.startPoint = CGPointMake(0, 0.5f);
    newShadow.endPoint = CGPointMake(1.0f, 0.5f);
	CGColorRef darkColor  = (CGColorRef)CFRetain([UIColor colorWithWhite:0.0f alpha:shadowAlpha_].CGColor);
	CGColorRef lightColor = (CGColorRef)CFRetain([UIColor clearColor].CGColor);
	newShadow.colors = [NSArray arrayWithObjects:
                        (id)(inverse ? lightColor : darkColor),
                        (id)(inverse ? darkColor : lightColor),
                        nil];
    
    CFRelease(darkColor);
    CFRelease(lightColor);
	return newShadow;
}

// return available shadows as set, for easy enumeration
- (NSSet *)shadowSet {
    NSMutableSet *set = [NSMutableSet set];
    if (self.leftShadowLayer) {
        [set addObject:self.leftShadowLayer];
    }
    if (self.innerShadowLayer) {
        [set addObject:self.innerShadowLayer];
    }
    if (self.rightShadowLayer) {
        [set addObject:self.rightShadowLayer];
    }
    return [[set copy] autorelease];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

+ (PSSVContainerView *)containerViewWithController:(UIViewController *)controller; {
    PSSVContainerView *view = [[[PSSVContainerView alloc] initWithFrame:controller.view.frame] autorelease];
    view.controller = controller;    
    return view;
}

- (void)dealloc {
    [self removeMask];
    self.shadow = PSSVSideNone; // TODO needed?
	
	self.leftShadowLayer = nil;
	self.innerShadowLayer = nil;
	self.rightShadowLayer = nil;
	self.transparentView = nil;
	
	[controller_ release], controller_ = nil;
	
	
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    // adapt layer heights
    for (CALayer *layer in [self shadowSet]) {
        CGRect aFrame = layer.frame;
        aFrame.size.height = frame.size.height;
        layer.frame = aFrame;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (CGFloat)limitToMaxWidth:(CGFloat)maxWidth; {
    BOOL widthChanged = NO;
    
    if (maxWidth && self.frameWidth > maxWidth) {
        self.frameWidth = maxWidth;
        widthChanged = YES;
    }else if(self.originalWidth && self.frameWidth < self.originalWidth) {
        self.frameWidth = MIN(maxWidth, self.originalWidth);
        widthChanged = YES;
    }
    self.controller.view.frameWidth = self.frameWidth;
    
    // update shadow layers for new width
    if (widthChanged) {
        [self updateContainer];
    }
    
    return self.frameWidth;
}

- (void)setController:(UIViewController *)aController {
    if (controller_ != aController) {
		
        if (controller_) {
            [controller_.view removeFromSuperview];
			[controller_ release];
        }        
        controller_ = [aController retain];
        
		if (controller_) {
			// properly embed view
			self.originalWidth = self.controller.view.frameWidth;
			controller_.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth; 
			controller_.view.frame = CGRectMake(0, 0, controller_.view.frameWidth, controller_.view.frameHeight);
			[self addSubview:controller_.view];
			[self bringSubviewToFront:transparentView_];
		}
    }
}

- (void)addMaskToCorners:(UIRectCorner)corners; {
    // Re-calculate the size of the mask to account for adding/removing rows.
    CGRect frame = self.controller.view.bounds;
    if([self.controller.view isKindOfClass:[UIScrollView class]] && ((UIScrollView *)self.controller.view).contentSize.height > self.controller.view.frame.size.height) {
    	frame.size = ((UIScrollView *)self.controller.view).contentSize;
    } else {
        frame.size = self.controller.view.frame.size;
    }
    
    // Create the path (with only the top-left corner rounded)
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:frame 
                                                   byRoundingCorners:corners
                                                         cornerRadii:CGSizeMake(cornerRadius_, cornerRadius_)];
    
    // Create the shape layer and set its path
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = frame;
    maskLayer.path = maskPath.CGPath;
    
    // Set the newly created shape layer as the mask for the image view's layer
    self.controller.view.layer.mask = maskLayer;
}

- (void)removeMask; {
    self.controller.view.layer.mask = nil;
}

- (void)updateContainer {
    // re-set shadow property
    self.shadow = shadow_;
}

- (void)setShadow:(PSSVSide)theShadow {
    shadow_ = theShadow;
    
    if (shadow_ & PSSVSideLeft) {
        if (!self.leftShadowLayer) {
            CAGradientLayer *leftShadow = [self shadowAsInverse:YES];
            self.leftShadowLayer = leftShadow;
        }
        self.leftShadowLayer.frame = CGRectMake(-shadowWidth_, 0, shadowWidth_+cornerRadius_, self.controller.view.frameHeight);
        if ([self.layer.sublayers indexOfObjectIdenticalTo:self.leftShadowLayer] != 0) {
            [self.layer insertSublayer:self.leftShadowLayer atIndex:0];
        }
    }else {
        [self.leftShadowLayer removeFromSuperlayer];
    }
    
    if (shadow_ & PSSVSideRight) {
        if (!self.rightShadowLayer) {
            CAGradientLayer *rightShadow = [self shadowAsInverse:NO];
            self.rightShadowLayer = rightShadow;
        }
        self.rightShadowLayer.frame = CGRectMake(self.frameWidth-cornerRadius_, 0, shadowWidth_, self.controller.view.frameHeight);
        if ([self.layer.sublayers indexOfObjectIdenticalTo:self.rightShadowLayer] != 0) {
            [self.layer insertSublayer:self.rightShadowLayer atIndex:0];
        }
    }else {
        [self.rightShadowLayer removeFromSuperlayer];
    }
    
    if (shadow_) {
        if (!self.innerShadowLayer) {
            CAGradientLayer *innerShadow = [[[CAGradientLayer alloc] init] autorelease];
            innerShadow.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0f alpha:shadowAlpha_].CGColor, (id)[UIColor colorWithWhite:0.0f alpha:shadowAlpha_].CGColor, nil];
            self.innerShadowLayer = innerShadow;
        }
        self.innerShadowLayer.frame = CGRectMake(cornerRadius_, 0, self.frameWidth-cornerRadius_*2, self.controller.view.frameHeight);
        if ([self.layer.sublayers indexOfObjectIdenticalTo:self.innerShadowLayer] != 0) {
            [self.layer insertSublayer:self.innerShadowLayer atIndex:0];
        }
    }else {
        [self.innerShadowLayer removeFromSuperlayer];
    }
}

- (void)setDarkRatio:(CGFloat)darkRatio {
    BOOL isTransparent = darkRatio > 0.01f;
    
    if (isTransparent && !transparentView_) {
        transparentView_ = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.frameWidth, self.frameHeight)];
        transparentView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        transparentView_.backgroundColor = [UIColor blackColor];
        transparentView_.alpha = 0.f;
        transparentView_.userInteractionEnabled = NO;
        [self addSubview:transparentView_];
    }
    
    transparentView_.alpha = darkRatio;
}

- (CGFloat)darkRatio {
    return transparentView_.alpha;
}

@end
