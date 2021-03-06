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
#import "MusicKombatAppDelegate.h"
#import "MKAPIConnection.h"
#import "MKAPIRequest.h"
#import "SocketIoClient.h"
#import "NSObject+SBJSON.h"
#import "NSString+SBJSON.h"

#import "AudioInput.h"

#define kMusicKombatHideViewAnimationContext @"kMusicKombatHideViewAnimationContext"

#define kMusicKombatDefaultAnimationDuration 0.3555
#define kMusicKombatCardFrame CGRectMake(24, 156, 972, 492)

#define kMusicKombatNumberOfLevels 5

static int levels [kMusicKombatNumberOfLevels] [4] = {
    {9, 7, 9, 7},
    {16, 14, 16, 7},
    {9, 14, 16, 9},
    {3, 14, 7, 3},
    {9, 12, 9, 16}
};


@interface MusicKombatViewController () <MPDADelegateProtocol, CardDelegate, MKAPIConnectionDelegate, SocketIoClientDelegate> {
@private
    Card *activeCard;
    
    AudioInput *pitchDetector;
    
    LifeBar *leftBar;
    LifeBar *rightBar;
    
    int level;
    
    NSNumber *opponentId;
    
    SocketIoClient *connection;
    
    NSDictionary *gameResponse;
    
    BOOL gameOver;
    
    UIImageView *mainView;
}


@property (retain) SocketIoClient *connection;

@property (nonatomic, retain) IBOutlet Card *activeCard;

- (void)next;

- (void)didLose;
- (void)didWin;

@end

@implementation MusicKombatViewController
@synthesize activeCard;
@synthesize connection;


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsLandscape(interfaceOrientation); 
}

- (void)awakeFromNib {
    
    [MusicKombatAppDelegate sharedDelegate].gameViewController = self;

    SocketIoClient *client = [[SocketIoClient alloc] initWithHost:@"dev.misomedia.com" port:1234];
    client.delegate = self;
    
    [client connect];
    
    connection = client;
    
    gameResponse = nil;
    opponentId = nil;

    pitchDetector = [[AudioInput alloc] initWithDelegate:self];
    
    leftBar = [[LifeBar alloc] initWithFrame:CGRectMake(42, 52, 0, 0) isRight:NO];
    rightBar = [[LifeBar alloc] initWithFrame:CGRectMake(569, 52, 0, 0) isRight:YES];
    
    [self.view addSubview:leftBar];
    [self.view addSubview:rightBar];
    
    level = 0;

    mainView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"menu_screen"]];
    [self.view addSubview:mainView];
}

- (void)startGame {
    
    NSLog(@"attempting to start new game");
    
    MKAPIConnection *apiConnection = [MusicKombatAppDelegate sharedDelegate].apiConnection;
    apiConnection.delegate = self;
    
    MKAPIRequest *request = [MKAPIRequest requestWithSuffix:@"games/new"];
    [request appendQueryArgumentKey:@"user_id" value:[NSString stringWithFormat:@"%i", [MusicKombatAppDelegate sharedDelegate].userId.intValue]];
    [request appendQueryArgumentKey:@"auth_token" value:[MusicKombatAppDelegate sharedDelegate].token];
    [request appendBodyArgumentKey:@"brandon" value:@"sucks_cock"]; // Fool stupid server into thinking it's a POST request
    [apiConnection sendRequest:request];
}

- (void)opponentFound {
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
    
    
    
    CBContextualizedBasicAnimation *fadeOutAnimation = [CBContextualizedBasicAnimation animationWithKeyPath:@"opacity"];
    fadeOutAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    fadeOutAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    fadeOutAnimation.duration = kMusicKombatDefaultAnimationDuration;
    fadeOutAnimation.removedOnCompletion = NO;
    fadeOutAnimation.fillMode = kCAFillModeForwards;
    fadeOutAnimation.delegate = self;
    fadeOutAnimation.context = mainView;
    
    [mainView.layer addAnimation:fadeOutAnimation forKey:@"opacity"];
}

- (void)didFailToReceiveAPIResponseForRequest:(MKAPIRequest *)request {
}

- (void)didReceiveAPIResponse:(NSDictionary *)response forRequest:(MKAPIRequest *)request {
    NSLog(@"response on vc %@", response);
    
    if ([request.suffix isEqualToString:@"games/new"]) {
        gameResponse = [response retain];
        
        NSDictionary *gameAuthMessage = [NSDictionary dictionaryWithObjectsAndKeys:[MusicKombatAppDelegate sharedDelegate].token, @"auth_token", [MusicKombatAppDelegate sharedDelegate].userId, @"user_id", [response objectForKey:@"id"], @"game_id", @"auth", @"action", nil];
        NSString *json = [gameAuthMessage JSONRepresentation];
        [connection send:json isJSON:YES];
    }
}

- (void)pitchDetected:(MPDA_RESULT)result {
    [self.activeCard pitchDetected:result];
}

- (void)cardCompleted {
    
    MKAPIConnection *apiConnection = [MusicKombatAppDelegate sharedDelegate].apiConnection;
    
    MKAPIRequest *request = [MKAPIRequest requestWithSuffix:[NSString stringWithFormat:@"games/%@/%@", [gameResponse objectForKey:@"id"], (((NSNumber *)[gameResponse objectForKey:@"opponent_id"]).intValue ? @"win": @"loss")]];
    [request appendQueryArgumentKey:@"user_id" value:[NSString stringWithFormat:@"%i", [MusicKombatAppDelegate sharedDelegate].userId.intValue]];
    [request appendQueryArgumentKey:@"auth_token" value:[MusicKombatAppDelegate sharedDelegate].token];
    [request appendBodyArgumentKey:@"brandon" value:@"sucks_cock"]; // Fool stupid server into thinking it's a POST request
    [apiConnection sendRequest:request];

    rightBar.value = rightBar.value + 1;
    
    if (rightBar.value == 5) {
        [self performSelectorOnMainThread:@selector(didWin) withObject:nil waitUntilDone:NO];
    } else {
        [self performSelectorOnMainThread:@selector(next) withObject:nil waitUntilDone:NO];
    }
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

- (void)didLose {
    NSLog(@"LOST");
    if (gameOver) return;
    gameOver = YES;
    
    self.activeCard = nil;
    
    CBContextualizedBasicAnimation *fadeInAnimation = [CBContextualizedBasicAnimation animationWithKeyPath:@"opacity"];
    fadeInAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    fadeInAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    fadeInAnimation.duration = kMusicKombatDefaultAnimationDuration;
    fadeInAnimation.removedOnCompletion = NO;
    fadeInAnimation.fillMode = kCAFillModeForwards;
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"robinson_win"]];
    [imageView.layer addAnimation:fadeInAnimation forKey:@"opacity"];
    [self.view addSubview:imageView];
}

- (void)didWin {
    NSLog(@"WON");
    if (gameOver) return;
    gameOver = YES;
    
    self.activeCard = nil;
    
    CBContextualizedBasicAnimation *fadeInAnimation = [CBContextualizedBasicAnimation animationWithKeyPath:@"opacity"];
    fadeInAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    fadeInAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    fadeInAnimation.duration = kMusicKombatDefaultAnimationDuration;
    fadeInAnimation.removedOnCompletion = NO;
    fadeInAnimation.fillMode = kCAFillModeForwards;
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ziggy_win"]];
    [imageView.layer addAnimation:fadeInAnimation forKey:@"opacity"];
    [self.view addSubview:imageView];
}

- (void)dealloc {
    [activeCard release];
    [pitchDetector release];
    [leftBar release];
    [rightBar release];
    [gameResponse release];
    [super dealloc];
}


- (void)socketIoClientDidConnect:(SocketIoClient *)client {
    NSLog(@"Connected.");
}

- (void)socketIoClientDidDisconnect:(SocketIoClient *)client {
    NSLog(@"Disconnected.");
}

- (void)socketIoClient:(SocketIoClient *)client didReceiveMessage:(NSString *)message isJSON:(BOOL)isJSON {
    NSLog(@"Received: %@", message);
    if (isJSON) {
        NSDictionary *messageDict = [message JSONValue];
        if (NSString *action = [messageDict objectForKey:@"action"]) {
            if ([action isEqualToString:@"game_update"]) {
                NSNumber *newOpponentId = [[messageDict objectForKey:@"game"] objectForKey:@"opponent_id"];
                if (newOpponentId.intValue > 0) {
                    opponentId = [newOpponentId retain];
                    [self opponentFound];
                }
            } else if([action isEqualToString:@"score_update"]) {
                NSNumber *opponentScore = [[messageDict objectForKey:@"game"] objectForKey:(((NSNumber *)[gameResponse objectForKey:@"opponent_id"]).intValue ? @"losses": @"wins")];
                leftBar.value = opponentScore.intValue;
                if (opponentScore.intValue >=5) {
                    [self performSelectorOnMainThread:@selector(didLose) withObject:nil waitUntilDone:NO];
                }
            }
        }
    }
}


- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    if (!finished) return;
    
    if (![animation isKindOfClass:[CBContextualizedBasicAnimation class]]) return;
    
    CBContextualizedBasicAnimation *contextualizedAnimation = (CBContextualizedBasicAnimation *)animation;
    
    if ([contextualizedAnimation.context isKindOfClass:[Card class]]) {
        [(Card *)contextualizedAnimation.context release];
    } else if ([contextualizedAnimation.context isKindOfClass:[UIView class]]) {
        [(UIView *)contextualizedAnimation.context removeFromSuperview];
    }

}

- (void)viewDidUnload {
    [self setActiveCard:nil];
    [super viewDidUnload];
}
@end
