//  Copyright (C) 2015-2018 Pierre-Olivier Latour <info@pol-online.net>
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

#import "GIPrivate.h"

#define kTextFontSize 10
#define kTextLineHeightPadding 3
#define kTextLineDescentAdjustment 1

NSDictionary *GIDiffViewLineAttributes = nil;
NSDictionary *GIDiffViewGutterAttributes = nil;

CTLineRef GIDiffViewAddedLine = NULL;
CTLineRef GIDiffViewDeletedLine = NULL;

CGFloat GIDiffViewLineHeight = 0.0;
CGFloat GIDiffViewLineDescent = 0.0;

NSColor* GIDiffViewDeletedBackgroundColor = nil;
NSColor* GIDiffViewDeletedHighlightColor = nil;
NSColor* GIDiffViewAddedBackgroundColor = nil;
NSColor* GIDiffViewAddedHighlightColor = nil;
NSColor* GIDiffViewSeparatorBackgroundColor = nil;
NSColor* GIDiffViewSeparatorLineColor = nil;
NSColor* GIDiffViewSeparatorTextColor = nil;
NSColor* GIDiffViewVerticalLineColor = nil;

NSString* const GIDiffViewMissingNewlinePlaceholder = @"🚫\n";
NSString* const GIDiffViewAddedLineIndicator = @"+";
NSString* const GIDiffViewDeletedLineIndicator = @"-";

@implementation GIDiffView

+ (void)initialize {
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.lineHeightMultiple = 1.2;
  paragraphStyle.lineSpacing = 2;
  paragraphStyle.minimumLineHeight = 14;
  paragraphStyle.maximumLineHeight = 14;

  NSFont *font = [NSFont userFixedPitchFontOfSize:kTextFontSize];

  GIDiffViewLineAttributes = @{
    NSParagraphStyleAttributeName: paragraphStyle,
    NSFontAttributeName: font,
    NSForegroundColorAttributeName: [NSColor textColor],
  };

  GIDiffViewGutterAttributes = @{
    NSParagraphStyleAttributeName: paragraphStyle,
    NSFontAttributeName: font,
    NSForegroundColorAttributeName: [NSColor tertiaryLabelColor],
  };

  CFAttributedStringRef addedString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)GIDiffViewAddedLineIndicator, (CFDictionaryRef)GIDiffViewGutterAttributes);
  GIDiffViewAddedLine = CTLineCreateWithAttributedString(addedString);
  CFRelease(addedString);

  CFAttributedStringRef deletedString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)GIDiffViewDeletedLineIndicator, (CFDictionaryRef)GIDiffViewGutterAttributes);
  GIDiffViewDeletedLine = CTLineCreateWithAttributedString(deletedString);
  CFRelease(deletedString);

  CGFloat ascent;
  CGFloat descent;
  CGFloat leading;
  CTLineGetTypographicBounds(GIDiffViewAddedLine, &ascent, &descent, &leading);
  GIDiffViewLineHeight = ceilf(ascent + descent + leading) + kTextLineHeightPadding;
  GIDiffViewLineDescent = ceilf(descent) + kTextLineDescentAdjustment;

  GIDiffViewDeletedBackgroundColor = [NSColor colorWithDeviceRed:1.0 green:0.9 blue:0.9 alpha:1.0];
  GIDiffViewDeletedHighlightColor = [NSColor colorWithDeviceRed:1.0 green:0.7 blue:0.7 alpha:1.0];
  GIDiffViewAddedBackgroundColor = [NSColor colorWithDeviceRed:0.85 green:1.0 blue:0.85 alpha:1.0];
  GIDiffViewAddedHighlightColor = [NSColor colorWithDeviceRed:0.7 green:1.0 blue:0.7 alpha:1.0];
  GIDiffViewSeparatorBackgroundColor = [NSColor colorWithDeviceRed:0.97 green:0.97 blue:0.97 alpha:1.0];
  GIDiffViewSeparatorLineColor = [NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1.0];
  GIDiffViewSeparatorTextColor = [NSColor colorWithDeviceRed:0.65 green:0.65 blue:0.65 alpha:1.0];
  GIDiffViewVerticalLineColor = [NSColor colorWithDeviceRed:0.85 green:0.85 blue:0.85 alpha:0.6];
}

- (void)didFinishInitializing {
  _backgroundColor = [NSColor whiteColor];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  if ((self = [super initWithFrame:frameRect])) {
    [self didFinishInitializing];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
  if ((self = [super initWithCoder:coder])) {
    [self didFinishInitializing];
  }
  return self;
}

- (BOOL)isOpaque {
  return YES;
}

- (BOOL)isEmpty {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

- (void)didUpdatePatch {
  [self clearSelection];
}

- (void)setPatch:(GCDiffPatch*)patch {
  if (patch != _patch) {
    _patch = patch;
    [self didUpdatePatch];
  }
}

- (CGFloat)updateLayoutForWidth:(CGFloat)width {
  [self doesNotRecognizeSelector:_cmd];
  return 0.0;
}

- (BOOL)hasSelection {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

- (void)clearSelection {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)getSelectedText:(NSString**)text oldLines:(NSIndexSet**)oldLines newLines:(NSIndexSet**)newLines {
  [self doesNotRecognizeSelector:_cmd];
}

@end
