//
//  test
//
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
#import "GIAppKit.h"

#define kTextLineNumberMargin (5.0 * 8.0)
#define kTextInsetLeft 15.0
#define kSeparatorHairline 0.5

@interface GIUnifiedDiffBlock: NSTextBlock
@end

@implementation GIUnifiedDiffBlock

- (instancetype)init {
  self = [super init];
  if (!self) { return nil; }

  [self setContentWidth:100 type:NSTextBlockPercentageValueType];

  return self;
}

- (BOOL)selectedRanges:(NSArray *)array hasRangeContaining:(NSRange)charRange {
  for (NSValue *value in array) {
    NSRange selectedRange = value.rangeValue;
    if (NSEqualRanges(NSIntersectionRange(selectedRange, charRange), charRange)) {
      return YES;
    }
  }
  return NO;
}

- (void)drawBackgroundWithFrame:(NSRect)frameRect inView:(NSView *)controlView characterRange:(NSRange)charRange layoutManager:(NSLayoutManager *)layoutManager {
  [super drawBackgroundWithFrame:frameRect inView:controlView characterRange:charRange layoutManager:layoutManager];

  if ([controlView isKindOfClass:NSTextView.class]) {
    NSTextView *textView = (NSTextView *)controlView;
    if ([self selectedRanges:textView.selectedRanges hasRangeContaining:charRange]) {
      NSColor* selectedColor = textView.window.keyWindow && textView.window.firstResponder == textView ? [NSColor selectedTextBackgroundColor] : [NSColor unemphasizedSelectedTextBackgroundColor];
      [selectedColor setFill];
      NSRectFill(frameRect);
    }
  }
}

@end


@interface GIUnifiedDiffSeparatorBlock: GIUnifiedDiffBlock
@end

@implementation GIUnifiedDiffSeparatorBlock

- (instancetype)init {
  self = [super init];
  if (!self) { return nil; }

  self.backgroundColor = GIDiffViewSeparatorBackgroundColor;
  [self setBorderColor:GIDiffViewSeparatorLineColor];

  [self setWidth:kSeparatorHairline type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMinYEdge];
  [self setWidth:kSeparatorHairline type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMaxYEdge];
  [self setWidth:2 * kTextLineNumberMargin type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];

  return self;
}

@end

@interface GIUnifiedDiffLineBlock: GIUnifiedDiffBlock

@property (nonatomic, readonly) GCLineDiffChange change;
@property (nonatomic, readonly) NSUInteger oldLineNumber;
@property (nonatomic, readonly) NSUInteger newLineNumber;

- (instancetype)initWithChange:(GCLineDiffChange)change oldLineNumber:(NSUInteger)oldLineNumber newLineNumber:(NSUInteger)newLineNumber;

@end

@implementation GIUnifiedDiffLineBlock

- (instancetype)initWithChange:(GCLineDiffChange)change oldLineNumber:(NSUInteger)oldLineNumber newLineNumber:(NSUInteger)newLineNumber {
  self = [super init];
  if (!self) { return nil; }

  _change = change;
  _oldLineNumber = oldLineNumber;
  _newLineNumber = newLineNumber;

  [self setWidth:2 * kTextLineNumberMargin + kTextInsetLeft type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];

  switch (change) {
    case kGCLineDiffChange_Unmodified:
      self.backgroundColor = nil;
      break;
    case kGCLineDiffChange_Added:
      self.backgroundColor = GIDiffViewAddedBackgroundColor;
      break;
    case kGCLineDiffChange_Deleted:
      self.backgroundColor = GIDiffViewDeletedBackgroundColor;
      break;
  }

  return self;
}

- (void)drawBackgroundWithFrame:(NSRect)frameRect inView:(NSView *)controlView characterRange:(NSRange)charRange layoutManager:(NSLayoutManager *)layoutManager {
  [super drawBackgroundWithFrame:frameRect inView:controlView characterRange:charRange layoutManager:layoutManager];

  [NSGraphicsContext.currentContext saveGraphicsState];
  NSGraphicsContext.currentContext.shouldAntialias = YES;

  if (self.oldLineNumber != NSNotFound) {
    NSString *oldLineNumberText = (self.oldLineNumber >= 100000 ? @"9999…" : [NSString stringWithFormat:@"%5lu", self.oldLineNumber]);
    [oldLineNumberText drawAtPoint:CGPointMake(CGRectGetMinX(frameRect) + 5, CGRectGetMinY(frameRect)) withAttributes:GIDiffViewGutterAttributes];

    if (self.change == kGCLineDiffChange_Deleted) {
      [GIDiffViewDeletedLineIndicator drawAtPoint:CGPointMake(CGRectGetMinX(frameRect) + 2 * kTextLineNumberMargin + 4, CGRectGetMinY(frameRect)) withAttributes:GIDiffViewGutterAttributes];
    }
  } else if (self.newLineNumber != NSNotFound) {
    NSString *newLineNumberText = (self.newLineNumber >= 100000 ? @"9999…" : [NSString stringWithFormat:@"%5lu", self.newLineNumber]);
    [newLineNumberText drawAtPoint:CGPointMake(CGRectGetMinX(frameRect) + kTextLineNumberMargin + 5, CGRectGetMinY(frameRect)) withAttributes:GIDiffViewGutterAttributes];

    if (self.change == kGCLineDiffChange_Added) {
      [GIDiffViewAddedLineIndicator drawAtPoint:CGPointMake(CGRectGetMinX(frameRect) + 2 * kTextLineNumberMargin + 4, CGRectGetMinY(frameRect)) withAttributes:GIDiffViewGutterAttributes];
    }
  }

  [NSGraphicsContext.currentContext restoreGraphicsState];

  [GIDiffViewVerticalLineColor setStroke];

  NSBezierPath *middleLine = [NSBezierPath bezierPath];
  [middleLine moveToPoint:CGPointMake(CGRectGetMinX(frameRect) + kTextLineNumberMargin - kSeparatorHairline, CGRectGetMinY(frameRect))];
  [middleLine lineToPoint:CGPointMake(CGRectGetMinX(frameRect) + kTextLineNumberMargin - kSeparatorHairline, CGRectGetMaxY(frameRect))];
  [middleLine stroke];

  NSBezierPath *rightLine = [NSBezierPath bezierPath];
  [rightLine moveToPoint:CGPointMake(CGRectGetMinX(frameRect) + 2 * kTextLineNumberMargin - kSeparatorHairline, CGRectGetMinY(frameRect))];
  [rightLine lineToPoint:CGPointMake(CGRectGetMinX(frameRect) + 2 * kTextLineNumberMargin - kSeparatorHairline, CGRectGetMaxY(frameRect))];
  [rightLine stroke];
}

@end

@interface GIUnifiedDiffView () <NSTextViewDelegate>
@property (nonatomic) GITextView *textView;
@end

@implementation GIUnifiedDiffView

- (void)didFinishInitializing {
  [super didFinishInitializing];

  GITextView *textView = [[GITextView alloc] init];
  textView.autoresizingMask = NSViewWidthSizable;
  textView.editable = NO;
  textView.delegate = self;
  textView.textContainerInset = CGSizeZero;
  textView.textContainer.lineFragmentPadding = 0;
  [self addSubview:textView];
  self.textView = textView;
}

- (BOOL)isEmpty {
  return self.textView.textStorage.length == 0;
}

- (void)didUpdatePatch {
  [super didUpdatePatch];

  [self.textView.textStorage beginEditing];
  if (self.patch) {
    NSMutableArray<NSValue *> *deletedLines = [NSMutableArray array];

    void(^commitHighlightWithInsertedLine)(NSRange) = ^(NSRange insertedLine){
      if (insertedLine.location == NSNotFound || deletedLines.count == 0) {
        [deletedLines removeAllObjects];
        return;
      }

      NSRange deletedLine = [deletedLines[0] rangeValue];
      [deletedLines removeObjectAtIndex:0];

      NSString *beforeString = [self.textView.textStorage.string substringWithRange:deletedLine];
      NSString *afterString = [self.textView.textStorage.string substringWithRange:insertedLine];
      NSRange beforeRange, afterRange;
      GIComputeModifiedRanges(beforeString, &beforeRange, afterString, &afterRange);

      [self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:GIDiffViewDeletedHighlightColor range:NSMakeRange(deletedLine.location + beforeRange.location, beforeRange.length)];
      [self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:GIDiffViewAddedHighlightColor range:NSMakeRange(insertedLine.location + afterRange.location, afterRange.length)];
    };

    [self.patch enumerateUsingBeginHunkHandler:^(NSUInteger oldLineNumber, NSUInteger oldLineCount, NSUInteger newLineNumber, NSUInteger newLineCount) {
      NSString *string = [NSString stringWithFormat:@"@@ -%lu,%lu +%lu,%lu @@\n", oldLineNumber, oldLineCount, newLineNumber, newLineCount];

      NSMutableDictionary *attributes = [GIDiffViewLineAttributes mutableCopy];
      NSMutableParagraphStyle *paragraphStyle = [attributes[NSParagraphStyleAttributeName] mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
      paragraphStyle.textBlocks = @[ [[GIUnifiedDiffSeparatorBlock alloc] init] ];
      attributes[NSParagraphStyleAttributeName] = paragraphStyle;
      attributes[NSForegroundColorAttributeName] = GIDiffViewSeparatorTextColor;

      [self.textView.textStorage appendString:string withAttributes:attributes];
    } lineHandler:^(GCLineDiffChange change, NSUInteger oldLineNumber, NSUInteger newLineNumber, const char* contentBytes, NSUInteger contentLength) {
      NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)contentBytes length:contentLength encoding:NSUTF8StringEncoding freeWhenDone:NO];
      if ([string characterAtIndex:string.length - 1] != '\n') {
        string = [string stringByAppendingString:GIDiffViewMissingNewlinePlaceholder];
      } else if (!string) {
        string = @"<LINE IS NOT VALID UTF-8>\n";
        GC_DEBUG_UNREACHABLE();
      }

      NSMutableDictionary *attributes = [GIDiffViewLineAttributes mutableCopy];
      NSMutableParagraphStyle *pStyle = [attributes[NSParagraphStyleAttributeName] mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
      pStyle.textBlocks = @[ [[GIUnifiedDiffLineBlock alloc] initWithChange:change oldLineNumber:oldLineNumber newLineNumber:newLineNumber] ];
      attributes[NSParagraphStyleAttributeName] = pStyle;

      [self.textView.textStorage appendString:string withAttributes:attributes];

      switch (change) {
        case kGCLineDiffChange_Unmodified:
          commitHighlightWithInsertedLine(NSMakeRange(NSNotFound, 0));
          break;
        case kGCLineDiffChange_Added:
          commitHighlightWithInsertedLine(NSMakeRange(self.textView.textStorage.length - string.length, string.length));
          break;
        case kGCLineDiffChange_Deleted:
          [deletedLines addObject:[NSValue valueWithRange:NSMakeRange(self.textView.textStorage.length - string.length, string.length)]];
          break;
      }
    } endHunkHandler:^{
      commitHighlightWithInsertedLine(NSMakeRange(NSNotFound, 0));
    }];
  } else {
    [self.textView.textStorage deleteAllCharacters];
  }
  [self.textView.textStorage endEditing];
}

- (CGFloat)updateLayoutForWidth:(CGFloat)width {
  [self setFrameSize:NSMakeSize(width, self.frame.size.height)];
  [self.textView sizeToFit];
  [self.textView setFrameOrigin:NSZeroPoint];
  return self.textView.frame.size.height;
}

- (BOOL)hasSelection {
  for (NSValue *value in self.textView.selectedRanges) {
    NSRange selectedRange = value.rangeValue;
    if (selectedRange.length != 0) {
      return YES;
    }
  }
  return NO;
}

- (void)clearSelection {
  [self.textView setSelectedRange:NSMakeRange(0, 0)];
}

- (void)getSelectedText:(NSString**)text oldLines:(NSIndexSet**)oldLines newLines:(NSIndexSet**)newLines {
  if (text) {
    *text = [[NSMutableString alloc] init];
    for (NSValue *value in self.textView.selectedRanges) {
      NSRange selectedRange = value.rangeValue;
      NSString *substring = [self.textView.textStorage.string substringWithRange:selectedRange];
      [(NSMutableString*)*text appendString:substring];
    }
  }

  if (oldLines) {
    *oldLines = [NSMutableIndexSet indexSet];
  }

  if (newLines) {
    *newLines = [NSMutableIndexSet indexSet];
  }

  if (oldLines || newLines) {
    for (NSValue *value in self.textView.selectedRanges) {
      NSRange selectedRange = value.rangeValue;
      [self.textView.textStorage enumerateAttribute:NSParagraphStyleAttributeName inRange:selectedRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSParagraphStyle *paragraphStyle, NSRange range, BOOL *stop) {
        for (NSTextBlock *textBlock in paragraphStyle.textBlocks) {
          if (![textBlock isKindOfClass:GIUnifiedDiffLineBlock.class]) { continue; }
          GIUnifiedDiffLineBlock *lineBlock = (GIUnifiedDiffLineBlock *)textBlock;
          if (oldLines && lineBlock.oldLineNumber != NSNotFound) {
            [(NSMutableIndexSet*)*oldLines addIndex:lineBlock.oldLineNumber];
          }
          if (newLines && lineBlock.newLineNumber != NSNotFound) {
            [(NSMutableIndexSet*)*newLines addIndex:lineBlock.newLineNumber];
          }
        }
      }];
    }
  }
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
  [self.delegate diffViewDidChangeSelection:self];
}

- (BOOL)textView:(NSTextView*)textView doCommandBySelector:(SEL)selector {
  if (selector == @selector(insertNewline:)) {
    return [self.window.firstResponder.nextResponder tryToPerform:@selector(keyDown:) with:self.window.currentEvent];
  }
  return NO;
}

@end
