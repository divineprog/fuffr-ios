//
//  AppViewController.m
//  FuffrBox
//
//  Created by Fuffr on 21/03/14.
//  Copyright (c) 2014 Fuffr. All rights reserved.
//

#import "AppViewController.h"

#import <FuffrLib/FFRTapGestureRecognizer.h>
#import <FuffrLib/FFRDoubleTapGestureRecognizer.h>
#import <FuffrLib/FFRLongPressGestureRecognizer.h>
#import <FuffrLib/FFRSwipeGestureRecognizer.h>
#import <FuffrLib/FFRPinchGestureRecognizer.h>
#import <FuffrLib/FFRPanGestureRecognizer.h>
#import <FuffrLib/FFRRotationGestureRecognizer.h>
#import <FuffrLib/FFROADHandler.h>
#import <FuffrLib/UIView+Toast.h>

/*********** Constants ***********/

#define URL_ARE_YOU_THERE @"http://games.fuffr.com/AreYouThere.txt"
#define URL_START_PAGE @"http://games.fuffr.com/"
#define URL_FIRMWARE_LIST @"http://games.fuffr.com/firmware/firmware.lst"
#define URL_INITIAL_URL_FIELD @"games.fuffr.com"

/*********** Global variables ***********/

/**
 * Reference to the AppViewController instance.
 */
static AppViewController* theAppViewController;

/**
 * Could not resist shortcut using a global.
 */
static BOOL FuffrIsConnected = NO;

/*********** Class URLProtocolFuffrBridge ***********/

/**
 * Bridge from JavaScript to Objective-C.
 */
@interface URLProtocolFuffrBridge : NSURLProtocol
@end

@implementation URLProtocolFuffrBridge

+ (BOOL)canInitWithRequest:(NSURLRequest*)theRequest
{
	NSString* path = theRequest.URL.path;
	if (!path) { return NO; }
	NSRange range = [path rangeOfString: @"/fuffr-bridge@"];
    BOOL found = (range.location != NSNotFound);
	return found;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)theRequest
{
	return theRequest;
}

- (void)startLoading
{
	NSString* path = self.request.URL.path;
	if (path)
	{
		[theAppViewController executeJavaScriptCommand: path];
	}

	NSDictionary* headers = @{
		@"Access-Control-Allow-Origin" : @"*",
		@"Access-Control-Allow-Headers" : @"Content-Type"
	};

	NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]
		initWithURL: self.request.URL
		statusCode: 200
		HTTPVersion: @"1.1"
		headerFields: headers];

	NSData* data = [@"OK" dataUsingEncoding: NSUTF8StringEncoding];

	// Not used.
	/*NSURLResponse* response = [[NSURLResponse alloc]
		initWithURL: self.request.URL
		MIMEType: @"text/plain"
		expectedContentLength: -1
		textEncodingName: nil];*/

	[[self client]
		URLProtocol: self
		didReceiveResponse: response
		cacheStoragePolicy: NSURLCacheStorageNotAllowed];
	[[self client] URLProtocol: self didLoadData: data];
	[[self client] URLProtocolDidFinishLoading: self];

	// Not used.
	/*[[self client]
		URLProtocol: self
		didFailWithError: createError()];*/
}

- (void)stopLoading
{
}

@end

/*********** Class GestureListener ***********/

/**
 * Gesture listener.
 */
@interface GestureListener : NSObject

@property int gestureId;
@property (nonatomic, strong) FFRGestureRecognizer* recognizer;
@property (nonatomic, weak) AppViewController* controller;

+ (GestureListener*) withTokens: (NSArray*) tokens
	controller: (AppViewController*) theController;

- (void) onPan: (FFRPanGestureRecognizer*) recognizer;
- (void) onPinch:(FFRPinchGestureRecognizer*) recognizer;
- (void) onRotation:(FFRRotationGestureRecognizer*) recognizer;
- (void) onTap:(FFRTapGestureRecognizer*) recognizer;
- (void) onDoubleTap:(FFRDoubleTapGestureRecognizer*) recognizer;
- (void) onLongPress:(FFRLongPressGestureRecognizer*) recognizer;
- (void) onSwipe:(FFRSwipeGestureRecognizer*) recognizer;

@end

// Helper function for creating a swipe gesture.
static void CreateSwipeGesture(
	GestureListener* gestureListener,
	FFRSwipeGestureRecognizerDirection direction,
	NSTimeInterval maximumDuration,
	BOOL maximumDurationIsSet,
	CGFloat minimumDistance,
	BOOL minimumDistanceIsSet)
{
	FFRSwipeGestureRecognizer* recognizer = [FFRSwipeGestureRecognizer new];
	recognizer.direction = direction;
	if (maximumDurationIsSet)
	{
			recognizer.maximumDuration = maximumDuration;
	}
	if (minimumDistanceIsSet)
	{
		recognizer.minimumDistance = minimumDistance;
	}
	[recognizer
		addTarget: gestureListener
		action: @selector(onSwipe:)];
	gestureListener.recognizer = recognizer;
}

@implementation GestureListener

+ (GestureListener*) withTokens: (NSArray*) tokens
	controller: (AppViewController*) theController
{
	NSString* gestureType = [NSString stringWithString:[tokens objectAtIndex: 2]];
	NSString* gestureSide = [NSString stringWithString:[tokens objectAtIndex: 3]];
	NSString* gestureId = [NSString stringWithString:[tokens objectAtIndex: 4]];

	// TODO: handle invalid values for type & side.
	int type = [gestureType intValue];
	FFRSide side = [gestureSide intValue];
	int gestureIntId = [gestureId intValue];

	// Extract gesture parameters.
	NSTimeInterval minimumDuration = 0;
	NSTimeInterval maximumDuration = 0;
	CGFloat minimumDistance = 0;
	CGFloat maximumDistance = 0;
	BOOL minimumDurationIsSet = NO;
	BOOL maximumDurationIsSet = NO;
	BOOL minimumDistanceIsSet = NO;
	BOOL maximumDistanceIsSet = NO;

	for (int tokenIndex = 6; tokenIndex < tokens.count; tokenIndex += 2)
	{
		NSString* paramName = [NSString stringWithString:[tokens objectAtIndex: tokenIndex]];
		NSString* paramValue = [NSString stringWithString:[tokens objectAtIndex: tokenIndex + 1]];
		if ([paramName isEqualToString: @"maximumDuration"])
		{
			maximumDuration = [paramValue intValue];
			maximumDurationIsSet = YES;
		}
		else
		if ([paramName isEqualToString: @"minimumDuration"])
		{
			minimumDuration = [paramValue intValue];
			minimumDurationIsSet = YES;
		}
		else
		if ([paramName isEqualToString: @"maximumDistance"])
		{
			maximumDistance = [paramValue intValue];
			maximumDistanceIsSet = YES;
		}
		else
		if ([paramName isEqualToString: @"minimumDistance"])
		{
			minimumDistance = [paramValue intValue];
			minimumDistanceIsSet = YES;
		}
	}

	// Create gesture handler object.

	GestureListener* me = [GestureListener new];

	me.gestureId = gestureIntId;
	me.controller = theController;

	if (1 == type)
	{
		me.recognizer = [FFRPanGestureRecognizer new];
    	[me.recognizer
			addTarget: me
			action: @selector(onPan:)];
	}
	else if (2 == type)
	{
		me.recognizer = [FFRPinchGestureRecognizer new];
    	[me.recognizer
			addTarget: me
			action: @selector(onPinch:)];
	}
	else if (3 == type)
	{
		me.recognizer = [FFRRotationGestureRecognizer new];
    	[me.recognizer
			addTarget: me
			action: @selector(onRotation:)];
	}
	else if (4 == type)
	{
		FFRTapGestureRecognizer* recognizer = [FFRTapGestureRecognizer new];
		if (maximumDurationIsSet)
		{
			recognizer.maximumDuration = maximumDuration;
		}
		if (maximumDistanceIsSet)
		{
			recognizer.maximumDistance = maximumDistance;
		}
    	[recognizer
			addTarget: me
			action: @selector(onTap:)];
		me.recognizer = recognizer;
	}
	else if (5 == type)
	{
		FFRDoubleTapGestureRecognizer* recognizer = [FFRDoubleTapGestureRecognizer new];
		if (maximumDurationIsSet)
		{
			recognizer.maximumDuration = maximumDuration;
		}
		if (maximumDistanceIsSet)
		{
			recognizer.maximumDistance = maximumDistance;
		}
    	[recognizer
			addTarget: me
			action: @selector(onDoubleTap:)];
		me.recognizer = recognizer;
	}
	else if (6 == type)
	{
		FFRLongPressGestureRecognizer* recognizer = [FFRLongPressGestureRecognizer new];
		if (minimumDurationIsSet)
		{
			recognizer.minimumDuration = minimumDuration;
		}
		if (maximumDistanceIsSet)
		{
			recognizer.maximumDistance = maximumDistance;
		}
    	[recognizer
			addTarget: me
			action: @selector(onLongPress:)];
		me.recognizer = recognizer;
	}
	else if (7 == type)
	{
		CreateSwipeGesture(
			me,
			FFRSwipeGestureRecognizerDirectionLeft,
			maximumDuration,
			maximumDurationIsSet,
			minimumDistance,
			minimumDistanceIsSet);
	}
	else if (8 == type)
	{
		CreateSwipeGesture(
			me,
			FFRSwipeGestureRecognizerDirectionRight,
			maximumDuration,
			maximumDurationIsSet,
			minimumDistance,
			minimumDistanceIsSet);
	}
	else if (9 == type)
	{
		CreateSwipeGesture(
			me,
			FFRSwipeGestureRecognizerDirectionUp,
			maximumDuration,
			maximumDurationIsSet,
			minimumDistance,
			minimumDistanceIsSet);
	}
	else if (10 == type)
	{
		CreateSwipeGesture(
			me,
			FFRSwipeGestureRecognizerDirectionDown,
			maximumDuration,
			maximumDurationIsSet,
			minimumDistance,
			minimumDistanceIsSet);
	}

	me.recognizer.side = side;

	[[FFRTouchManager sharedManager] addGestureRecognizer: me.recognizer];

	[theController.gestureListeners setObject: me forKey: gestureId];

	return me;
}

- (void) onPan: (FFRPanGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i,%f,%f)",
		self.gestureId,
		recognizer.state,
		recognizer.translation.width,
		recognizer.translation.height];
	[self.controller callJS: code];
}

- (void) onPinch:(FFRPinchGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i,%f)",
		self.gestureId,
		recognizer.state,
		recognizer.scale];
	[self.controller callJS: code];
}

- (void) onRotation:(FFRRotationGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i,%f)",
		self.gestureId,
		recognizer.state,
		recognizer.rotation];
	[self.controller callJS: code];
}

- (void) onTap:(FFRTapGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i)",
		self.gestureId,
		recognizer.state];
	[self.controller callJS: code];
}

- (void) onDoubleTap:(FFRDoubleTapGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i)",
		self.gestureId,
		recognizer.state];
	[self.controller callJS: code];
}

- (void) onLongPress:(FFRLongPressGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i)",
		self.gestureId,
		recognizer.state];
	[self.controller callJS: code];
}

- (void) onSwipe:(FFRSwipeGestureRecognizer*) recognizer
{
	NSString* code = [NSString stringWithFormat:
		@"fuffr.internal.performCallback(%i,%i)",
		self.gestureId,
		recognizer.state];
	[self.controller callJS: code];
}

@end


/*********** Class TapToShowNavBarView ***********/

@interface TapToShowNavBarView : UIView

@end

@implementation TapToShowNavBarView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame: frame];
	if (self)
	{
		self.multipleTouchEnabled = YES;
		[self setBackgroundColor:[UIColor redColor]];
	}

	return self;
}

- (void) touchesBegan: (NSSet *)touches withEvent: (UIEvent *)event
{
    NSLog(@"touchesBegan");
}

- (void) touchesMoved: (NSSet *)touches withEvent: (UIEvent *)event
{
    NSLog(@"touchesMoved");
}

- (void) touchesEnded: (NSSet *)touches withEvent: (UIEvent *)event
{
    NSLog(@"touchesEnded");
}

- (void) touchesCancelled: (NSSet *)touches withEvent: (UIEvent *)event
{
    NSLog(@"touchesCancelled");
}

@end


/*********** Class FuffrBoxView ***********/

@interface FuffrBoxView : UIView

/** The web view. */
@property UIWebView* webView;

/** The url field. */
@property UITextField* urlField;

/** The Back button. */
@property UIButton* buttonBack;

/** The Go button. */
@property UIButton* buttonGo;

@property TapToShowNavBarView* tapBarView;

@end

@implementation FuffrBoxView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame: frame];
	if (self)
	{
    	self.autoresizingMask =
			UIViewAutoresizingFlexibleHeight |
			UIViewAutoresizingFlexibleWidth;
		self.multipleTouchEnabled = YES;
		[self setBackgroundColor:[UIColor whiteColor]];
		[self createSubviews];
	}

	return self;
}

- (void) createSubviews
{
	// Create Back button.
	self.buttonBack = [UIButton buttonWithType: UIButtonTypeSystem];
	[self.buttonBack setTitle: @"Back" forState: UIControlStateNormal];
    [self addSubview: self.buttonBack];

	// Create URL field.
	self.urlField = [[UITextField alloc] initWithFrame: CGRectZero];
	self.urlField.clearButtonMode = UITextFieldViewModeNever;
	[self.urlField setKeyboardType: UIKeyboardTypeURL];
	self.urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self addSubview: self.urlField];

	// Create Go button.
	self.buttonGo = [UIButton buttonWithType: UIButtonTypeSystem];
	[self.buttonGo setTitle: @"Go" forState: UIControlStateNormal];
    [self addSubview: self.buttonGo];

	// Create Web view.
	self.webView = [[UIWebView alloc] initWithFrame: CGRectZero];
	self.webView.autoresizingMask =
		UIViewAutoresizingFlexibleHeight |
		UIViewAutoresizingFlexibleWidth;
	self.webView.scalesPageToFit = NO; //YES;
	self.webView.scrollView.bounces = NO;
	[self.webView setBackgroundColor:[UIColor whiteColor]];
    [self addSubview: self.webView];

	self.tapBarView = [[TapToShowNavBarView alloc] initWithFrame: CGRectZero];
    [self addSubview: self.tapBarView];
}

- (void) layoutSubviews
{
	CGFloat toolbarOffsetY = 0;
	CGFloat toolbarHeight = 40;

	CGRect viewBounds = self.bounds;

	CGRect bounds; // Temporary rect

	// Size Back button.
    [self.buttonBack setFrame: CGRectMake(3, toolbarOffsetY, 40, toolbarHeight)];

	// Size URL field.
	bounds = CGRectMake(50, toolbarOffsetY + 1, 0, toolbarHeight);
	bounds.size.width = viewBounds.size.width - 90;
	[self.urlField setFrame: bounds];

	// Size tap bar.
	bounds = CGRectMake(50, toolbarOffsetY + 1, 0, toolbarHeight);
	bounds.size.width = viewBounds.size.width - 90;
	[self.tapBarView setFrame: bounds];

	// Size Go button.
	bounds = CGRectMake(0, toolbarOffsetY, 40, toolbarHeight);
	bounds.origin.x = viewBounds.size.width - 40;
    [self.buttonGo setFrame: bounds];

	// Size Web view.
	bounds = viewBounds;
	//bounds = CGRectOffset(bounds, 0, 20);
	//bounds = CGRectInset(bounds, 0, 50);
	bounds.origin.y = toolbarHeight;
	bounds.size.height -= bounds.origin.y;
	[self.webView setFrame: bounds];
}

@end

/*********** Class AppViewController ***********/

@implementation AppViewController

- (id) init
{
	self = [super init];

	// Global reference to the AppViewController instance.
	theAppViewController = self;

    return self;
}

- (void) loadView
{
	// Create application root view.
	self.view = [[FuffrBoxView alloc] initWithFrame: CGRectZero];
}

- (UIWebView*) webView
{
	return self.rootView.webView;
}

- (FuffrBoxView*) rootView
{
	return (FuffrBoxView*) self.view;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

	// Set property that fixes web view layout problem.
	// http://stackoverflow.com/questions/18947872/ios7-added-new-whitespace-in-uiwebview-removing-uiwebview-whitespace-in-ios7
	self.automaticallyAdjustsScrollViewInsets = NO;

	// Set the web view delegate.
	self.webView.delegate = self;

	// Set button event handlers.
	[self.rootView.buttonGo
		addTarget: self
		action: @selector(onButtonGo:)
		forControlEvents: UIControlEventTouchUpInside];
	[self.rootView.buttonBack
		addTarget: self
		action: @selector(onButtonBack:)
		forControlEvents: UIControlEventTouchUpInside];

	// Set saved URL field content.
	[self setSavedURL];

	// Load initial content into the view view.
	[self loadWebViewContent];

	// Create object that handles calls from JavaScript.
	[NSURLProtocol registerClass: [URLProtocolFuffrBridge class]];

	// Create gesture listeners.
	self.gestureListeners = [NSMutableDictionary new];
}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

-(void) loadWebViewContent
{
	NSURL* startPageURL;
	NSURL* testURL = [NSURL URLWithString: URL_ARE_YOU_THERE];
	NSData* data = [NSData dataWithContentsOfURL: testURL];

	if (data)
	{
		// Set URL to online page.
		startPageURL = [NSURL URLWithString: URL_START_PAGE];
	}
	else
	{
		// Set URL to local start page.
		NSString* path = [[NSBundle mainBundle]
			pathForResource:@"index" ofType:@"html" inDirectory:@"www"];
		startPageURL = [NSURL fileURLWithPath:path isDirectory:NO];
	}

	// Load URL into web view.
	NSURLRequest* request = [NSURLRequest
		requestWithURL: startPageURL
		cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
		timeoutInterval: 10];
	[self.webView loadRequest: request];
}

/*
// WebGL enable hack commented out in production version.

#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"

-(void) enableWebGL
{
	id webDocumentView = [self.webView performSelector: @selector(_browserView)];
    id backingWebView = [webDocumentView performSelector: @selector(webView)];

	// Cannot use performSelector: since _setWebGLEnabled: takes
	// a primitibe BOOL param. Therefore using NSInvocation.
	// Compiler raises error if sending _setWebGLEnabled: in the normal way.
	SEL selector = NSSelectorFromString(@"_setWebGLEnabled:");
	BOOL flag = YES;
	void* value = &flag;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		[backingWebView methodSignatureForSelector: selector]];
    [invocation setSelector: selector];
    [invocation setTarget: backingWebView];
    [invocation setArgument: value atIndex: 2];
    [invocation invoke];
}

#pragma clang diagnostic pop
*/

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];

	// Commented out WebGL code in production version.
	//[self enableWebGL];

	// Connect to Fuffr and setup touch events.
	[self setupFuffr];
}

- (void) viewWillDisappear: (BOOL)animated
{
	// Clear the web view delegate.
	self.webView.delegate = nil;

	// Disconnects Fuffr.
	[[FFRTouchManager sharedManager] shutDown];

    [super viewWillDisappear: animated];
}

-(void) viewDidDisappear: (BOOL)animated
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) setupFuffr
{
	[self connectToFuffr];

	[self setupTouches];
}

- (void) connectToFuffr
{
	[self.view ffr_makeToast: @"Scanning for Fuffr"];

	// Get a reference to the touch manager.
	// First time the manager is requested, it will be created
	// and start scanning for a Fuffr device.
	FFRTouchManager* manager = [FFRTouchManager sharedManager];

	// Set connected and disconnected action blocks.
	[manager
		onFuffrConnected:
		^{
			NSLog(@"Fuffr Connected");
			[self.view ffr_makeToast: @"Fuffr Connected"];
			FuffrIsConnected = YES;
			[self callJS: @"fuffr.on.connected()"];
		}
		onFuffrDisconnected:
		^{
			NSLog(@"Fuffr Disconnected");
			[self.view ffr_makeToast: @"Fuffr Disconnected"];
			FuffrIsConnected = NO;
			[self callJS: @"fuffr.on.disconnected()"];
		}];
}

- (void) setupTouches
{
	// Register listener for all sides. The JavaScript application
	// can still enable/disable sides, this is a separate mechanism
	// that updates the actual configuraton used by the hardware.
	// Sides below are used for filtering touches by side, and here
	// we use no filtering (all sides enabled turns off filtering).
	[[FFRTouchManager sharedManager]
		addTouchObserver: self
		touchBegan: @selector(touchesBegan:)
		touchMoved: @selector(touchesMoved:)
		touchEnded: @selector(touchesEnded:)
		sides: FFRSideRight | FFRSideLeft | FFRSideTop | FFRSideBottom];
}

- (void) executeJavaScriptCommand: (NSString*) command
{
	//NSLog(@"executeJavaScriptCommand: %@", command);

	NSArray* tokens = [command componentsSeparatedByString:@"@"];
	NSString* commandName = [NSString stringWithString:[tokens objectAtIndex: 1]];

	if ([commandName isEqualToString: @"domLoaded"])
	{
		[self jsCommandDomLoaded: tokens];
	}
	else if ([commandName isEqualToString: @"enableSides"])
	{
		[self jsCommandEnableSides: tokens];
	}
	else if ([commandName isEqualToString: @"addGesture"])
	{
		[self jsCommandAddGesture: tokens];
	}
	else if ([commandName isEqualToString: @"removeGesture"])
	{
		[self jsCommandRemoveGesture: tokens];
	}
	else if ([commandName isEqualToString: @"updateFirmware"])
	{
		[self jsCommandUpdateFirmware: tokens];
	}
	else if ([commandName isEqualToString: @"consoleLog"])
	{
		[self jsCommandConsoleLog: tokens];
	}
}

- (void) jsCommandDomLoaded: (NSArray*) tokens
{
	if (FuffrIsConnected)
	{
		[self callJS: @"fuffr.on.connected()"];
	}
}

- (void) jsCommandEnableSides: (NSArray*) tokens
{
	NSString* sides = [NSString stringWithString:[tokens objectAtIndex: 2]];
	NSString* touches = [NSString stringWithString:[tokens objectAtIndex: 3]];
	
	[[FFRTouchManager sharedManager] useSensorService:
	^{
		[[FFRTouchManager sharedManager]
			enableSides: (FFRSide)[sides intValue]
			touchesPerSide: [NSNumber numberWithInt: [touches intValue]]];
	}];
}

- (void) jsCommandAddGesture: (NSArray*) tokens
{
	[GestureListener
		withTokens: tokens
		controller: self];
}

- (void) jsCommandRemoveGesture: (NSArray*) tokens
{
	NSString* gestureId = [NSString stringWithString:[tokens objectAtIndex: 2]];

	// Remove gesture from list of gesture listeners.
	[self.gestureListeners removeObjectForKey: gestureId];
}

- (void) jsCommandRemoveAllGestures: (NSArray*) tokens
{
	[self.gestureListeners removeAllObjects];
}

- (void) jsCommandUpdateFirmware: (NSArray*) tokens
{
	[[FFRTouchManager sharedManager] updateFirmwareFromURL: URL_FIRMWARE_LIST];
}

- (void) jsCommandConsoleLog: (NSArray*) tokens
{
	NSString* message = [NSString stringWithString:[tokens objectAtIndex: 2]];
	NSLog(@"%@", message);
}

- (void) onButtonBack: (id)sender
{
	// Hack to update firmware when pressing Back:
	//[self jsCommandUpdateFirmware: nil];

	[self.webView goBack];
}

- (void) onButtonGo: (id)sender
{
	[self.view endEditing: YES];

	NSString* urlString = self.rootView.urlField.text;

	if (![urlString hasPrefix: @"http"])
	{
		urlString = [NSString stringWithFormat:@"http://%@", urlString];
	}

	[self saveURL: urlString];

	NSURL* url = [NSURL URLWithString: urlString];
	NSURLRequest* request = [NSURLRequest
		requestWithURL: url
		cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
		timeoutInterval: 10];
	[self.webView loadRequest: request];
}

- (void) saveURL: (NSString*)url
{
	[[NSUserDefaults standardUserDefaults]
		setObject: url
		forKey: @"FuffrBoxSavedURL"];
}

- (void) setSavedURL
{
	NSString* url = [[NSUserDefaults standardUserDefaults]
		stringForKey: @"FuffrBoxSavedURL"];
	if (url)
	{
		self.rootView.urlField.text = url;
	}
	else
	{
		self.rootView.urlField.text = URL_INITIAL_URL_FIELD;
	}
}

- (void) touchesBegan: (NSSet*)touches
{
	[self callJS: @"fuffr.on.touchesBegan" withTouches: touches];
}

- (void) touchesMoved: (NSSet*)touches
{
	[self callJS: @"fuffr.on.touchesMoved" withTouches: touches];
}

- (void) touchesEnded: (NSSet*)touches
{
	[self callJS: @"fuffr.on.touchesEnded" withTouches: touches];
}

// Example call: fuffr.on.touchesBegan([{...},{...},...])
- (void) callJS: (NSString*) functionName withTouches: (NSSet*) touches
{
	NSString* script = [NSString stringWithFormat:
		@"try{%@(%@)}catch(err){}",
		functionName,
		[self touchesAsJsArray: touches]];
	dispatch_async(dispatch_get_main_queue(),
	^{
		[self.webView stringByEvaluatingJavaScriptFromString: script];
    });
}

- (void) callJS: (NSString*) code
{
	NSString* script = [NSString stringWithFormat:
		@"try{%@}catch(err){}",
		code];
	dispatch_async(dispatch_get_main_queue(),
	^{
		[self.webView stringByEvaluatingJavaScriptFromString: script];
    });
}

- (NSString*) touchesAsJsArray: (NSSet*) touches
{
	NSMutableString* arrayString = [NSMutableString stringWithCapacity: 300];

	[arrayString appendString: @"["];

	int counter = (int)touches.count;
	for (FFRTouch* touch in touches)
	{
		[arrayString appendString: [self touchAsJsObject: touch]];
		if (--counter > 0)
		{
			[arrayString appendString: @","];
		}
	}

	[arrayString appendString: @"]"];

	return arrayString;
}

- (NSString*) touchAsJsObject: (FFRTouch*)touch
{
	return [NSString stringWithFormat:
		@"{id:%d,side:%d,x:%f,y:%f,prevx:%f,prevy:%f,normx:%f,normy:%f}",
		(int)touch.identifier,
		touch.side,
		touch.location.x,
		touch.location.y,
		touch.previousLocation.x,
		touch.previousLocation.y,
		touch.normalizedLocation.x,
		touch.normalizedLocation.y];
}

/**
 * From interface UIWebViewDelegate.
 */
- (BOOL)webView:(UIWebView *)webView
	shouldStartLoadWithRequest:(NSURLRequest *)request
	navigationType:(UIWebViewNavigationType)navigationType
{
	//NSLog(@"Loading URL :%@", request.URL.absoluteString);

	//return FALSE; //to stop loading
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	//NSLog(@"webViewDidStartLoad");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	//NSLog(@"webViewDidFinishLoad");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	NSLog(@"Failed to load page: %@", [error debugDescription]);

	// Show error page.

	// Set URL to local error page.
	NSString* path = [[NSBundle mainBundle]
		pathForResource:@"error" ofType:@"html" inDirectory:@"www"];
	NSURL* errorPageURL = [NSURL fileURLWithPath:path isDirectory:NO];

	// Load URL into web view.
	NSURLRequest* request = [NSURLRequest
		requestWithURL: errorPageURL
		cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
		timeoutInterval: 10];
	[self.webView loadRequest: request];
}

@end
