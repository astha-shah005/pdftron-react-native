#import <Foundation/Foundation.h>
#import <PDFNet/PDFNet.h>
#import <Tools/Tools.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Create image stamp annotations.
 */
PT_OBJC_RUNTIME_NAME(ImageStampCreate)
@interface CustomRubberStamp : PTRubberStampCreate

-(instancetype)initWithPDFViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl imageUrl:(NSString *)imageUrl data:(NSString *)data;

@end

NS_ASSUME_NONNULL_END
