package com.pdftron.reactnative.tools;

import android.graphics.Point;
import android.net.Uri;

import com.pdftron.common.Matrix2D;
import com.pdftron.filters.SecondaryFileFilter;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.Image;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Page;
import com.pdftron.pdf.PageSet;
import com.pdftron.pdf.Rect;
import com.pdftron.pdf.annots.Markup;
import com.pdftron.pdf.tools.RubberStampCreate;
import com.pdftron.pdf.utils.AnalyticsHandlerAdapter;
import com.pdftron.pdf.utils.Utils;
import com.pdftron.sdf.Obj;
import com.pdftron.sdf.ObjSet;


public class CustomRubberStampTool extends RubberStampCreate {
    private Uri imageUri;
    private String data;

    public CustomRubberStampTool(PDFViewCtrl ctrl, Uri imageUri, String data) {
        super(ctrl);
        this.imageUri = imageUri;
        this.data = data;
    }

    @Override
    protected void addStamp() {
        createImageStamp(this.imageUri, 0, null);
    }

    @Override
    public boolean createImageStamp(Uri uri, int imageRotation, String filePath) {
        boolean shouldUnlock = false;
        SecondaryFileFilter filter = null;

        boolean var11;
        try {
            this.mPdfViewCtrl.docLock(true);
            shouldUnlock = true;
            PDFDoc doc = this.mPdfViewCtrl.getDoc();
            filter = new SecondaryFileFilter(this.mPdfViewCtrl.getContext(), uri);
            ObjSet hintSet = new ObjSet();
            Obj encoderHints = hintSet.createArray();
            encoderHints.pushBackName("JPEG");
            encoderHints.pushBackName("Quality");
            encoderHints.pushBackNumber(85.0);
            Image img = Image.create(doc.getSDFDoc(), filter, encoderHints);
            int pageNum;
            if (this.mTargetPoint != null) {
                pageNum = this.mPdfViewCtrl.getPageNumberFromScreenPt((double)this.mTargetPoint.x, (double)this.mTargetPoint.y);
                if (pageNum <= 0) {
                    pageNum = this.mPdfViewCtrl.getCurrentPage();
                }
            } else {
                pageNum = this.mPdfViewCtrl.getCurrentPage();
            }

            if (pageNum > 0) {
                Page page = doc.getPage(pageNum);
                int viewRotation = this.mPdfViewCtrl.getPageRotation();
                Rect pageViewBox = page.getBox(this.mPdfViewCtrl.getPageBox());
                Rect pageCropBox = page.getCropBox();
                int pageRotation = page.getRotation();
                Point size = new Point();
                Utils.getDisplaySize(this.mPdfViewCtrl.getContext(), size);
                int screenWidth = size.x < size.y ? size.x : size.y;
                int screenHeight = size.x < size.y ? size.y : size.x;
                double maxImageHeightPixels = (double)screenHeight * 0.25;
                double maxImageWidthPixels = (double)screenWidth * 0.25;
                double[] point1 = this.mPdfViewCtrl.convScreenPtToPagePt(0.0, 0.0, pageNum);
                double[] point2 = this.mPdfViewCtrl.convScreenPtToPagePt(20.0, 20.0, pageNum);
                double pixelsToPageRatio = Math.abs(point1[0] - point2[0]) / 20.0;
                double maxImageHeightPage = maxImageHeightPixels * pixelsToPageRatio;
                double maxImageWidthPage = maxImageWidthPixels * pixelsToPageRatio;
                double stampWidth = (double)img.getImageWidth();
                double stampHeight = (double)img.getImageHeight();
                double pageWidth;
                if (imageRotation == 90 || imageRotation == 270) {
                    pageWidth = stampWidth;
                    stampWidth = stampHeight;
                    stampHeight = pageWidth;
                }

                pageWidth = pageViewBox.getWidth();
                double pageHeight = pageViewBox.getHeight();
                double scaleFactor;
                if (pageRotation == 1 || pageRotation == 3) {
                    scaleFactor = pageWidth;
                    pageWidth = pageHeight;
                    pageHeight = scaleFactor;
                }

                if (pageWidth < maxImageWidthPage) {
                    maxImageWidthPage = pageWidth;
                }

                if (pageHeight < maxImageHeightPage) {
                    maxImageHeightPage = pageHeight;
                }

                scaleFactor = Math.min(maxImageWidthPage / stampWidth, maxImageHeightPage / stampHeight);
                stampWidth *= scaleFactor;
                stampHeight *= scaleFactor;
                if (viewRotation == 1 || viewRotation == 3) {
                    double temp = stampWidth;
                    stampWidth = stampHeight;
                    stampHeight = temp;
                }

                if (this.getAbsoluteStampWidth() > 0.0) {
                    stampWidth = this.getAbsoluteStampWidth();
                }

                if (this.getAbsoluteStampHeight() > 0.0) {
                    stampHeight = this.getAbsoluteStampHeight();
                }

                com.pdftron.pdf.Stamper stamper = new com.pdftron.pdf.Stamper(2, stampWidth, stampHeight);
                if (this.mTargetPoint != null) {
                    double[] pageTarget = this.mPdfViewCtrl.convScreenPtToPagePt((double)this.mTargetPoint.x, (double)this.mTargetPoint.y, pageNum);
                    Matrix2D mtx = page.getDefaultMatrix();
                    com.pdftron.pdf.Point pageTargetPoint = mtx.multPoint(pageTarget[0], pageTarget[1]);
                    stamper.setAlignment(-1, -1);
                    pageTargetPoint.x -= stampWidth / 2.0;
                    pageTargetPoint.y -= stampHeight / 2.0;
                    double leftEdge = pageViewBox.getX1() - pageCropBox.getX1();
                    double bottomEdge = pageViewBox.getY1() - pageCropBox.getY1();
                    if (pageTargetPoint.x > leftEdge + pageWidth - stampWidth) {
                        pageTargetPoint.x = leftEdge + pageWidth - stampWidth;
                    }

                    if (pageTargetPoint.x < leftEdge) {
                        pageTargetPoint.x = leftEdge;
                    }

                    if (pageTargetPoint.y > bottomEdge + pageHeight - stampHeight) {
                        pageTargetPoint.y = bottomEdge + pageHeight - stampHeight;
                    }

                    if (pageTargetPoint.y < bottomEdge) {
                        pageTargetPoint.y = bottomEdge;
                    }

                    stamper.setPosition(pageTargetPoint.x, pageTargetPoint.y);
                } else {
                    stamper.setPosition(0.0, 0.0);
                }

                stamper.setAsAnnotation(true);
                int stampRotation = (4 - viewRotation) % 4;
                stamper.setRotation((double)stampRotation * 90.0 + (double)imageRotation);
                stamper.stampImage(doc, img, new PageSet(pageNum));
                int numAnnots = page.getNumAnnots();
                Annot annot = page.getAnnot(numAnnots - 1);
                annot.setCustomData("data", this.data);
                Obj obj = annot.getSDFObj();
                obj.putNumber("pdftronImageStampRotation", 0.0);
                if (annot.isMarkup()) {
                    Markup markup = new Markup(annot);
                    this.setAuthor(markup);
                }

                this.setAnnot(annot, pageNum);
                this.buildAnnotBBox();
                this.mPdfViewCtrl.update(annot, pageNum);
                this.raiseAnnotationAddedEvent(annot, pageNum);
                boolean var58 = true;
                return var58;
            }

            var11 = false;
        } catch (Exception var52) {
            AnalyticsHandlerAdapter.getInstance().sendException(var52);
            boolean var7 = false;
            return var7;
        } finally {
            Utils.closeQuietly(filter);
            if (shouldUnlock) {
                this.mPdfViewCtrl.docUnlock();
            }

            this.mTargetPoint = null;
            this.safeSetNextToolMode();
        }

        return var11;
    }
}