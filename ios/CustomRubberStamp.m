#import "CustomRubberStamp.h"
#import <PDFKit/PDFKit.h>

@interface CustomRubberStamp () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong, nullable) PTPDFPoint *touchPtPage;
@property (nonatomic, assign) BOOL isPencilTouch;

@property (nonatomic, strong) NSString *imageUrl;
@property (nonatomic, strong) NSString *data;

@end

@implementation CustomRubberStamp

@dynamic isPencilTouch;


- (instancetype)initWithPDFViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl imageUrl:(NSString *)imageUrl data:(NSString *)data
{
    self = [super initWithPDFViewCtrl:pdfViewCtrl];
    if (self) {
        self.imageUrl = imageUrl;
        self.data = data;
    }

    return self;
}

- (Class)annotClass
{
    return [PTRubberStamp class];
}

+ (PTExtendedAnnotType)annotType
{
    return PTExtendedAnnotTypeStamp;
}

-(void)setToolManager:(PTToolManager *)toolManager
{
    [super setToolManager:toolManager];
    
    self.pdfViewCtrl.minimumTwoFingersToScrollEnabled = NO;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    
    if( !(self.isPencilTouch == YES || self.toolManager.annotationsCreatedWithPencilOnly == NO) )
    {
        return YES;
    }
    
    CGPoint touchPoint = [gestureRecognizer locationInView:self.pdfViewCtrl];

    __block int pageNumber = 0;

    NSError *error = nil;
    [self.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:touchPoint.x y:touchPoint.y];
    } error:&error];

    if (error) {
        NSLog(@"Error: %@", error);
        return YES;
    }
    if (pageNumber < 1) {
        return YES;
    }

    // Save page number for touch point.
    _pageNumber = pageNumber;
    self.endPoint = touchPoint;
    [self stampImage];
    // Tap handled.
    return YES;
}

- (BOOL)onSwitchToolEvent:(id)userData
{
    if (userData &&
        (userData == self.defaultClass ||
        [(NSString*)userData isEqualToString:@"CloseAnnotationToolbar"])) {

        self.nextToolType = self.defaultClass;
        return NO;
    }else {
        self.endPoint = self.longPressPoint;
        _pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:self.endPoint.x y:self.endPoint.y];
        [self stampImage];

        return YES;
    }
}

- (void)stampImage
{
    NSURL *url = [NSURL URLWithString:self.imageUrl];
    NSData *imageData = [NSData dataWithContentsOfURL:url];
    UIImage *image = [UIImage imageWithData:imageData];
    
    [self createStampWithImage:image];
}


- (void)createStampWithImage:(UIImage*)image
{
    self.image = [self correctForRotation:image];
    [self createStampWithImage:self.image atPoint:self.endPoint];
    [self.toolManager createSwitchToolEvent:self.defaultClass];
}

- (void)createStampWithImage:(UIImage *)image atPoint:(CGPoint)point
{

    NSString* temporaryImageDataPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pt_stamp_tempImage"];
    NSError *error;

    BOOL hasWriteLock = NO;
    @try {
        [self.pdfViewCtrl DocLock:YES];
        hasWriteLock = YES;
        
        PTPDFDoc *doc = [self.pdfViewCtrl GetDoc];

        _pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:point.x y:point.y];
        
        PTPage* page = [doc GetPage:self.pageNumber];

        PTPDFRect* stampRect = [[PTPDFRect alloc] initWithX1:0 y1:0 x2:image.size.width y2:image.size.height];
        double maxWidth = 80;
        double maxHeight = 80;
        
        PTRotate ctrlRotation = [self.pdfViewCtrl GetRotation];
        PTRotate pageRotation = [page GetRotation];
        PTRotate viewRotation = ((pageRotation + ctrlRotation) % 4);

        PTPDFRect* pageCropBox = [page GetCropBox];
        
        if ([pageCropBox Width] < maxWidth)
        {
            maxWidth = [pageCropBox Width];
        }
        if ([pageCropBox Height] < maxHeight)
        {
            maxHeight = [pageCropBox Height];
        }
        
        if (viewRotation == e_pt90 || viewRotation == e_pt270) {
            // Swap width and height if visible page is rotated 90 or 270 degrees
            maxWidth = maxWidth + maxHeight;
            maxHeight = maxWidth - maxHeight;
            maxWidth = maxWidth - maxHeight;
        }

        CGFloat scaleFactor = MIN(maxWidth / [stampRect Width], maxHeight / [stampRect Height]);
        CGFloat stampWidth = [stampRect Width] * scaleFactor;
        CGFloat stampHeight = [stampRect Height] * scaleFactor;
        
        if (ctrlRotation == e_pt90 || ctrlRotation == e_pt270) {
            // Swap width and height if pdfViewCtrl is rotated 90 or 270 degrees
            stampWidth = stampWidth + stampHeight;
            stampHeight = stampWidth - stampHeight;
            stampWidth = stampWidth - stampHeight;
        }

        PTStamper* stamper = [[PTStamper alloc] initWithSize_type:e_ptabsolute_size a:stampWidth b:stampHeight];
        [stamper SetAlignment:e_pthorizontal_left vertical_alignment:e_ptvertical_bottom];
        [stamper SetAsAnnotation:YES];
        
        // Account for page rotation in the page-space touch point
        PTMatrix2D *mtx = [page GetDefaultMatrix:NO box_type:e_ptcrop angle:0];

        self.touchPtPage = [self.pdfViewCtrl ConvScreenPtToPagePt:[[PTPDFPoint alloc] initWithPx:point.x py:point.y] page_num:self.pageNumber];
        self.touchPtPage = [mtx Mult:self.touchPtPage];
        
        CGFloat xPos = [self.touchPtPage getX] - (stampWidth / 2);
        CGFloat yPos = [self.touchPtPage getY] - (stampHeight / 2);

        double pageWidth = [[page GetCropBox] Width];
        if (xPos > pageWidth - stampWidth)
        {
            xPos = pageWidth - stampWidth;
        }
        if (xPos < 0)
        {
            xPos = 0;
        }
        double pageHeight = [[page GetCropBox] Height];
        if (yPos > pageHeight - stampHeight)
        {
            yPos = pageHeight - stampHeight;
        }
        if (yPos < 0)
        {
            yPos = 0;
        }
        
        [stamper SetPosition:xPos vertical_distance:yPos use_percentage:NO];
        
        PTPageSet* pageSet = [[PTPageSet alloc] initWithOne_page:self.pageNumber];
        
        NSData* data = UIImagePNGRepresentation(image);
        
        PTObjSet* hintSet = [[PTObjSet alloc] init];
        PTObj* encoderHints = [hintSet CreateArray];

        // Flate compression is good for graphics but very inefficent for photos
        NSString *compressionAlgorithm = @"Flate";
        NSInteger compressionQuality = 5;
        [encoderHints PushBackName:compressionAlgorithm];
        if ([compressionAlgorithm isEqualToString:@"Flate"]) {
            [encoderHints PushBackName:@"Level"];
            [encoderHints PushBackNumber:compressionQuality];
        }

        if ([NSFileManager.defaultManager fileExistsAtPath:temporaryImageDataPath]) {
            [NSFileManager.defaultManager removeItemAtPath:temporaryImageDataPath error:&error];
        }
        BOOL creationSuccess = [NSFileManager.defaultManager createFileAtPath:temporaryImageDataPath
                                                                     contents:data
                                                                   attributes:nil];
        
        PTImage* stampImage;
        if (creationSuccess && !error) {
            // Use temp file
            stampImage = [PTImage Create:[doc GetSDFDoc] filename:temporaryImageDataPath];
        }else{
            // Fallback on create with data method
            NSString *compressionAlgorithm = @"JPEG";

            NSInteger compressionQuality = 60;
            [encoderHints PushBackName:compressionAlgorithm];
            [encoderHints PushBackName:@"Quality"];
            [encoderHints PushBackNumber:compressionQuality];

            stampImage = [PTImage CreateWithData:[doc GetSDFDoc] buf:data buf_size:data.length width:image.size.width height:image.size.height bpc:8 color_space:[PTColorSpace CreateDeviceRGB] encoder_hints:encoderHints];
        }

        // Rotate stamp based on the pdfViewCtrl's rotation
        PTRotate stampRotation = (4 - viewRotation) % 4; // 0 = 0, 90 = 1; 180 = 2, and 270 = 3
        [stamper SetRotation:stampRotation * 90.0];
        [stamper StampImage:doc src_img:stampImage dest_pages:pageSet];
        
        int numAnnots = [page GetNumAnnots];
        
        assert(numAnnots > 0);
        
        PTAnnot* annot = [page GetAnnot:numAnnots - 1];
        PTObj* obj = [annot GetSDFObj];
        [obj PutString:PTImageStampAnnotationIdentifier value:@""];
        [obj PutNumber:PTImageStampAnnotationRotationDegreeIdentifier value:0.0];
        
        // Set the image-stamp annotation identifier in the custom data for (X)FDF compatibility,
        // otherwise there is nothing in the (X)FDF to distinguish the annotation from a regular
        // stamp annotation.
        // NOTE: A non-empty string value is required.
        [annot SetCustomData:PTImageStampAnnotationIdentifier value:@"YES"];
        [annot SetCustomData:@"data" value:self.data];
        
        // Set up to transfer to PTAnnotEditTool
        self.currentAnnotation = annot;
        [self.currentAnnotation RequestRefreshAppearance];
        
        self.annotationPageNumber = self.pageNumber;
        
        [self.pdfViewCtrl UpdateWithAnnot:annot page_num:self.pageNumber];
        
    } @catch (NSException *exception) {
        NSLog(@"Exception: %@, %@", exception.name, exception.reason);
    } @finally {
        if (hasWriteLock) {
            [self.pdfViewCtrl DocUnlock];
        }
        if ([NSFileManager.defaultManager fileExistsAtPath:temporaryImageDataPath]) {
            [NSFileManager.defaultManager removeItemAtPath:temporaryImageDataPath error:&error];
        }
    }
    
    if (self.currentAnnotation && self.annotationPageNumber > 0) {
        [self annotationAdded:self.currentAnnotation onPageNumber:self.annotationPageNumber];
    }
}

-(UIImage*)correctForRotation:(UIImage*)src
{
    UIGraphicsBeginImageContext(src.size);
    
    [src drawAtPoint:CGPointMake(0, 0)];
    
    UIImage* img =  UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}
@end
