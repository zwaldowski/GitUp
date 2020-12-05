//  Copyright (C) 2015-2020 Pierre-Olivier Latour <info@pol-online.net>
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

#import "GIModalWindow.h"
#import "NSColor+GINamedColors.h"

@interface GIModalDimmingView : NSBox
- (instancetype)initWithContentView:(NSView*)contentView;
@end

@interface GIModalSheetView : NSBox
- (instancetype)initWithContentView:(NSView*)contentView;
@end

@implementation GIModalWindow

+ (NSWindow*)windowForCenteredSheetWithView:(NSView*)view {
  // If the app were not reusing modal views, or were reusing window controllers
  // instead, the system behavior would all work out normally. As it stands,
  // the "default" button (the one highlighted with the system accent color)
  // loses its default status if a modal view is reused across different
  // windows. Emulate reuse of window controllers to avoid the problem.
  static dispatch_once_t onceToken;
  static NSMapTable* cachedWindowsForViews;
  dispatch_once(&onceToken, ^{
    cachedWindowsForViews = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
  });

  NSWindow* window = [cachedWindowsForViews objectForKey:view];
  if (!window) {
    if (@available(macOS 11, *)) {
      window = [[NSWindow alloc] initWithContentRect:view.frame styleMask:NSWindowStyleMaskTitled | NSFullSizeContentViewWindowMask backing:NSBackingStoreBuffered defer:NO];
      window.releasedWhenClosed = NO;
      window.contentView = view;
    } else {
      window = [[GIModalWindow alloc] initWithContentView:view];
    }
    [cachedWindowsForViews setObject:window forKey:view];
  }
  return window;
}

- (instancetype)initWithContentView:(NSView*)contentView {
  self = [super initWithContentRect:contentView.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
  if (!self) {
    return nil;
  }

  self.releasedWhenClosed = NO;
  self.backgroundColor = NSColor.clearColor;
  self.opaque = NO;
  self.contentView = [[GIModalDimmingView alloc] initWithContentView:contentView];

  return self;
}

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen*)screen {
  if (self.sheetParent) {
    return self.sheetParent.frame;
  } else {
    return [super constrainFrameRect:frameRect toScreen:screen];
  }
}

- (NSTimeInterval)animationResizeTime:(NSRect)newFrame {
  if (newFrame.size.height < 1) {
    return 0;
  } else {
    return [super animationResizeTime:newFrame];
  }
}

- (BOOL)canBecomeKeyWindow {
  return YES;
}

@end

// MARK: -

@implementation GIModalDimmingView

- (instancetype)initWithContentView:(NSView*)contentView {
  self = [super initWithFrame:NSZeroRect];
  if (!self) {
    return nil;
  }

  self.boxType = NSBoxCustom;
  self.contentViewMargins = NSZeroSize;
  self.borderWidth = 0;
  self.cornerRadius = 4;
  // This is for dimming so deliberately does not adapt for dark mode.
  self.fillColor = [NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:0.4];

  GIModalSheetView* sheetView = [[GIModalSheetView alloc] initWithContentView:contentView];
  sheetView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:sheetView];

  [NSLayoutConstraint activateConstraints:@[
    [NSLayoutConstraint constraintWithItem:sheetView
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.contentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1
                                  constant:0],
    [NSLayoutConstraint constraintWithItem:sheetView
                                 attribute:NSLayoutAttributeCenterY
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.contentView
                                 attribute:NSLayoutAttributeCenterY
                                multiplier:1
                                  constant:0]
  ]];

  return self;
}

- (void)mouseDown:(NSEvent*)event {
  if (!self.window.sheetParent) {
    return;
  }

  if (@available(macOS 10.11, *)) {
    [self.window.sheetParent performWindowDragWithEvent:event];
  }
}

@end

@implementation GIModalSheetView

- (instancetype)initWithContentView:(NSView*)contentView {
  self = [super initWithFrame:NSZeroRect];
  if (!self) {
    return nil;
  }

  self.boxType = NSBoxCustom;
  self.contentViewMargins = NSZeroSize;
  self.borderWidth = 1;
  self.cornerRadius = 6;
  self.borderColor = NSColor.gitUpSeparatorColor;
  self.fillColor = NSColor.windowBackgroundColor;

  [NSLayoutConstraint activateConstraints:@[
    [NSLayoutConstraint constraintWithItem:self
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1
                                  constant:NSWidth(contentView.frame) + 2],
    [NSLayoutConstraint constraintWithItem:self
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1
                                  constant:NSHeight(contentView.frame) + 2]
  ]];

  // Only set the content view after taking its size for the container.
  self.contentView = contentView;

  return self;
}

@end
