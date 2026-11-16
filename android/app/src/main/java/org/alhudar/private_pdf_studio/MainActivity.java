package org.alhudar.private_pdf_studio;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Bounded SAF reads without temporary copies; fresh local-document exports. */
public class MainActivity extends FlutterActivity {
    private static final int CREATE_PDF = 4001;
    private static final int OPEN_PDFS = 4002;
    private static final int MAX_FILE = 20 * 1024 * 1024;
    private static final int MAX_TOTAL = 50 * 1024 * 1024;
    private static final int MAX_OUTPUT = 100 * 1024 * 1024;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private MethodChannel.Result pending;
    private byte[] output;
    private int remainingFiles;
    private int remainingBytes;
    private int pendingRequest;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),
            "private_pdf_studio/files").setMethodCallHandler((call, result) -> {
            if (pending != null) { result.error("busy", "File operation in progress", null); return; }
            if (call.method.equals("openPdfs")) {
                Integer files = call.argument("remainingFiles");
                Integer bytes = call.argument("remainingBytes");
                if (files == null || files < 1 || files > 10) {
                    result.error("too_many_files", "File limit exceeded", null); return;
                }
                if (bytes == null || bytes < 1 || bytes > MAX_TOTAL) {
                    result.error("too_large", "Size limit exceeded", null); return;
                }
                remainingFiles = files;
                remainingBytes = bytes;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/pdf");
                intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
                launch(intent, OPEN_PDFS, result);
            } else if (call.method.equals("savePdf")) {
                byte[] bytes = call.argument("bytes");
                String name = call.argument("name");
                if (bytes == null || bytes.length == 0 || bytes.length > MAX_OUTPUT ||
                    name == null || name.contains("/") || name.contains("\\")) {
                    result.error("invalid", "Invalid output", null); return;
                }
                output = bytes;
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/pdf");
                intent.putExtra(Intent.EXTRA_TITLE, name);
                intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
                launch(intent, CREATE_PDF, result);
            } else { result.notImplemented(); }
        });
    }

    private void launch(Intent intent, int request, MethodChannel.Result result) {
        pending = result;
        pendingRequest = request;
        try { startActivityForResult(intent, request); }
        catch (Exception ignored) { complete(null, "file_access"); }
    }

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (pending == null || request != pendingRequest) return;
        if (result != Activity.RESULT_OK || data == null) {
            complete(request == OPEN_PDFS ? new ArrayList<>() : false, null); return;
        }
        if (request == OPEN_PDFS) {
            final List<Uri> uris = new ArrayList<>();
            ClipData clip = data.getClipData();
            if (clip != null) {
                if (clip.getItemCount() > remainingFiles) { complete(null, "too_many_files"); return; }
                for (int i = 0; i < clip.getItemCount(); i++) uris.add(clip.getItemAt(i).getUri());
            } else if (data.getData() != null) { uris.add(data.getData()); }
            io.execute(() -> readPdfs(uris));
            return;
        }
        final Uri uri = data.getData();
        if (uri == null) { complete(false, null); return; }
        final byte[] bytes = output;
        io.execute(() -> {
            boolean success = false;
            try (OutputStream stream = getContentResolver().openOutputStream(uri, "w")) {
                if (stream == null) throw new IllegalStateException();
                stream.write(bytes);
                stream.flush();
                success = true;
            } catch (Exception ignored) {
                success = false;
                try { getContentResolver().delete(uri, null, null); }
                catch (Exception alsoIgnored) { /* no document data is logged */ }
            }
            final boolean saved = success;
            runOnUiThread(() -> complete(saved, saved ? null : "file_access"));
        });
    }

    private void readPdfs(List<Uri> uris) {
        try {
            if (uris.size() > remainingFiles) throw new LimitException("too_many_files");
            final List<Map<String, Object>> files = new ArrayList<>();
            int total = 0;
            for (Uri uri : uris) {
                String name = "document.pdf";
                try (Cursor cursor = getContentResolver().query(uri,
                    new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}, null, null, null)) {
                    if (cursor != null && cursor.moveToFirst()) {
                        int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                        if (nameIndex >= 0 && !cursor.isNull(nameIndex)) name = cursor.getString(nameIndex);
                        int sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE);
                        if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                            long size = cursor.getLong(sizeIndex);
                            if (size > MAX_FILE || size > remainingBytes - total) {
                                throw new LimitException("too_large");
                            }
                        }
                    }
                }
                try (InputStream input = getContentResolver().openInputStream(uri);
                     ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
                    if (input == null) throw new IllegalStateException();
                    byte[] chunk = new byte[64 * 1024];
                    int count;
                    while ((count = input.read(chunk)) != -1) {
                        if (bytes.size() + count > MAX_FILE ||
                            total + bytes.size() + count > remainingBytes) {
                            throw new LimitException("too_large");
                        }
                        bytes.write(chunk, 0, count);
                    }
                    byte[] content = bytes.toByteArray();
                    total += content.length;
                    Map<String, Object> file = new HashMap<>();
                    file.put("name", name);
                    file.put("bytes", content);
                    files.add(file);
                }
            }
            runOnUiThread(() -> complete(files, null));
        } catch (LimitException limit) {
            runOnUiThread(() -> complete(null, limit.code));
        } catch (Exception ignored) {
            runOnUiThread(() -> complete(null, "file_access"));
        }
    }

    private static class LimitException extends Exception {
        final String code;
        LimitException(String code) { this.code = code; }
    }

    private void complete(Object value, String error) {
        final MethodChannel.Result callback = pending;
        pending = null;
        output = null;
        if (callback == null) return;
        if (error != null) callback.error(error, "File operation failed", null);
        else callback.success(value);
    }

    @Override
    protected void onDestroy() {
        complete(null, "file_access");
        io.shutdown();
        super.onDestroy();
    }
}
