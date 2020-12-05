//  Copyright (C) 2015-2019 Pierre-Olivier Latour <info@pol-online.net>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#if !__has_feature(objc_arc)
#error This file requires ARC
#endif

#import <QuartzCore/QuartzCore.h>

#import "GIWindowController.h"
#import "GIColorView.h"
#import "GIConstants.h"
#import "GIModalWindow.h"

#import "XLFacilityMacros.h"
#import "GIGraphView.h"

#define kOverlayAnimationInDuration 0.2  // seconds
#define kOverlayAnimationOutDuration 0.15  // seconds

@interface GIWindowController ()
@property(nonatomic, strong) IBOutlet GIColorView* overlayView;
@property(nonatomic, weak) IBOutlet NSTextField* overlayTextField;
@property(nonatomic, weak) IBOutlet NSButton* overlayCloseButton;
@property(nonatomic, readonly) NSMapTable *cachedWindowsForModalViews;
@end

@interface GIFieldEditor : NSTextView
@end

@implementation GIFieldEditor

- (void)keyDown:(NSEvent*)event {
  if (event.keyCode == kGIKeyCode_Tab) {
    if (event.modifierFlags & NSShiftKeyMask) {
      [self.window selectPreviousKeyView:nil];
    } else {
      [self.window selectNextKeyView:nil];
    }
  } else {
    [self.nextResponder tryToPerform:@selector(keyDown:) with:event];
  }
}

- (void)keyUp:(NSEvent*)event {
  [self.nextResponder tryToPerform:@selector(keyUp:) with:event];
}

@end

@implementation GIWindow {
  GIFieldEditor* _fieldEditor;
}

@dynamic windowController;  // Prevent synthetizing a property overriding the superclass methods

// For NSTextFields that are only selectable, return a custom field editor that forwards all key events to the next responder
- (NSText*)fieldEditor:(BOOL)createFlag forObject:(id)anObject {
  if ([anObject isKindOfClass:[NSTextField class]] && [(NSTextField*)anObject isSelectable] && ![(NSTextField*)anObject isEditable]) {
    if (!_fieldEditor && createFlag) {
      _fieldEditor = [[GIFieldEditor alloc] init];
      _fieldEditor.fieldEditor = YES;
    }
    return _fieldEditor;
  }
  return [super fieldEditor:createFlag forObject:anObject];
}

static void _WalkViewTree(NSView* view, NSMutableArray* array) {
  for (NSView* subview in view.subviews) {
    if (!subview.hidden) {
      if ([subview isKindOfClass:[NSTextField class]] || [subview isKindOfClass:[NSTextView class]] || ([subview isKindOfClass:[NSTableView class]] && (![[(NSTableView*)subview delegate] respondsToSelector:@selector(selectionShouldChangeInTableView:)] || [[(NSTableView*)subview delegate] selectionShouldChangeInTableView:(NSTableView*)subview]))  // Allows NSTableView assuming it doesn't return NO for -selectionShouldChangeInTableView:
          || [subview isKindOfClass:[GIGraphView class]]) {  // Always allow GIGraphView which can become first-responder
        if (subview.acceptsFirstResponder) {
          [array addObject:subview];
        }
      }
      _WalkViewTree(subview, array);
    }
  }
}

- (void)_selectKeyView:(NSInteger)delta {
  NSMutableArray* array = [[NSMutableArray alloc] init];
  _WalkViewTree(self.contentView, array);
  for (NSToolbarItem* item in self.toolbar.items) {
    _WalkViewTree(item.view, array);
  }
  if (array.count) {
    NSUInteger index = [array indexOfObjectIdenticalTo:self.firstResponder];
    if (index == NSNotFound) {
      index = 0;
    } else {
      index = (index + array.count + delta) % array.count;
    }
    [self makeFirstResponder:array[index]];
  } else {
    XLOG_DEBUG_UNREACHABLE();
  }
}

- (void)selectNextKeyView:(id)sender {
  [self _selectKeyView:1];
}

- (void)selectPreviousKeyView:(id)sender {
  [self _selectKeyView:-1];
}

- (void)keyDown:(NSEvent*)event {
  if (![self.windowController.delegate windowController:self.windowController handleKeyDown:event]) {
    [super keyDown:event];
  }
}

- (void)sendEvent:(NSEvent*)event {
  BOOL escapeKeyDown = (event.type == NSKeyDown) && (event.keyCode == kGIKeyCode_Esc);
  if (escapeKeyDown && self.windowController.overlayVisible) {
    [self.windowController hideOverlay];
  } else {
    [super sendEvent:event];
  }
}

@end

static NSColor* _helpColor = nil;
static NSColor* _informationalColor = nil;
static NSColor* _warningColor = nil;

@implementation GIWindowController {
  NSTrackingArea* _area;
  CFRunLoopTimerRef _overlayTimer;  // Can't use a NSTimer because of retain-cycle
  CFTimeInterval _overlayDelay;
}

@dynamic window;  // Prevent synthetizing a property overriding the superclass methods

+ (void)initialize {
  _helpColor = [NSColor colorWithDeviceRed:(0.0 / 255.0) green:(104.0 / 255.0) blue:(217.0 / 255.0) alpha:0.9];
  _informationalColor = [NSColor colorWithDeviceRed:(75.0 / 255.0) green:(75.0 / 255.0) blue:(75.0 / 255.0) alpha:0.9];
  _warningColor = [NSColor colorWithDeviceRed:(204.0 / 255.0) green:(82.0 / 255.0) blue:(82.0 / 255.0) alpha:0.9];
}

static void _TimerCallBack(CFRunLoopTimerRef timer, void* info) {
  @autoreleasepool {
    [(__bridge GIWindowController*)info dismissOverlay:nil];
  }
}

- (instancetype)initWithWindow:(NSWindow*)window {
  if ((self = [super initWithWindow:window])) {
    [[NSBundle bundleForClass:[GIWindowController class]] loadNibNamed:@"GIWindowController" owner:self topLevelObjects:NULL];
    XLOG_DEBUG_CHECK(_overlayView);

    // Force a dark appearance of the overlay. Set in the nib for 10.14.
    if (@available(macOS 10.14, *)) {
    } else {
      _overlayTextField.textColor = NSColor.whiteColor;
      _overlayCloseButton.cell.backgroundStyle = NSBackgroundStyleEmphasized;
    }

    _area = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited) owner:self userInfo:nil];
    [_overlayView addTrackingArea:_area];

    CFRunLoopTimerContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
    _overlayTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, HUGE_VALF, HUGE_VALF, 0, 0, _TimerCallBack, &context);
    CFRunLoopAddTimer(CFRunLoopGetMain(), _overlayTimer, kCFRunLoopCommonModes);
  }
  return self;
}

- (void)dealloc {
  CFRunLoopTimerInvalidate(_overlayTimer);
  CFRelease(_overlayTimer);
}

- (BOOL)isOverlayVisible {
  return (_overlayView.superview != nil);
}

- (void)showOverlayWithStyle:(GIOverlayStyle)style format:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);

  [self showOverlayWithStyle:style message:message];
}

- (void)showOverlayWithStyle:(GIOverlayStyle)style message:(NSString*)message {
  switch (style) {
    case kGIOverlayStyle_Help:
      _overlayView.backgroundColor = _helpColor;
      _overlayDelay = 4.0;
      break;

    case kGIOverlayStyle_Informational:
      _overlayView.backgroundColor = _informationalColor;
      _overlayDelay = 3.0;
      break;

    case kGIOverlayStyle_Warning:
      _overlayView.backgroundColor = _warningColor;
      _overlayDelay = 5.0;
      break;
  }

  if (_overlayView.superview == nil) {
    NSRect bounds = [self.window.contentView bounds];
    NSRect frame = _overlayView.frame;
    _overlayView.frame = NSMakeRect(0, bounds.size.height - frame.size.height, bounds.size.width, frame.size.height);
    [self.window.contentView addSubview:_overlayView];  // Must be above everything else
    _overlayView.hidden = YES;
    [CATransaction flush];

    _overlayTextField.stringValue = message;
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:kOverlayAnimationInDuration];
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [_overlayView.animator setHidden:NO];
    [NSAnimationContext endGrouping];
  } else {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:kOverlayAnimationInDuration];
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
      _overlayTextField.stringValue = message;
      [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:kOverlayAnimationInDuration];
      [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
      [_overlayTextField.animator setAlphaValue:1.0];
      [NSAnimationContext endGrouping];
    }];
    [_overlayTextField.animator setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
  }

  CFRunLoopTimerSetNextFireDate(_overlayTimer, CFAbsoluteTimeGetCurrent() + _overlayDelay);
}

- (void)hideOverlay {
  if (_overlayView.superview) {
    NSRect frame = _overlayView.frame;
    NSRect newFrame = NSOffsetRect(frame, 0, frame.size.height);

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:kOverlayAnimationOutDuration];
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
      [_overlayView removeFromSuperview];
    }];
    [_overlayView.animator setFrame:newFrame];
    [NSAnimationContext endGrouping];

    CFRunLoopTimerSetNextFireDate(_overlayTimer, HUGE_VALF);
  } else {
    XLOG_DEBUG_UNREACHABLE();
  }
}

- (IBAction)dismissOverlay:(id)sender {
  [self hideOverlay];
}

- (void)mouseEntered:(NSEvent*)event {
  if (event.trackingArea == _area) {
    CFRunLoopTimerSetNextFireDate(_overlayTimer, HUGE_VALF);
  } else {
    [super mouseEntered:event];
  }
}

- (void)mouseExited:(NSEvent*)event {
  if (event.trackingArea == _area) {
    CFRunLoopTimerSetNextFireDate(_overlayTimer, CFAbsoluteTimeGetCurrent() + _overlayDelay);
  } else {
    [super mouseExited:event];
  }
}

- (void)runModalView:(NSView*)view withInitialFirstResponder:(NSView*)initialFirstResponder completionHandler:(void (^)(BOOL success))handler {
  XLOG_DEBUG_CHECK(handler);

  // The app reuses modal views. If the views were to be reused across windows,
  // the "default" button (the one highlighted with the system accent color)
  // loses its default status, among other wonky issues. It makes sense then to
  // reuse their windows similarly. If the app were not reusing modal views, or
  // was reusing window controllers, this wouldn't be a problem.
  NSWindow* window = [_cachedWindowsForModalViews objectForKey:view];
  if (!window) {
    window = [GIModalWindow windowForCenteredSheetWithView:view];
    if (!_cachedWindowsForModalViews) {
      _cachedWindowsForModalViews = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    [_cachedWindowsForModalViews setObject:window forKey:view];
  }
  window.initialFirstResponder = initialFirstResponder;

  // Performed on the main run loop instead of the main queue (including the
  // completion handler) to ensure that the main queue is serviced instead of
  // blocked during a modal session.
  GIPerformOnMainRunLoop(^{
    [self.window beginSheet:window
          completionHandler:^(NSModalResponse returnCode) {
            // Defer the callback a bit to ensure animations run in parallel to callback execution
            GIPerformOnMainRunLoop(^{
              handler(returnCode == NSModalResponseOK);
            });
          }];
  });
}

- (void)stopModalView:(BOOL)success {
  [self.window endSheet:self.window.attachedSheet returnCode:(success ? NSModalResponseOK : NSModalResponseCancel)];
}

@end

@implementation GIViewController (GIWindowController)

- (IBAction)finishModalView:(id)sender {
  [self.windowController stopModalView:YES];
}

- (IBAction)cancelModalView:(id)sender {
  [self.windowController stopModalView:NO];
}

@end
