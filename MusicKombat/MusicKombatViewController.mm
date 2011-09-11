//
//  MusicKombatViewController.m
//  MusicKombat
//
//  Created by Kenneth Ballenegger on 9/10/11.
//  Copyright 2011 Azure Talon. All rights reserved.
//

#import "MusicKombatViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "CardView.h"
#import "CBContextualizedBasicAnimation.h"
#import "Card.h"
#import "LifeBar.h"

#import "AudioInput.h"

#define kMusicKombatHideViewAnimationContext @"kMusicKombatHideViewAnimationContext"

#define kMusicKombatDefaultAnimationDuration 0.3555
#define kMusicKombatCardFrame CGRectMake(24, 156, 972, 492)

#define kMusicKombatNumberOfLevels 5

static int levels [kMusicKombatNumberOfLevels] [4] = {
    {9, 7, 9, 7},
    {16, 14, 16, 7},
    {9, 14, 16, 9},
    {18, 18, 18, 18},
    {9, 7, 9, 7}
};


@interface MusicKombatViewController () <MPDADelegateProtocol, CardDelegate> {
@private
    Card *activeCard;
    
    AudioInput *pitchDetector;
    
    LifeBar *leftBar;
    LifeBar *rightBar;
    
    int level;
}


@property (nonatomic, retain) IBOutlet Card *activeCard;

- (void)next;

@end

@implementation MusicKombatViewController
@synthesize activeCard;


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsLandscape(interfaceOrientation); 
}

- (void)awakeFromNib {
    
    pitchDetector = [[AudioInput alloc] initWithDelegate:self];
    
    leftBar = [[LifeBar alloc] initWithFrame:CGRectMake(42, 52, 0, 0) isRight:NO];
    rightBar = [[LifeBar alloc] initWithFrame:CGRectMake(569, 52, 0, 0) isRight:YES];
    
    [self.view addSubview:leftBar];
    NSLog(@"frame %@", NSStringFromCGRect(leftBar.frame));
    NSLog(@"frame %@", NSStringFromCGRect(rightBar.frame));
    [self.view addSubview:rightBar];
    
    level = 0;
    int *notes = levels[level];
    
    // First card
    
    CardView *newView = [[CardView alloc] initWithFrame:kMusicKombatCardFrame];
    CALayer *newLayer = newView.layer;

    Card *card = [[Card alloc] initWithCardView:newView notes:notes];
    card.delegate = self;
    
    CGPoint newToPosition = newView.center;
    CGPoint newFromPosition = newToPosition;
    
    newFromPosition.x += 1024;
    
    CABasicAnimation *slideInAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    slideInAnimation.fromValue = [NSValue valueWithCGPoint:newFromPosition];
    slideInAnimation.toValue = [NSValue valueWithCGPoint:newToPosition];
    slideInAnimation.duration = kMusicKombatDefaultAnimationDuration;
    slideInAnimation.removedOnCompletion = NO;
    slideInAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
    slideInAnimation.fillMode = kCAFillModeForwards;
    
    [self.view addSubview:newView];
    [newLayer addAnimation:slideInAnimation forKey:@"position"];
    
    [newView autorelease];
    self.activeCard = [card autorelease];
}

- (void)pitchDetected:(MPDA_RESULT)result {
    [self.activeCard pitchDetected:result];
}

- (void)cardCompleted {
    leftBar.value = leftBar.value + 1;
    rightBar.value = rightBar.value + 1;
    [self performSelectorOnMainThread:@selector(next) withObject:nil waitUntilDone:NO];
}

- (void)next {
    
    level++;
    if (level > kMusicKombatNumberOfLevels) {
        // TODO: GAME OVER
        return;
    }

    Card *oldCard = [self.activeCard retain]; // Keep it around long enough for the animation to happen
    
    // Replace view with animation
    
    CardView *oldView = oldCard.cardView;
    CALayer *oldLayer = oldView.layer;
    
    CardView *newView = [[CardView alloc] initWithFrame:kMusicKombatCardFrame];
    CALayer *newLayer = newView.layer;

    Card *newCard = [[[Card alloc] initWithCardView:newView notes:levels[level]] autorelease];
    newCard.delegate = self;
    
    self.activeCard = newCard;

    CGPoint newToPosition = newView.center;
    CGPoint newFromPosition = newToPosition;
    
    newFromPosition.x += 1024;
    
    CABasicAnimation *slideInAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    slideInAnimation.fromValue = [NSValue valueWithCGPoint:newFromPosition];
    slideInAnimation.toValue = [NSValue valueWithCGPoint:newToPosition];
    slideInAnimation.duration = kMusicKombatDefaultAnimationDuration;
    slideInAnimation.removedOnCompletion = NO;
    slideInAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
    slideInAnimation.fillMode = kCAFillModeForwards;
    
    [self.view addSubview:newView];
    [newLayer addAnimation:slideInAnimation forKey:@"position"];
    
    CGPoint oldFromPosition = oldView.center;
    CGPoint oldToPosition = oldFromPosition;
    
    oldToPosition.x -= 1024;
    
    CBContextualizedBasicAnimation *slideOutAnimation = [CBContextualizedBasicAnimation animationWithKeyPath:@"position"];
    slideOutAnimation.fromValue = [NSValue valueWithCGPoint:oldFromPosition];
    slideOutAnimation.toValue = [NSValue valueWithCGPoint:oldToPosition];
    slideOutAnimation.duration = kMusicKombatDefaultAnimationDuration;
    slideOutAnimation.removedOnCompletion = NO;
    slideOutAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
    slideOutAnimation.fillMode = kCAFillModeForwards;
    slideOutAnimation.delegate = self;
    slideOutAnimation.context = oldView;
    
    [oldLayer addAnimation:slideOutAnimation forKey:@"position"];
}

- (void)dealloc {
    [activeCard release];
    [pitchDetector release];
    [leftBar release];
    [rightBar release];
    [super dealloc];
}


- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    if (!finished) return;
    
    if (![animation isKindOfClass:[CBContextualizedBasicAnimation class]]) return;
    
    CBContextualizedBasicAnimation *contextualizedAnimation = (CBContextualizedBasicAnimation *)animation;
    
    if ([contextualizedAnimation.context isKindOfClass:[Card class]]) {
        [(Card *)contextualizedAnimation.context release];
    }
}

- (void)viewDidUnload {
    [self setActiveCard:nil];
    [super viewDidUnload];
}
@end
