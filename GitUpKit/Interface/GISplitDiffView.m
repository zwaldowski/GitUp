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

#define kTextLineNumberMargin (5 * 8)
#define kTextInsetLeft 5
#define kTextInsetRight 5
#define kTextBottomPadding 0
#define kSeparatorHairline 0.5

typedef NS_ENUM(NSUInteger, DiffLineType) {
  kDiffLineType_Separator = 0,
  kDiffLineType_Context,
  kDiffLineType_Change
};

typedef NS_ENUM(NSUInteger, SelectionMode) {
  kSelectionMode_None = 0,
  kSelectionMode_Replace,
  kSelectionMode_Extend,
  kSelectionMode_Inverse
};

@interface GISplitDiffView () <NSUserInterfaceValidations, NSSplitViewDelegate, NSTextViewDelegate, NSLayoutManagerDelegate>
@property (nonatomic) NSSplitView *splitView;
@property (nonatomic) GITextView *leftTextView;
@property (nonatomic) GITextView *rightTextView;
@end

@interface GISplitDiffBlock: NSTextBlock <NSCopying>

@property (nonatomic, readonly) GCLineDiffChange change;
@property (nonatomic) NSRange companionRange;

@end

@implementation GISplitDiffBlock

- (GCLineDiffChange)change {
  return kGCLineDiffChange_Unmodified;
}

- (instancetype)init {
  self = [super init];
  if (!self) { return nil; }

  _companionRange = NSMakeRange(NSNotFound, 0);

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

- (id)copyWithZone:(NSZone *)zone {
  GISplitDiffBlock *other = [[self.class alloc] init];
  other.companionRange = self.companionRange;
  return other;
}

- (void)unionCompanionRange:(NSRange)companionRange {
  self.companionRange = self.companionRange.location == NSNotFound ? companionRange : NSUnionRange(self.companionRange, companionRange);
}

@end


@interface GISplitDiffSeparatorBlock: GISplitDiffBlock
@end

@implementation GISplitDiffSeparatorBlock

- (instancetype)init {
  self = [super init];
  if (!self) { return nil; }

  [self setContentWidth:100 type:NSTextBlockPercentageValueType];

  self.backgroundColor = GIDiffViewSeparatorBackgroundColor;
  [self setBorderColor:GIDiffViewSeparatorLineColor];

  [self setWidth:kSeparatorHairline type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMinYEdge];
  [self setWidth:kSeparatorHairline type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMaxYEdge];
  [self setWidth:kTextLineNumberMargin type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];

  return self;
}

@end

@interface GISplitDiffLineBlock: GISplitDiffBlock

@property (nonatomic, readonly) GCLineDiffChange change;
@property (nonatomic, readonly) NSUInteger lineNumber;

- (instancetype)initWithChange:(GCLineDiffChange)change lineNumber:(NSUInteger)lineNumber;
- (instancetype)initWithChange:(GCLineDiffChange)change lineNumber:(NSUInteger)lineNumber companionRange:(NSRange)companionRange;

@end

@implementation GISplitDiffLineBlock

@synthesize change = _change;

- (instancetype)initWithChange:(GCLineDiffChange)change lineNumber:(NSUInteger)lineNumber {
  return (self = [self initWithChange:change lineNumber:lineNumber companionRange:NSMakeRange(NSNotFound, 0)]);
}

- (instancetype)initWithChange:(GCLineDiffChange)change lineNumber:(NSUInteger)lineNumber companionRange:(NSRange)companionRange {
  self = [super init];
  if (!self) { return nil; }

  _change = change;
  _lineNumber = lineNumber;

  [self setWidth:kTextLineNumberMargin + kTextInsetLeft type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];

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

  if (self.lineNumber != NSNotFound) {
    NSString *oldLineNumberText = (self.lineNumber >= 100000 ? @"9999…" : [NSString stringWithFormat:@"%5lu", self.lineNumber]);
    [oldLineNumberText drawAtPoint:CGPointMake(CGRectGetMinX(frameRect) + 5, CGRectGetMinY(frameRect)) withAttributes:GIDiffViewGutterAttributes];
  }

  [NSGraphicsContext.currentContext restoreGraphicsState];

  [GIDiffViewVerticalLineColor setStroke];

  NSBezierPath *rightLine = [NSBezierPath bezierPath];
  [rightLine moveToPoint:CGPointMake(CGRectGetMinX(frameRect) + kTextLineNumberMargin - kSeparatorHairline, CGRectGetMinY(frameRect))];
  [rightLine lineToPoint:CGPointMake(CGRectGetMinX(frameRect) + kTextLineNumberMargin - kSeparatorHairline, CGRectGetMaxY(frameRect))];
  [rightLine stroke];
}

- (GISplitDiffLineBlock *)withCompanionRange:(NSRange)companionRange {
  return [[GISplitDiffLineBlock alloc] initWithChange:self.change lineNumber:self.lineNumber companionRange:companionRange];
}

//- (GISplitDiffLineBlock *)unionCompanionRange:(NSRange)companionRange {
//  NSRange newCompanionRange = self.companionRange.location == NSNotFound ? companionRange : NSUnionRange(self.companionRange, companionRange);
//  return [[GISplitDiffLineBlock alloc] initWithChange:self.change lineNumber:self.lineNumber companionRange:newCompanionRange];
//}

//- (id)copyWithZone:(NSZone *)zone {
//  GISplitDiffView *other = [super copyWithZone:zone];
//}

- (id)copyWithZone:(NSZone *)zone {
  return [[GISplitDiffLineBlock alloc] initWithChange:self.change lineNumber:self.lineNumber companionRange:self.companionRange];
}

@end

@implementation NSMutableAttributedString (GISplitDiffView)

- (void)updateSplitDiffBlockInRange:(NSRange)range usingBlock:(void(^)(GISplitDiffBlock *))block {
  NSRange searchRange = range.length != 0 ? range : NSMakeRange(0, self.length);
  NSUInteger index = range.length != 0 ? range.location : (self.length != 0 ? self.length - 1 : 0);
  NSRange effectiveRange;
//  NSLog(@"%lu %@", index, NSStringFromRange(searchRange));
  NSMutableParagraphStyle *paragraphStyle = [[self attribute:NSParagraphStyleAttributeName atIndex:index longestEffectiveRange:&effectiveRange inRange:searchRange] mutableCopy];
  NSMutableArray *textBlocks = [paragraphStyle.textBlocks mutableCopy];
  NSUInteger blockIndex = [textBlocks indexOfObjectPassingTest:^(NSTextBlock *obj, NSUInteger idx, BOOL *stop) {
    return [obj isKindOfClass:GISplitDiffBlock.class];
  }];
  if (blockIndex == NSNotFound) { return; }
  GISplitDiffBlock *textBlock = [textBlocks[blockIndex] copy];
  block(textBlock);
  textBlocks[blockIndex] = textBlock;
  paragraphStyle.textBlocks = textBlocks;
  [self addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:effectiveRange];
}

@end

@interface GISplitDiffLine : NSObject
@property(nonatomic, readonly) DiffLineType type;

@property(nonatomic) NSUInteger leftNumber;
@property(nonatomic, strong) NSString* leftString;
@property(nonatomic) CTLineRef leftLine;
@property(nonatomic) BOOL leftWrapped;
@property(nonatomic) CFRange leftHighlighted;

@property(nonatomic) const char* leftContentBytes;  // Not valid outside of patch generation
@property(nonatomic) NSUInteger leftContentLength;  // Not valid outside of patch generation

@property(nonatomic) NSUInteger rightNumber;
@property(nonatomic, strong) NSString* rightString;
@property(nonatomic) CTLineRef rightLine;
@property(nonatomic) BOOL rightWrapped;
@property(nonatomic) CFRange rightHighlighted;

@property(nonatomic) const char* rightContentBytes;  // Not valid outside of patch generation
@property(nonatomic) NSUInteger rightContentLength;  // Not valid outside of patch generation
@end

@implementation GISplitDiffLine

- (id)initWithType:(DiffLineType)type {
  if ((self = [super init])) {
    _type = type;
  }
  return self;
}

- (void)dealloc {
  if (_leftLine) {
    CFRelease(_leftLine);
  }
  if (_rightLine) {
    CFRelease(_rightLine);
  }
}

- (NSString*)description {
  switch (_type) {
    case kDiffLineType_Separator:
      return _leftString;
    case kDiffLineType_Context:
      return [NSString stringWithFormat:@"[%lu] '%@' | [%lu] '%@'", _leftNumber, _leftString, _rightNumber, _rightString];
    case kDiffLineType_Change:
      return [NSString stringWithFormat:@"[%lu] '%@' | [%lu] '%@'", _leftNumber, _leftString, _rightNumber, _rightString];
  }
  return nil;
}

@end

typedef struct {
  NSRange range;
  BOOL isRight;
  NSRect rect;
} ProvisionalLineFragmentRect;

@implementation GISplitDiffView {
  NSMutableArray* _lines;
  NSSize _size;

  BOOL _rightSelection;
  NSMutableIndexSet* _selectedLines;
  NSRange _selectedText;
  NSUInteger _selectedTextStart;
  NSUInteger _selectedTextEnd;
  SelectionMode _selectionMode;
  NSIndexSet* _startLines;
  NSUInteger _startIndex;
  NSUInteger _startOffset;

  NSUInteger _provisionalLineGlyphIndex;
  NSUInteger _provisionalLineCharacterIndex;
  CGRect _provisionalLineFragmentRect;
  BOOL _provisionalLineFragmentIsRight;

  NSMutableDictionary<NSValue *, NSNumber *> *_calculatedLineFragmentRects;
}

- (void)didFinishInitializing {
  [super didFinishInitializing];

  _lines = [[NSMutableArray alloc] initWithCapacity:1024];
  _selectedLines = [[NSMutableIndexSet alloc] init];
  _calculatedLineFragmentRects = [NSMutableDictionary new];
  _provisionalLineCharacterIndex = NSNotFound;
  _provisionalLineGlyphIndex = NSNotFound;

  NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:self.bounds];
  splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  splitView.vertical = YES;
  splitView.dividerStyle = NSSplitViewDividerStyleThin;
  splitView.delegate = self;
  [self addSubview:splitView];
  self.splitView = splitView;

  GITextView *leftTextView = [[GITextView alloc] init];
  leftTextView.editable = NO;
  leftTextView.delegate = self;
  leftTextView.textContainerInset = CGSizeZero;
//  leftTextView.layoutManager.allowsNonContig uousLayout = YES;
  leftTextView.layoutManager.delegate = self;
  leftTextView.textContainer.lineFragmentPadding = 0;
  [splitView addSubview:leftTextView];
  self.leftTextView = leftTextView;

  GITextView *rightTextView = [[GITextView alloc] init];
  rightTextView.editable = NO;
  rightTextView.delegate = self;
  rightTextView.textContainerInset = CGSizeZero;
//  rightTextView.layoutManager.allowsNonContiguousLayout = YES;
  rightTextView.layoutManager.delegate = self;
  rightTextView.textContainer.lineFragmentPadding = 0;
  //[rightTextView.layoutManager replaceTextStorage:leftTextView.textStorage];
  [splitView addSubview:rightTextView];
  self.rightTextView = rightTextView;
}

- (void)layoutManager:(NSLayoutManager *)layoutManager textContainer:(NSTextContainer *)textContainer didChangeGeometryFromSize:(NSSize)oldSize {
  NSLog(@"!!!!, %@ %@", NSStringFromSize(oldSize), NSStringFromSize(textContainer.size));
}

- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager paragraphSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(NSRect)rect {
  NSUInteger characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  NSParagraphStyle *paragraphStyle = [layoutManager.textStorage attribute:NSParagraphStyleAttributeName atIndex:characterIndex effectiveRange:NULL];

  GISplitDiffBlock *line;
  for (NSTextBlock *block in paragraphStyle.textBlocks) {
    if (![block isKindOfClass:GISplitDiffBlock.class]) { continue; }
    line = (GISplitDiffBlock *)block;
    break;
  }

  if (!line || line.companionRange.location == NSNotFound) { return 0; }
  BOOL isLeft = (layoutManager == self.leftTextView.layoutManager);
  NSTextView *companion = isLeft ? self.rightTextView : self.leftTextView;


  NSRange glyphRange = [companion.layoutManager glyphRangeForCharacterRange:line.companionRange actualCharacterRange:NULL];
  CGRect companionLineFragmentRect = [companion.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:companion.textContainer];

  CGFloat bottomMargin = 0;
  if (line.change == kGCLineDiffChange_Unmodified) {
    bottomMargin = CGRectGetHeight(companionLineFragmentRect) + 1;
  } else {
    bottomMargin = CGRectGetHeight(companionLineFragmentRect) - CGRectGetHeight(rect) - 2;
  }

  NSLog(@"!!! %@ %f", NSStringFromRect(rect), bottomMargin);
  return bottomMargin;


  /*- (NSRect)boundsRectForContentRect:(NSRect)contentRect inRect:(NSRect)rect textContainer:(NSTextContainer *)textContainer characterRange:(NSRange)charRange {
    NSRect bounds = [super boundsRectForContentRect:contentRect inRect:rect textContainer:textContainer characterRange:charRange];

    if (self.companionRange.location != NSNotFound && [textContainer.textView.delegate isKindOfClass:GISplitDiffView.class]) {
      GISplitDiffView *parent = (GISplitDiffView *)textContainer.textView.delegate;
      BOOL isLeft = (textContainer == parent.leftTextView.textContainer);
      NSTextView *companion = isLeft ? parent.rightTextView : parent.leftTextView;

      NSRange glyphRange = [companion.layoutManager glyphRangeForCharacterRange:self.companionRange actualCharacterRange:NULL];
      CGRect companionLineFragmentRect = [companion.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:companion.textContainer];

      CGFloat bottomMargin = 0;
      if (self.change == kGCLineDiffChange_Unmodified) {
        bottomMargin = CGRectGetHeight(companionLineFragmentRect);
      } else {
        bottomMargin = CGRectGetHeight(companionLineFragmentRect) - CGRectGetHeight(bounds);
      }

      bounds.size.height += bottomMargin;
    }

    return bounds;
  }*/


  /*NSUInteger characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];

  NSRange testEffectiveRange;

  NSParagraphStyle *paragraphStyle = [layoutManager.textStorage attribute:NSParagraphStyleAttributeName atIndex:characterIndex effectiveRange:&testEffectiveRange];
  GISplitDiffLineBlock *line;
  for (NSTextBlock *block in paragraphStyle.textBlocks) {
    if (![block isKindOfClass:GISplitDiffLineBlock.class]) { continue; }
    line = (GISplitDiffLineBlock *)block;
    break;
  }
  if (!line || line.companionRange.location == NSNotFound) { return 0; }

  BOOL isLeft = (layoutManager == self.leftTextView.layoutManager);

  if (!isLeft) { return 0; }

  NSLog(@"!!! %@", [self.leftTextView.textStorage.string substringWithRange:testEffectiveRange]);

  CGRect companionLineFragmentRect;

  if (_provisionalLineCharacterIndex == NSMaxRange(line.companionRange) - 1 && ((isLeft && _provisionalLineFragmentIsRight) || (!isLeft && !_provisionalLineFragmentIsRight))) {
    companionLineFragmentRect = _provisionalLineFragmentRect;
  } else {
    _provisionalLineFragmentRect = rect;
    _provisionalLineFragmentIsRight = !isLeft;
    _provisionalLineCharacterIndex = characterIndex;

    //- (NSRect)boundingRectForGlyphRange:(NSRange)glyphRange inTextContainer:(NSTextContainer *)container;
//    [compani]

    NSTextView *companion = isLeft ? self.rightTextView : self.leftTextView;
    NSRange glyphRange = [companion.layoutManager glyphRangeForCharacterRange:line.companionRange actualCharacterRange:NULL];
    companionLineFragmentRect = [companion.layoutManager boundingRectForGlyphRange:NSMakeRange(glyphRange.location, glyphRange.length - 1) inTextContainer:companion.textContainer];
  }

  CGFloat diff = fmax(CGRectGetMaxY(companionLineFragmentRect) - 2 - CGRectGetMaxY(rect), 0);

  NSLog(@"!!! %@ %f %f -> %f", isLeft ? @"ltr" : @"rtl" , CGRectGetHeight(rect), CGRectGetHeight(companionLineFragmentRect), diff);

  return diff;*/
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
  return NO;
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex {
  return NSZeroRect;
}

- (void)dealloc {
//  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
//  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
}

/*- (void)_windowKeyDidChange:(NSNotification*)notification {
  if ([self hasSelection]) {
    [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed
  }
}*/

/*- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];

  if (self.window) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowKeyDidChange:) name:NSWindowDidBecomeKeyNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowKeyDidChange:) name:NSWindowDidResignKeyNotification object:self.window];
  } else {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
  }
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (BOOL)becomeFirstResponder {
  if (self.hasSelection) {
    [self setNeedsDisplay:YES];
  }
  return YES;
}

- (BOOL)resignFirstResponder {
  if (self.hasSelection) {
    [self setNeedsDisplay:YES];
  }
  return YES;
}*/

- (BOOL)isEmpty {
  return (_lines.count == 0);
}

- (void)didUpdatePatch {
  [super didUpdatePatch];

  [_calculatedLineFragmentRects removeAllObjects];

//  [_lines removeAllObjects];

//  [self setNeedsDisplay:YES];

  [self.leftTextView.textStorage beginEditing];
  [self.rightTextView.textStorage beginEditing];
  if (self.patch) {
    NSMutableArray<NSValue *> *deletedLines = [NSMutableArray array];
    NSMutableArray<NSValue *> *insertedLines = [NSMutableArray array];

    void(^finishPendingPair)(void) = ^{
      /*for (NSUInteger i = 0; i < deletedLines.count || i < insertedLines.count; i++) {
        NSValue *deletedLineValue = (i < deletedLines.count) ? deletedLines[i] : deletedLines.lastObject;
        NSRange deletedLine = deletedLineValue != nil ? deletedLineValue.rangeValue : NSMakeRange(NSNotFound, 0);

        NSValue *insertedLineValue = (i < insertedLines.count) ? insertedLines[i] : insertedLines.lastObject;
        NSRange insertedLine = insertedLineValue != nil ? insertedLineValue.rangeValue : NSMakeRange(NSNotFound, 0);

        [self.leftTextView.textStorage updateSplitDiffBlockInRange:deletedLine usingBlock:^(GISplitDiffBlock *block){
          block.companionRange = insertedLine;
        }];

        [self.rightTextView.textStorage updateSplitDiffBlockInRange:insertedLine usingBlock:^(GISplitDiffBlock *block){
          block.companionRange = deletedLine;
        }];
      }*/

      if (insertedLines.count < deletedLines.count) {
        NSRange insertedLine = insertedLines.lastObject.rangeValue;

        NSRange deletedLinesUnion;
        for (NSUInteger i = 0; i < deletedLines.count; i++) {
          NSRange deletedLine = deletedLines[i].rangeValue;
          deletedLinesUnion = i == 0 ? deletedLine : NSUnionRange(deletedLinesUnion, deletedLine);
        }

        [self.rightTextView.textStorage updateSplitDiffBlockInRange:insertedLine usingBlock:^(GISplitDiffBlock *block){
          block.companionRange = deletedLinesUnion;
        }];
      } else if (insertedLines.count != 0) {
        NSRange deletedLine = deletedLines.lastObject.rangeValue;

        NSRange insertedLinesUnion;
        for (NSUInteger i = 0; i < insertedLines.count; i++) {
          NSRange insertedLine = insertedLines[i].rangeValue;
          insertedLinesUnion = i == 0 ? insertedLine : NSUnionRange(insertedLinesUnion, insertedLine);
        }

        [self.leftTextView.textStorage updateSplitDiffBlockInRange:deletedLine usingBlock:^(GISplitDiffBlock *block){
          block.companionRange = insertedLinesUnion;
        }];
      }

      [deletedLines removeAllObjects];
      [insertedLines removeAllObjects];


      /*if (insertedLine.location == NSNotFound || deletedLines.count == 0) {
        [deletedLines removeAllObjects];
        insertedLine = NSMakeRange(NSNotFound, 0);
        return;
      }

      NSRange companionRange = NSMakeRange(NSNotFound, 0);
      for (NSValue *value in deletedLines) {
        NSRange range = value.rangeValue;
        companionRange = companionRange.location == NSNotFound ? range : NSUnionRange(companionRange, range);
      }
      [deletedLines removeAllObjects];
*/
//      NSMutableParagraphStyle *paragraphStyle = [[self.rightTextView.textStorage attribute:NSParagraphStyleAttributeName atIndex:insertedLine.location longestEffectiveRange:NULL inRange:insertedLine] mutableCopy];
//      NSMutableArray *textBlocks = [paragraphStyle.textBlocks mutableCopy];
//      NSUInteger blockIndex = [textBlocks indexOfObjectPassingTest:^(NSTextBlock *obj, NSUInteger idx, BOOL *stop) {
//        return [obj isKindOfClass:GISplitDiffLineBlock.class];
//      }];
//      if (blockIndex == NSNotFound) { return; }
//      textBlocks[blockIndex] = [(GISplitDiffLineBlock *)textBlocks[blockIndex] unionCompanionRange:companionRange];
//      paragraphStyle.textBlocks = textBlocks;
//      [self.rightTextView.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:insertedLine];
    };

    /*void(^commitInsertedLine)(NSRange) = ^(NSRange companionRange){
      insertedLine = companionRange;

      if (deletedLines.count == 0) {
        return;
      }

      NSRange deletedLine = deletedLines[0].rangeValue;
      if (deletedLines.count > 1) {
        [deletedLines removeObjectAtIndex:0];
      }

      NSMutableParagraphStyle *paragraphStyle = [[self.leftTextView.textStorage attribute:NSParagraphStyleAttributeName atIndex:deletedLine.location longestEffectiveRange:NULL inRange:deletedLine] mutableCopy];
      NSMutableArray *textBlocks = [paragraphStyle.textBlocks mutableCopy];
      NSUInteger blockIndex = [textBlocks indexOfObjectPassingTest:^(NSTextBlock *obj, NSUInteger idx, BOOL *stop) {
        return [obj isKindOfClass:GISplitDiffLineBlock.class];
      }];
      if (blockIndex == NSNotFound) { NSLog(@"!"); return; }
      textBlocks[blockIndex] = [(GISplitDiffLineBlock *)textBlocks[blockIndex] unionCompanionRange:companionRange];
      paragraphStyle.textBlocks = textBlocks;
      [self.leftTextView.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:deletedLine];
    };*/

    /*void(^commitHighlightWithInsertedLine)(NSRange) = ^(NSRange insertedLine){
      if (insertedLine.location == NSNotFound || deletedLines.count == 0) {
        [deletedLines removeAllObjects];
        return;
      }

      NSRange deletedLine = [deletedLines[0] rangeValue];
      [deletedLines removeObjectAtIndex:0];

      NSString *beforeString = [self.leftTextView.textStorage.string substringWithRange:deletedLine];
      NSString *afterString = [self.rightTextView.textStorage.string substringWithRange:insertedLine];
      NSRange beforeRange, afterRange;
      GIComputeModifiedRanges(beforeString, &beforeRange, afterString, &afterRange);

      [self.leftTextView.textStorage addAttribute:NSBackgroundColorAttributeName value:GIDiffViewDeletedHighlightColor range:NSMakeRange(deletedLine.location + beforeRange.location, beforeRange.length)];
      [self.rightTextView.textStorage addAttribute:NSBackgroundColorAttributeName value:GIDiffViewAddedHighlightColor range:NSMakeRange(insertedLine.location + afterRange.location, afterRange.length)];
    };*/

    [self.patch enumerateUsingBeginHunkHandler:^(NSUInteger oldLineNumber, NSUInteger oldLineCount, NSUInteger newLineNumber, NSUInteger newLineCount) {
      finishPendingPair();

      NSString *string = [NSString stringWithFormat:@"@@ -%lu,%lu +%lu,%lu @@\n", oldLineNumber, oldLineCount, newLineNumber, newLineCount];

      NSMutableDictionary *attributes = [GIDiffViewLineAttributes mutableCopy];
      NSMutableParagraphStyle *paragraphStyle = [attributes[NSParagraphStyleAttributeName] mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
      paragraphStyle.textBlocks = @[ [[GISplitDiffSeparatorBlock alloc] init] ];
      attributes[NSParagraphStyleAttributeName] = paragraphStyle;
      attributes[NSForegroundColorAttributeName] = GIDiffViewSeparatorTextColor;

      [self.leftTextView.textStorage appendString:string withAttributes:attributes];
      [self.rightTextView.textStorage appendString:@"\n" withAttributes:attributes];
    } lineHandler:^(GCLineDiffChange change, NSUInteger oldLineNumber, NSUInteger newLineNumber, const char* contentBytes, NSUInteger contentLength) {
      NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)contentBytes length:contentLength encoding:NSUTF8StringEncoding freeWhenDone:NO];
      if ([string characterAtIndex:string.length - 1] != '\n') {
        string = [string stringByAppendingString:GIDiffViewMissingNewlinePlaceholder];
      } else if (!string) {
        string = @"<LINE IS NOT VALID UTF-8>\n";
        GC_DEBUG_UNREACHABLE();
      }

      NSMutableDictionary *leftAttributes = [GIDiffViewLineAttributes mutableCopy];
      NSMutableParagraphStyle *leftParagraphStyle = [leftAttributes[NSParagraphStyleAttributeName] mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
      leftParagraphStyle.textBlocks = @[ [[GISplitDiffLineBlock alloc] initWithChange:(change == kGCLineDiffChange_Added ? kGCLineDiffChange_Unmodified : change) lineNumber:oldLineNumber] ];
      leftAttributes[NSParagraphStyleAttributeName] = leftParagraphStyle;

      NSMutableDictionary *rightAttributes = [GIDiffViewLineAttributes mutableCopy];
      NSMutableParagraphStyle *rightParagraphStyle = [rightAttributes[NSParagraphStyleAttributeName] mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
      rightParagraphStyle.textBlocks = @[ [[GISplitDiffLineBlock alloc] initWithChange:(change == kGCLineDiffChange_Deleted ? kGCLineDiffChange_Unmodified : change) lineNumber:newLineNumber] ];
      rightAttributes[NSParagraphStyleAttributeName] = rightParagraphStyle;

      switch (change) {
        case kGCLineDiffChange_Unmodified:
          finishPendingPair();
          [self.leftTextView.textStorage appendString:string withAttributes:leftAttributes];
          [self.rightTextView.textStorage appendString:string withAttributes:rightAttributes];
          break;

        case kGCLineDiffChange_Deleted:
          [self.leftTextView.textStorage appendString:string withAttributes:leftAttributes];
          [deletedLines addObject:[NSValue valueWithRange:NSMakeRange(self.leftTextView.textStorage.length - string.length, string.length)]];
          break;

        case kGCLineDiffChange_Added:
          [self.rightTextView.textStorage appendString:string withAttributes:rightAttributes];
          [insertedLines addObject:[NSValue valueWithRange:NSMakeRange(self.rightTextView.textStorage.length - string.length, string.length)]];
          break;
      }
    } endHunkHandler:^{
      finishPendingPair();
    }];
  } else {
    [self.leftTextView.textStorage deleteAllCharacters];
    [self.rightTextView.textStorage deleteAllCharacters];
  }
  [self.leftTextView.textStorage endEditing];
  [self.rightTextView.textStorage endEditing];
}

- (CGFloat)updateLayoutForWidth:(CGFloat)width {
  [self setFrameSize:NSMakeSize(width, self.frame.size.height)];
  [self.leftTextView sizeToFit];
  [self.rightTextView sizeToFit];
  //[self.rightTextView setFrameOrigin:NSZeroPoint];
  return fmax(self.leftTextView.frame.size.height, self.rightTextView.frame.size.height);
  /*if (self.patch && (NSInteger)width != (NSInteger)_size.width) {
    [_lines removeAllObjects];

    CGFloat lineWidth = floor((width - 2 * kTextLineNumberMargin - 2 * kTextInsetLeft - 2 * kTextInsetRight) / 2);
    __block NSUInteger lineIndex = NSNotFound;
    __block NSUInteger startIndex = NSNotFound;
    __block NSUInteger addedCount = 0;
    __block NSUInteger deletedCount = 0;
    void (^highlightBlock)() = ^() {
      if ((addedCount == deletedCount) && (startIndex != NSNotFound)) {
        NSUInteger deletedIndex = startIndex;
        NSUInteger addedIndex = startIndex;
        while (addedCount) {
          GISplitDiffLine* deletedLine = [_lines objectAtIndex:deletedIndex++];
          while (deletedLine.leftWrapped) {
            deletedLine = [_lines objectAtIndex:deletedIndex++];
          }
          GISplitDiffLine* addedLine = [_lines objectAtIndex:addedIndex++];
          while (addedLine.rightWrapped) {
            addedLine = [_lines objectAtIndex:addedIndex++];
          }
          CFRange deletedRange;
          CFRange addedRange;
          GIComputeHighlightRanges(deletedLine.leftContentBytes, deletedLine.leftContentLength, deletedLine.leftString.length, &deletedRange,
                                   addedLine.rightContentBytes, addedLine.rightContentLength, addedLine.rightString.length, &addedRange);
          while (deletedRange.length > 0) {
            CFRange range = CTLineGetStringRange(deletedLine.leftLine);
            if ((deletedRange.location >= range.location) && (deletedRange.location < range.location + range.length)) {
              if (deletedRange.location + deletedRange.length <= range.location + range.length) {
                deletedLine.leftHighlighted = CFRangeMake(deletedRange.location - range.location, deletedRange.length);
                break;
              }
              deletedLine.leftHighlighted = CFRangeMake(deletedRange.location - range.location, range.location + range.length - deletedRange.location);
              deletedRange = CFRangeMake(range.location + range.length, deletedRange.location + deletedRange.length - range.location - range.length);
            }
            deletedLine = [_lines objectAtIndex:deletedIndex++];
            GC_DEBUG_CHECK(deletedLine.leftWrapped);
          }
          while (addedRange.length > 0) {
            CFRange range = CTLineGetStringRange(addedLine.rightLine);
            if ((addedRange.location >= range.location) && (addedRange.location < range.location + range.length)) {
              if (addedRange.location + addedRange.length <= range.location + range.length) {
                addedLine.rightHighlighted = CFRangeMake(addedRange.location - range.location, addedRange.length);
                break;
              }
              addedLine.rightHighlighted = CFRangeMake(addedRange.location - range.location, range.location + range.length - addedRange.location);
              addedRange = CFRangeMake(range.location + range.length, addedRange.location + addedRange.length - range.location - range.length);
            }
            addedLine = [_lines objectAtIndex:addedIndex++];
            GC_DEBUG_CHECK(addedLine.rightWrapped);
          }
          --addedCount;
        }
      }
    };
    [self.patch enumerateUsingBeginHunkHandler:^(NSUInteger oldLineNumber, NSUInteger oldLineCount, NSUInteger newLineNumber, NSUInteger newLineCount) {
      NSString* string = [[NSString alloc] initWithFormat:@"@@ -%lu,%lu +%lu,%lu @@", oldLineNumber, oldLineCount, newLineNumber, newLineCount];
      CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)string, (CFDictionaryRef)GIDiffViewLineAttributes);
      CTLineRef line = CTLineCreateWithAttributedString(attributedString);
      CFRelease(attributedString);

      GISplitDiffLine* diffLine = [[GISplitDiffLine alloc] initWithType:kDiffLineType_Separator];
      diffLine.leftString = string;
      diffLine.leftLine = line;  // Transfer ownership to GISplitDiffLine
      [_lines addObject:diffLine];

      addedCount = 0;
      deletedCount = 0;
      startIndex = NSNotFound;
    }
        lineHandler:^(GCLineDiffChange change, NSUInteger oldLineNumber, NSUInteger newLineNumber, const char* contentBytes, NSUInteger contentLength) {
          NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)contentBytes length:contentLength encoding:NSUTF8StringEncoding freeWhenDone:NO];
          if ([string characterAtIndex:string.length - 1] != '\n') {
            string = [string stringByAppendingString:GIDiffViewMissingNewlinePlaceholder];
          } else if (!string) {
            string = @"<LINE IS NOT VALID UTF-8>\n";
            GC_DEBUG_UNREACHABLE();
          }

          switch (change) {
            case kGCLineDiffChange_Unmodified:
              highlightBlock();
              addedCount = 0;
              deletedCount = 0;
              startIndex = NSNotFound;
              break;

            case kGCLineDiffChange_Deleted:
              ++deletedCount;
              break;

            case kGCLineDiffChange_Added:
              ++addedCount;
              break;
          }

          CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)string, (CFDictionaryRef)GIDiffViewLineAttributes);
          CTTypesetterRef typeSetter = CTTypesetterCreateWithAttributedString(attributedString);
          CFIndex length = CFAttributedStringGetLength(attributedString);
          CFIndex offset = 0;
          BOOL isWrappedLine = NO;
          do {
            CFIndex index = CTTypesetterSuggestLineBreak(typeSetter, offset, lineWidth);
            CTLineRef line = CTTypesetterCreateLine(typeSetter, CFRangeMake(offset, index));
            switch (change) {  // Assume the order of repeating changes is always [unmodified -> deleted -> added -> unmodified]

              case kGCLineDiffChange_Unmodified: {
                GISplitDiffLine* diffLine = [[GISplitDiffLine alloc] initWithType:kDiffLineType_Context];
                [_lines addObject:diffLine];
                diffLine.leftNumber = oldLineNumber;
                diffLine.leftString = string;
                diffLine.leftLine = line;  // Transfer ownership to GISplitDiffLine
                diffLine.leftWrapped = isWrappedLine;
                diffLine.rightNumber = newLineNumber;
                diffLine.rightString = string;
                diffLine.rightLine = CFRetain(line);  // Transfer ownership to GISplitDiffLine
                diffLine.rightWrapped = isWrappedLine;
                lineIndex = NSNotFound;
                break;
              }

              case kGCLineDiffChange_Deleted: {
                if (lineIndex == NSNotFound) {
                  GC_DEBUG_CHECK(!isWrappedLine);
                  lineIndex = _lines.count;
                }
                GISplitDiffLine* diffLine = [[GISplitDiffLine alloc] initWithType:kDiffLineType_Change];
                [_lines addObject:diffLine];
                diffLine.leftNumber = oldLineNumber;
                diffLine.leftString = string;
                diffLine.leftLine = line;  // Transfer ownership to GISplitDiffLine
                diffLine.leftWrapped = isWrappedLine;
                if (!isWrappedLine) {
                  diffLine.leftContentBytes = contentBytes;
                  diffLine.leftContentLength = contentLength;
                }
                break;
              }

              case kGCLineDiffChange_Added: {
                GISplitDiffLine* diffLine;
                if (lineIndex != NSNotFound) {
                  if (startIndex == NSNotFound) {
                    startIndex = lineIndex;
                  }
                  diffLine = _lines[lineIndex];
                  lineIndex += 1;
                  if (lineIndex == _lines.count) {
                    lineIndex = NSNotFound;
                  }
                } else {
                  diffLine = [[GISplitDiffLine alloc] initWithType:kDiffLineType_Change];
                  [_lines addObject:diffLine];
                }
                diffLine.rightNumber = newLineNumber;
                diffLine.rightString = string;
                diffLine.rightLine = line;  // Transfer ownership to GISplitDiffLine
                diffLine.rightWrapped = isWrappedLine;
                if (!isWrappedLine) {
                  diffLine.rightContentBytes = contentBytes;
                  diffLine.rightContentLength = contentLength;
                }
                break;
              }
            }
            offset += index;
            isWrappedLine = YES;
          } while (offset < length);
          CFRelease(typeSetter);
          CFRelease(attributedString);
        }
        endHunkHandler:^{
          highlightBlock();
        }];
    _size = NSMakeSize(width, _lines.count * GIDiffViewLineHeight + kTextBottomPadding);
  }
  return _size.height;*/
}

/*- (void)drawRect:(NSRect)dirtyRect {
  NSRect bounds = self.bounds;
  CGFloat offset = floor(bounds.size.width / 2);
  CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
  CGContextSaveGState(context);

  [self updateLayoutForWidth:bounds.size.width];

  [self.backgroundColor setFill];
  CGContextFillRect(context, dirtyRect);

  if (_lines.count) {
    NSColor* selectedColor = self.window.keyWindow && (self.window.firstResponder == self) ? [NSColor selectedControlColor] : [NSColor secondarySelectedControlColor];
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    NSUInteger count = _lines.count;
    NSUInteger start = MIN(MAX(count - (dirtyRect.origin.y + dirtyRect.size.height - kTextBottomPadding) / GIDiffViewLineHeight, 0), count);
    NSUInteger end = MIN(MAX(count - (dirtyRect.origin.y - kTextBottomPadding) / GIDiffViewLineHeight + 1, 0), count);
    for (NSUInteger i = start; i < end; ++i) {
      __unsafe_unretained GISplitDiffLine* diffLine = _lines[i];
      CTLineRef leftLine = diffLine.leftLine;
      CTLineRef rightLine = diffLine.rightLine;
      CGFloat linePosition = (count - 1 - i) * GIDiffViewLineHeight + kTextBottomPadding;
      CGFloat textPosition = linePosition + GIDiffViewLineDescent;
      if (diffLine.type == kDiffLineType_Separator) {
        [GIDiffViewSeparatorBackgroundColor setFill];
        CGContextFillRect(context, CGRectMake(0, linePosition + 1, bounds.size.width, GIDiffViewLineHeight - 1));

        [GIDiffViewSeparatorLineColor setStroke];
        CGContextMoveToPoint(context, 0, linePosition + 0.5);
        CGContextAddLineToPoint(context, bounds.size.width, linePosition + 0.5);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, 0, linePosition + GIDiffViewLineHeight - 0.5);
        CGContextAddLineToPoint(context, bounds.size.width, linePosition + GIDiffViewLineHeight - 0.5);
        CGContextStrokePath(context);

        [GIDiffViewSeparatorTextColor setFill];
        CGContextSetTextPosition(context, kTextLineNumberMargin + 4, textPosition);
        CTLineDraw(leftLine, context);
      } else {
        if (leftLine) {
          if (!_rightSelection && [_selectedLines containsIndex:diffLine.leftNumber]) {
            [selectedColor setFill];
            CGContextFillRect(context, CGRectMake(0, linePosition, offset, GIDiffViewLineHeight));
          } else if (diffLine.type != kDiffLineType_Context) {
            [GIDiffViewDeletedBackgroundColor setFill];
            CGContextFillRect(context, CGRectMake(0, linePosition, offset, GIDiffViewLineHeight));

            CFRange highlighted = diffLine.leftHighlighted;
            if (highlighted.length) {
              [GIDiffViewDeletedHighlightColor setFill];
              CFRange range = CTLineGetStringRange(leftLine);
              CGFloat startX = kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(leftLine, range.location + highlighted.location, NULL));
              CGFloat endX = kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(leftLine, range.location + highlighted.location + highlighted.length, NULL));
              CGContextFillRect(context, CGRectMake(startX, linePosition, endX - startX, GIDiffViewLineHeight));
            }
          }
        }
        if (rightLine) {
          if (_rightSelection && [_selectedLines containsIndex:diffLine.rightNumber]) {
            [selectedColor setFill];
            CGContextFillRect(context, CGRectMake(offset, linePosition, bounds.size.width, GIDiffViewLineHeight));
          } else if (diffLine.type != kDiffLineType_Context) {
            [GIDiffViewAddedBackgroundColor setFill];
            CGContextFillRect(context, CGRectMake(offset, linePosition, bounds.size.width, GIDiffViewLineHeight));

            CFRange highlighted = diffLine.rightHighlighted;
            if (highlighted.length) {
              [GIDiffViewAddedHighlightColor setFill];
              CFRange range = CTLineGetStringRange(rightLine);
              CGFloat startX = offset + kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(rightLine, range.location + highlighted.location, NULL));
              CGFloat endX = offset + kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(rightLine, range.location + highlighted.location + highlighted.length, NULL));
              CGContextFillRect(context, CGRectMake(startX, linePosition, endX - startX, GIDiffViewLineHeight));
            }
          }
        }

        if (leftLine) {
          if (!diffLine.leftWrapped) {
            CFAttributedStringRef string = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)(diffLine.leftNumber >= 100000 ? @"9999…" : [NSString stringWithFormat:@"%5lu", diffLine.leftNumber]), (CFDictionaryRef)GIDiffViewGutterAttributes);
            CTLineRef prefix = CTLineCreateWithAttributedString(string);
            CGContextSetTextPosition(context, 5, textPosition);
            CTLineDraw(prefix, context);
            CFRelease(prefix);
            CFRelease(string);
          }

          if (!_rightSelection && _selectedText.length && (i >= _selectedText.location) && (i < _selectedText.location + _selectedText.length)) {
            [selectedColor setFill];
            CGFloat startX = kTextLineNumberMargin + kTextInsetLeft;
            CGFloat endX = offset;
            if (i == _selectedText.location) {
              startX = kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(leftLine, _selectedTextStart, NULL));
            }
            if (i == _selectedText.location + _selectedText.length - 1) {
              endX = kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(leftLine, _selectedTextEnd, NULL));
            }
            CGContextFillRect(context, CGRectMake(startX, linePosition, endX - startX, GIDiffViewLineHeight));
          }

          CGContextSetTextPosition(context, kTextLineNumberMargin + kTextInsetLeft, textPosition);
          CTLineDraw(leftLine, context);
        }
        if (rightLine) {
          if (!diffLine.rightWrapped) {
            CFAttributedStringRef string = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)(diffLine.rightNumber >= 100000 ? @"9999…" : [NSString stringWithFormat:@"%5lu", diffLine.rightNumber]), (CFDictionaryRef)GIDiffViewGutterAttributes);
            CTLineRef prefix = CTLineCreateWithAttributedString(string);
            CGContextSetTextPosition(context, offset + 5, textPosition);
            CTLineDraw(prefix, context);
            CFRelease(prefix);
            CFRelease(string);
          }

          if (_rightSelection && _selectedText.length && (i >= _selectedText.location) && (i < _selectedText.location + _selectedText.length)) {
            [selectedColor setFill];
            CGFloat startX = offset + kTextLineNumberMargin + kTextInsetLeft;
            CGFloat endX = bounds.size.width;
            if (i == _selectedText.location) {
              startX = offset + kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(rightLine, _selectedTextStart, NULL));
            }
            if (i == _selectedText.location + _selectedText.length - 1) {
              endX = offset + kTextLineNumberMargin + kTextInsetLeft + round(CTLineGetOffsetForStringIndex(rightLine, _selectedTextEnd, NULL));
            }
            CGContextFillRect(context, CGRectMake(startX, linePosition, endX - startX, GIDiffViewLineHeight));
          }

          CGContextSetTextPosition(context, offset + kTextLineNumberMargin + kTextInsetLeft, textPosition);
          CTLineDraw(rightLine, context);
        }
      }
    }
  }

  [GIDiffViewVerticalLineColor setStroke];
  CGContextMoveToPoint(context, kTextLineNumberMargin - 0.5, 0);
  CGContextAddLineToPoint(context, kTextLineNumberMargin - 0.5, bounds.size.height);
  CGContextStrokePath(context);
  CGContextMoveToPoint(context, offset - 0.5, 0);
  CGContextAddLineToPoint(context, offset - 0.5, bounds.size.height);
  CGContextStrokePath(context);
  CGContextMoveToPoint(context, offset + kTextLineNumberMargin - 0.5, 0);
  CGContextAddLineToPoint(context, offset + kTextLineNumberMargin - 0.5, bounds.size.height);
  CGContextStrokePath(context);

  CGContextRestoreGState(context);
}

- (void)resetCursorRects {
  NSRect bounds = self.bounds;
  CGFloat offset = floor(bounds.size.width / 2);
  [self addCursorRect:NSMakeRect(kTextLineNumberMargin + kTextInsetLeft, 0, offset - kTextLineNumberMargin - kTextInsetLeft, bounds.size.height)
               cursor:[NSCursor IBeamCursor]];
  [self addCursorRect:NSMakeRect(offset + kTextLineNumberMargin + kTextInsetLeft, 0, bounds.size.width - offset - kTextLineNumberMargin - kTextInsetLeft, bounds.size.height)
               cursor:[NSCursor IBeamCursor]];
}*/

- (BOOL)hasSelection {
  return _selectedLines.count || _selectedText.length;
}

- (void)clearSelection {
  if (_selectedLines.count) {
    [_selectedLines removeAllIndexes];
    _selectedText.length = 0;
    [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed

    [self.delegate diffViewDidChangeSelection:self];
  }
}

- (void)getSelectedText:(NSString**)text oldLines:(NSIndexSet**)oldLines newLines:(NSIndexSet**)newLines {
  if (text) {
    if (_selectedText.length > 0) {
      GC_DEBUG_CHECK(!_selectedLines.count);
      if (_selectedText.length == 1) {
        GISplitDiffLine* diffLine = _lines[_selectedText.location];
        NSString* string = _rightSelection ? diffLine.rightString : diffLine.leftString;
        *text = [string substringWithRange:NSMakeRange(_selectedTextStart, _selectedTextEnd - _selectedTextStart)];
      } else {
        *text = [[NSMutableString alloc] init];
        for (NSUInteger i = _selectedText.location; i < _selectedText.location + _selectedText.length; ++i) {
          GISplitDiffLine* diffLine = _lines[i];
          NSString* string = _rightSelection ? diffLine.rightString : diffLine.leftString;
          if (string) {
            CFRange range = CTLineGetStringRange(_rightSelection ? diffLine.rightLine : diffLine.leftLine);
            if (i == _selectedText.location) {
              [(NSMutableString*)*text appendString:[string substringWithRange:NSMakeRange(_selectedTextStart, range.location + range.length - _selectedTextStart)]];
            } else if (i == _selectedText.location + _selectedText.length - 1) {
              [(NSMutableString*)*text appendString:[string substringWithRange:NSMakeRange(range.location, _selectedTextEnd - range.location)]];
            } else {
              [(NSMutableString*)*text appendString:[string substringWithRange:NSMakeRange(range.location, range.length)]];
            }
          }
        }
      }
    }
    if (_selectedLines.count) {
      GC_DEBUG_CHECK(!_selectedText.length);
      *text = [[NSMutableString alloc] init];
      NSUInteger lastLineNumber = NSNotFound;
      for (GISplitDiffLine* diffLine in _lines) {
        if (_rightSelection) {
          if ([_selectedLines containsIndex:diffLine.rightNumber] && (lastLineNumber != diffLine.rightNumber)) {
            [(NSMutableString*)*text appendString:diffLine.rightString];
            lastLineNumber = diffLine.rightNumber;
          }
        } else {
          if ([_selectedLines containsIndex:diffLine.leftNumber] && (lastLineNumber != diffLine.leftNumber)) {
            [(NSMutableString*)*text appendString:diffLine.leftString];
            lastLineNumber = diffLine.leftNumber;
          }
        }
      }
    }
  }
  if (oldLines) {
    *oldLines = [NSMutableIndexSet indexSet];
  }
  if (newLines) {
    *newLines = [NSMutableIndexSet indexSet];
  }
  if (oldLines || newLines) {
    [_selectedLines enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
      if (_rightSelection) {
        [(NSMutableIndexSet*)*newLines addIndex:index];
      } else {
        [(NSMutableIndexSet*)*oldLines addIndex:index];
      }
    }];
  }
}

/*
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
  if (item.action == @selector(copy:)) {
    return [self hasSelection];
  }

  return NO;
}

- (void)mouseDown:(NSEvent*)event {
  NSRect bounds = self.bounds;
  CGFloat offset = floor(bounds.size.width / 2);
  NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];

  // Reset state
  _selectionMode = kSelectionMode_None;
  _startLines = nil;
  _startIndex = NSNotFound;
  if (!_lines.count) {
    return;
  }

  // Check if mouse is in the content area
  NSInteger y = _lines.count - (location.y - kTextBottomPadding) / GIDiffViewLineHeight;
  if ((y >= 0) && (y < (NSInteger)_lines.count)) {
    GISplitDiffLine* diffLine = _lines[y];

    // Clear selection if changing side
    BOOL rightSelection = (location.x >= offset);
    if (rightSelection != _rightSelection) {
      [_selectedLines removeAllIndexes];
      _selectedText.length = 0;
    }
    _rightSelection = rightSelection;

    // Set selection mode according to modifier flags
    if (event.modifierFlags & NSEventModifierFlagCommand) {
      _selectionMode = kSelectionMode_Inverse;
    } else if ((event.modifierFlags & NSEventModifierFlagShift) && _selectedLines.count) {
      _selectionMode = kSelectionMode_Extend;
    } else {
      _selectionMode = kSelectionMode_Replace;
    }

    // Check if mouse is in the margin area
    if (((location.x >= 0) && (location.x < kTextLineNumberMargin)) || ((location.x >= offset) && (location.x < offset + kTextLineNumberMargin))) {
      // Reset selection
      _selectedText.length = 0;
      if (_selectionMode == kSelectionMode_Replace) {
        [_selectedLines removeAllIndexes];
      }

      // Update selected lines
      NSUInteger index = (_rightSelection ? diffLine.rightNumber : diffLine.leftNumber);
      if (diffLine.type != kDiffLineType_Separator) {  // Ignore separators
        _startIndex = index;
      } else {
        _selectionMode = kSelectionMode_None;
      }
      switch (_selectionMode) {
        case kSelectionMode_None:
          break;

        case kSelectionMode_Replace: {
          GC_DEBUG_CHECK(_selectedLines.count == 0);
          [_selectedLines addIndex:index];
          _startLines = [_selectedLines copy];
          break;
        }

        case kSelectionMode_Extend: {
          GC_DEBUG_CHECK(_selectedLines.count > 0);
          _startLines = [_selectedLines copy];
          if (index > _startLines.lastIndex) {
            [_selectedLines addIndexesInRange:NSMakeRange(_startLines.lastIndex, index - _startLines.lastIndex + 1)];
          } else if (index < _startLines.firstIndex) {
            [_selectedLines addIndexesInRange:NSMakeRange(index, _startLines.firstIndex - index + 1)];
          }
          break;
        }

        case kSelectionMode_Inverse: {
          _startLines = [_selectedLines copy];
          if ([_selectedLines containsIndex:index]) {
            [_selectedLines removeIndex:index];
          } else {
            [_selectedLines addIndex:index];
          }
          break;
        }
      }
      [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed

    }
    // Otherwise check if mouse is is in the diff area
    else if (((location.x >= kTextLineNumberMargin + kTextInsetLeft) && (location.x < offset)) || (location.x >= offset + kTextLineNumberMargin + kTextInsetLeft)) {
      // Reset selection
      _selectedText.length = 0;
      [_selectedLines removeAllIndexes];

      // Update selected text
      CTLineRef line = _rightSelection ? diffLine.rightLine : diffLine.leftLine;
      CFIndex index = CTLineGetStringIndexForPosition(line, CGPointMake(location.x - ((_rightSelection ? offset : 0) + kTextLineNumberMargin + kTextInsetLeft), GIDiffViewLineHeight / 2));
      if (index != kCFNotFound) {
        _startIndex = y;
        _startOffset = index;
        if (event.clickCount > 1) {
          NSString* string = _rightSelection ? diffLine.rightString : diffLine.leftString;
          CFRange range = CTLineGetStringRange(line);
          [string enumerateSubstringsInRange:NSMakeRange(range.location, range.length)
                                     options:NSStringEnumerationByWords
                                  usingBlock:^(NSString* substring, NSRange substringRange, NSRange enclosingRange, BOOL* stop) {
                                    if ((index >= (CFIndex)substringRange.location) && (index <= (CFIndex)(substringRange.location + substringRange.length))) {
                                      _selectedText = NSMakeRange(y, 1);
                                      _selectedTextStart = substringRange.location;
                                      _selectedTextEnd = substringRange.location + substringRange.length;
                                      _startIndex = _selectedText.location;
                                      _startOffset = _selectedTextStart;
                                      *stop = YES;
                                    }
                                  }];
        }
      } else {
        _selectionMode = kSelectionMode_None;
      }
      [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed

    } else {
      _selectionMode = kSelectionMode_None;
    }

  }
  // Otherwise clear entire selection
  else {
    [self clearSelection];
  }
}

- (void)mouseDragged:(NSEvent*)event {
  if (_selectionMode == kSelectionMode_None) {
    return;
  }
  NSRect bounds = self.bounds;
  CGFloat offset = floor(bounds.size.width / 2);
  NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];

  // Check if mouse is in the content area
  NSInteger y = _lines.count - (location.y - kTextBottomPadding) / GIDiffViewLineHeight;
  if ((y >= 0) && (y < (NSInteger)_lines.count)) {
    GISplitDiffLine* diffLine = _lines[y];

    // Check if we are in line-selection mode
    if (_startLines) {
      if (diffLine.type != kDiffLineType_Separator) {  // Ignore separators

        // Update selected lines
        if (_rightSelection ? diffLine.rightLine : diffLine.leftLine) {
          NSUInteger index = (_rightSelection ? diffLine.rightNumber : diffLine.leftNumber);
          switch (_selectionMode) {
            case kSelectionMode_None:
              break;

            case kSelectionMode_Replace:
            case kSelectionMode_Extend: {
              GC_DEBUG_CHECK(_startLines.count > 0);
              [_selectedLines removeAllIndexes];
              [_selectedLines addIndexes:_startLines];
              if (index > _startLines.lastIndex) {
                [_selectedLines addIndexesInRange:NSMakeRange(_startLines.lastIndex, index - _startLines.lastIndex + 1)];
              } else if (index < _startLines.firstIndex) {
                [_selectedLines addIndexesInRange:NSMakeRange(index, _startLines.firstIndex - index + 1)];
              }
              break;
            }

            case kSelectionMode_Inverse: {
              [_selectedLines removeAllIndexes];
              [_selectedLines addIndexes:_startLines];
              for (NSUInteger i = MIN(_startIndex, index); i <= MAX(_startIndex, index); ++i) {
                if (![_selectedLines containsIndex:i]) {
                  [_selectedLines addIndex:i];
                } else {
                  [_selectedLines removeIndex:i];
                }
              }
              break;
            }
          }
          [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed
        }
      }
    }
    // Otherwise we are in text-selection mode
    else {
      CTLineRef line = _rightSelection ? diffLine.rightLine : diffLine.leftLine;
      CFIndex index = CTLineGetStringIndexForPosition(line, CGPointMake(location.x - ((_rightSelection ? offset : 0) + kTextLineNumberMargin + kTextInsetLeft), GIDiffViewLineHeight / 2));
      if (index != kCFNotFound) {
        // Update selected text
        if ((NSUInteger)y > _startIndex) {
          _selectedText = NSMakeRange(_startIndex, y - _startIndex + 1);
          _selectedTextStart = _startOffset;
          _selectedTextEnd = index;
        } else if ((NSUInteger)y < _startIndex) {
          _selectedText = NSMakeRange(y, _startIndex - y + 1);
          _selectedTextStart = index;
          _selectedTextEnd = _startOffset;
        } else {
          _selectedText = NSMakeRange(_startIndex, 1);
          if ((NSUInteger)index > _startOffset) {
            _selectedTextStart = _startOffset;
            _selectedTextEnd = index;
          } else if ((NSUInteger)index < _startOffset) {
            _selectedTextStart = index;
            _selectedTextEnd = _startOffset;
          }
        }
        [self setNeedsDisplay:YES];  // TODO: Only redraw what's needed
      }
    }
  }

  // Scroll if needed
  [self autoscroll:event];
}

- (void)mouseUp:(NSEvent*)event {
  if (_lines.count) {
    [self.delegate diffViewDidChangeSelection:self];  // TODO: Avoid calling delegate if seleciton hasn't actually changed
  }
}

- (void)copy:(id)sender {
  [[NSPasteboard generalPasteboard] declareTypes:@[ NSPasteboardTypeString ] owner:nil];
  NSString* text;
  [self getSelectedText:&text oldLines:NULL newLines:NULL];
  [[NSPasteboard generalPasteboard] setString:text forType:NSPasteboardTypeString];
}*/

@end
