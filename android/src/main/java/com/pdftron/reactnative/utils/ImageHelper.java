package com.pdftron.reactnative.utils;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class ImageHelper {

    public static Uri fetchImageToUri(Context context, String imageUrl) {
        try {
            URL url = new URL(imageUrl);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setDoInput(true);
            connection.connect();
            InputStream input = connection.getInputStream();
            Bitmap bitmap = BitmapFactory.decodeStream(input);

            File outputDir = context.getCacheDir();
            File outputFile = File.createTempFile("prefix", "extension", outputDir);
            FileOutputStream out = new FileOutputStream(outputFile);
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
            out.flush();
            out.close();

            return Uri.fromFile(outputFile);
        } catch (Exception e) {
            Log.e("ImageHelper", "Error fetching image", e);
            return null;
        }
    }
}
