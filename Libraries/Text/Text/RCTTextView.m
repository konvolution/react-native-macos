/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTTextView.h"

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
#import <MobileCoreServices/UTCoreTypes.h>
#else
#import <Quartz/Quartz.h> // TODO(macOS ISS#2323203) for CATiledLayer
#endif // TODO(macOS ISS#2323203)

#import <React/RCTAssert.h> // TODO(macOS ISS#2323203)
#import <React/RCTUtils.h>
#import <React/UIView+React.h>

#import "RCTTextShadowView.h"
#import "RCTTextRenderer.h"

@interface RCTTextTiledLayer : CATiledLayer

@end

@implementation RCTTextTiledLayer

+ (CFTimeInterval)fadeDuration
{
  return 0.05;
}

@end

#import <QuartzCore/QuartzCore.h> // TODO(macOS ISS#2323203)

@implementation RCTTextView
{
#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
  UILongPressGestureRecognizer *_longPressGestureRecognizer;
#endif // TODO(macOS ISS#2323203)

  NSArray<RCTUIView *> *_Nullable _descendantViews; // TODO(macOS ISS#3536887)
  NSTextStorage *_Nullable _textStorage;
  CGRect _contentFrame;
  RCTTextRenderer *_renderer;
  // For small amount of text avoid the overhead of CATiledLayer and
  // make render text synchronously. For large amount of text, use
  // CATiledLayer to chunk text rendering and avoid linear memory
  // usage.
  CALayer *_Nullable _syncLayer;
  RCTTextTiledLayer *_Nullable _asyncTiledLayer;
  CAShapeLayer *_highlightLayer;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
    self.isAccessibilityElement = YES;
    self.accessibilityTraits |= UIAccessibilityTraitStaticText;
#else // [TODO(macOS ISS#2323203)
    self.accessibilityRole = NSAccessibilityStaticTextRole;
#endif // ]TODO(macOS ISS#2323203)
    self.opaque = NO;
    RCTUIViewSetContentModeRedraw(self); // TODO(macOS ISS#2323203) and TODO(macOS ISS#3536887)
    _renderer = [RCTTextRenderer new];
  }
  return self;
}

#if TARGET_OS_OSX // [TODO(macOS ISS#2323203)
- (BOOL)canBecomeKeyView
{
	// RCTText should not get any keyboard focus unless its `selectable` prop is true
	return _selectable;
}

- (BOOL)enableFocusRing
{
  return _selectable;
}

- (void)drawFocusRingMask {
  if ([self enableFocusRing]) {
    NSRectFill([self bounds]);
  }
}

- (NSRect)focusRingMaskBounds {
  return [self bounds];
}
#endif // ]TODO(macOS ISS#2323203)

- (NSString *)description
{
  NSString *superDescription = super.description;
  NSRange semicolonRange = [superDescription rangeOfString:@";"];
  NSString *replacement = [NSString stringWithFormat:@"; reactTag: %@; text: %@", self.reactTag, _textStorage.string];
  return [superDescription stringByReplacingCharactersInRange:semicolonRange withString:replacement];
}

- (void)setSelectable:(BOOL)selectable
{
  if (_selectable == selectable) {
    return;
  }

  _selectable = selectable;

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
  if (_selectable) {
    [self enableContextMenu];
  }
  else {
    [self disableContextMenu];
  }
#endif // TODO(macOS ISS#2323203)
}

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
- (void)reactSetFrame:(CGRect)frame
{
  // Text looks super weird if its frame is animated.
  // This disables the frame animation, without affecting opacity, etc.
  [UIView performWithoutAnimation:^{
    [super reactSetFrame:frame];
    [self configureLayer];
  }];
}
#endif // TODO(macOS ISS#2323203)

- (void)didUpdateReactSubviews
{
  // Do nothing, as subviews are managed by `setTextStorage:` method
}

- (void)setTextStorage:(NSTextStorage *)textStorage
          contentFrame:(CGRect)contentFrame
       descendantViews:(NSArray<RCTUIView *> *)descendantViews // TODO(macOS ISS#3536887)
{
#if TARGET_OS_OSX // [TODO(macOS ISS#2323203)
  // On macOS when a large number of flex layouts are being performed, such
  // as when a window is being resized, AppKit can throw an uncaught exception
  // (-[NSConcretePointerArray pointerAtIndex:]: attempt to access pointer at index ...)
  // during the dealloc of NSLayoutManager.  The _textStorage and its
  // associated NSLayoutManager dealloc later in an autorelease pool.
  // Manually removing the layout manager from _textStorage prior to release
  // works around this issue in AppKit.
  NSArray<NSLayoutManager *> *managers = [_textStorage layoutManagers];
  for (NSLayoutManager *manager in managers) {
    [_textStorage removeLayoutManager:manager];
  }
#endif // ]TODO(macOS ISS#2323203)

  _textStorage = textStorage;
  _contentFrame = contentFrame;

  // FIXME: Optimize this.
  for (RCTUIView *view in _descendantViews) { // TODO(macOS ISS#3536887)
    [view removeFromSuperview];
  }

  _descendantViews = descendantViews;

  for (RCTUIView *view in descendantViews) { // TODO(macOS ISS#3536887)
    [self addSubview:view];
  }

  [_renderer setTextStorage:textStorage contentFrame:contentFrame];
  [self configureLayer];
  [self setCurrentLayerNeedsDisplay];
}

- (void)configureLayer
{
  if (!_textStorage) {
    return;
  }

  CALayer *currentLayer;

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
  CGSize screenSize = RCTScreenSize();
#else
  CGSize screenSize = [[NSScreen mainScreen] frame].size;
#endif // TODO(macOS ISS#2323203)
  CGFloat textViewTileSize =  MAX(screenSize.width, screenSize.height) * 1.5;

  if (self.frame.size.width > textViewTileSize || self.frame.size.height > textViewTileSize) {
    // Cleanup sync layer
    if (_syncLayer != nil) {
      _syncLayer.delegate = nil;
      [_syncLayer removeFromSuperlayer];
      _syncLayer = nil;
    }

    if (_asyncTiledLayer == nil) {
      RCTTextTiledLayer *layer = [RCTTextTiledLayer layer];
      layer.delegate = _renderer;
#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
      layer.contentsScale = RCTScreenScaleRCTScreenScale();
#else
      layer.contentsScale = 1.0;
#endif // TODO(macOS ISS#2323203)
      layer.tileSize = CGSizeMake(textViewTileSize, textViewTileSize);
      _asyncTiledLayer = layer;
      [self.layer addSublayer:layer];
      [layer setNeedsDisplay];
    }
    _asyncTiledLayer.frame = self.bounds;
    currentLayer = _asyncTiledLayer;
  } else {
    // Cleanup async tiled layer
    if (_asyncTiledLayer != nil) {
      _asyncTiledLayer.delegate = nil;
      [_asyncTiledLayer removeFromSuperlayer];
      _asyncTiledLayer = nil;
    }

    if (_syncLayer == nil) {
      CALayer *layer = [CALayer layer];
      layer.delegate = _renderer;
#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
      layer.contentsScale = RCTScreenScale();
#else
      layer.contentsScale = 1.0;
#endif // TODO(macOS ISS#2323203)
      _syncLayer = layer;
      [self.layer addSublayer:layer];
      [layer setNeedsDisplay];
    }
    _syncLayer.frame = self.bounds;
    currentLayer = _syncLayer;
  }

  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSRange glyphRange =
    [layoutManager glyphRangeForTextContainer:textContainer];

  __block UIBezierPath *highlightPath = nil;
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                     actualGlyphRange:NULL];

  [_textStorage enumerateAttribute:RCTTextAttributesIsHighlightedAttributeName
                           inRange:characterRange
                           options:0
                        usingBlock:
   ^(NSNumber *value, NSRange range, __unused BOOL *stop) {
     if (!value.boolValue) {
       return;
     }

     [layoutManager enumerateEnclosingRectsForGlyphRange:range
                                withinSelectedGlyphRange:range
                                         inTextContainer:textContainer
                                              usingBlock:
      ^(CGRect enclosingRect, __unused BOOL *anotherStop) {
#if !TARGET_OS_OSX // TODO(macOS ISS#3536887)
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(enclosingRect, -2, -2) cornerRadius:2];
#else // TODO(macOS ISS#3536887)
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(enclosingRect, -2, -2) xRadius:2 yRadius:2];
#endif // TODO(macOS ISS#3536887)
        if (highlightPath) {
          UIBezierPathAppendPath(highlightPath, path); // TODO(macOS ISS#2323203)
        } else {
          highlightPath = path;
        }
      }
      ];
   }];

  if (highlightPath) {
    if (!_highlightLayer) {
      _highlightLayer = [CAShapeLayer layer];
      _highlightLayer.fillColor = [UIColor colorWithWhite:0 alpha:0.25].CGColor;
    }
    if (![currentLayer.sublayers containsObject:_highlightLayer]) {
      [currentLayer addSublayer:_highlightLayer];
    }
    _highlightLayer.position = _contentFrame.origin;
    _highlightLayer.path = UIBezierPathCreateCGPathRef(highlightPath); // TODO(macOS ISS#2323203)
  } else {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }
}

- (void)setCurrentLayerNeedsDisplay
{
  if (_asyncTiledLayer != nil) {
    [_asyncTiledLayer setNeedsDisplay];
  } else if (_syncLayer != nil) {
    [_syncLayer setNeedsDisplay];
  }
  [_highlightLayer setNeedsDisplay];
}

- (NSNumber *)reactTagAtPoint:(CGPoint)point
{
  NSNumber *reactTag = self.reactTag;

  CGFloat fraction;
  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSUInteger characterIndex = [layoutManager characterIndexForPoint:point
                                                    inTextContainer:textContainer
                           fractionOfDistanceBetweenInsertionPoints:&fraction];

  // If the point is not before (fraction == 0.0) the first character and not
  // after (fraction == 1.0) the last character, then the attribute is valid.
  if (_textStorage.length > 0 && (fraction > 0 || characterIndex > 0) && (fraction < 1 || characterIndex < _textStorage.length - 1)) {
    reactTag = [_textStorage attribute:RCTTextAttributesTagAttributeName atIndex:characterIndex effectiveRange:NULL];
  }

  return reactTag;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  // When an `RCTText` instance moves offscreen (possibly due to parent clipping),
  // we unset the layer's contents until it comes onscreen again.
  if (!self.window) {
    [_syncLayer removeFromSuperlayer];
    _syncLayer = nil;
    [_asyncTiledLayer removeFromSuperlayer];
    _asyncTiledLayer = nil;
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  } else if (_textStorage) {
    [self configureLayer];
    [self setCurrentLayerNeedsDisplay];
  }
}

#pragma mark - Accessibility

- (NSString *)accessibilityLabel
{
  NSString *superAccessibilityLabel = [super accessibilityLabel];
  if (superAccessibilityLabel) {
    return superAccessibilityLabel;
  }
  return _textStorage.string;
}

#pragma mark - Context Menu

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
- (void)enableContextMenu
{
  _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  [self addGestureRecognizer:_longPressGestureRecognizer];
}

- (void)disableContextMenu
{
  [self removeGestureRecognizer:_longPressGestureRecognizer];
  _longPressGestureRecognizer = nil;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
#if !TARGET_OS_TV
  UIMenuController *menuController = [UIMenuController sharedMenuController];

  if (menuController.isMenuVisible) {
    return;
  }

  if (!self.isFirstResponder) {
    [self becomeFirstResponder];
  }

  [menuController setTargetRect:self.bounds inView:self];
  [menuController setMenuVisible:YES animated:YES];
#endif
}
#else // [TODO(macOS ISS#2323203)

- (void)rightMouseDown:(NSEvent *)event
{
  if (_selectable == NO) {
    [super rightMouseDown:event];
    return;
  }
  NSText *fieldEditor = [self.window fieldEditor:YES forObject:self];
  NSMenu *fieldEditorMenu = [fieldEditor menuForEvent:event];

  RCTAssert(fieldEditorMenu, @"Unable to obtain fieldEditor's context menu");

  if (fieldEditorMenu) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

    for (NSMenuItem *fieldEditorMenuItem in fieldEditorMenu.itemArray) {
      if (fieldEditorMenuItem.action == @selector(copy:)) {
        NSMenuItem *item = [fieldEditorMenuItem copy];

        item.target = self;
        [menu addItem:item];

        break;
      }
    }

    RCTAssert(menu.numberOfItems > 0, @"Unable to create context menu with \"Copy\" item");

    if (menu.numberOfItems > 0) {
      [NSMenu popUpContextMenu:menu withEvent:event forView:self];
    }
  }
}
#endif // ]TODO(macOS ISS#2323203)

- (BOOL)canBecomeFirstResponder
{
  return _selectable;
}

#if !TARGET_OS_OSX // TODO(macOS ISS#2323203)
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (_selectable && action == @selector(copy:)) {
    return YES;
  }

  return [self.nextResponder canPerformAction:action withSender:sender];
}
#endif // TODO(macOS ISS#2323203)

- (void)copy:(id)sender
{
#if !TARGET_OS_TV
  NSAttributedString *attributedText = _textStorage;

  NSData *rtf = [attributedText dataFromRange:NSMakeRange(0, attributedText.length)
                           documentAttributes:@{NSDocumentTypeDocumentAttribute: NSRTFDTextDocumentType}
                                        error:nil];
#if TARGET_OS_IPHONE // TODO(macOS ISS#2323203)
  NSMutableDictionary *item = [NSMutableDictionary new]; // TODO(macOS ISS#2323203)

  if (rtf) {
    [item setObject:rtf forKey:(id)kUTTypeFlatRTFD];
  }

  [item setObject:attributedText.string forKey:(id)kUTTypeUTF8PlainText];

  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  pasteboard.items = @[item];
#elif TARGET_OS_OSX // TODO(macOS ISS#2323203)
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard writeObjects:[NSArray arrayWithObjects:attributedText.string, rtf, nil]];
#endif // TODO(macOS ISS#2323203)
#endif
}

@end
