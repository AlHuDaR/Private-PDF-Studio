import '../core/model.dart';

class Strings {
  const Strings(this.ar);
  final bool ar;
  String t(String en, String arabic) => ar ? arabic : en;
  String get title => t('Private PDF Studio', 'استوديو PDF الخاص');
  String get privacy => t(
    'Your PDFs stay on this device. No uploads, accounts or fees.',
    'تبقى ملفات PDF على جهازك. بلا رفع أو حسابات أو رسوم.',
  );
  String get add => t('Import PDFs', 'استيراد ملفات PDF');
  String get merge => t('Merge / export all', 'دمج / تصدير الكل');
  String get extract => t('Split / extract selected', 'تقسيم / استخراج المحدد');
  String get clear => t('Clear workspace', 'مسح مساحة العمل');
  String get empty => t(
    'Import PDFs, arrange their pages, then export a new copy.',
    'استورد الملفات ورتب صفحاتها ثم صدّر نسخة جديدة.',
  );
  String get limits => t(
    'Up to 10 files, 20 MiB each, 50 MiB total and 500 pages. Encrypted PDFs are not supported.',
    'حتى ١٠ ملفات، ٢٠ ميبيبايت للملف و٥٠ إجمالاً و٥٠٠ صفحة. الملفات المشفرة غير مدعومة.',
  );
  String get cancel => t('Cancel processing', 'إلغاء المعالجة');
  String get working => t('Processing locally…', 'جارٍ المعالجة محلياً…');
  String get saving =>
      t('Choose where to save the new copy…', 'اختر مكان حفظ النسخة الجديدة…');
  String get reading =>
      t('Choose and read local files…', 'اختيار وقراءة الملفات المحلية…');
  String get selectAll => t('Select all', 'تحديد الكل');
  String get deselect => t('Deselect all', 'إلغاء تحديد الكل');
  String get up => t('Move page up', 'نقل الصفحة للأعلى');
  String get down => t('Move page down', 'نقل الصفحة للأسفل');
  String get rotate => t('Rotate 90° clockwise', 'تدوير ٩٠° مع عقارب الساعة');
  String get remove => t('Remove page from output', 'إزالة الصفحة من الناتج');
  String page(int n, int angle) =>
      t('Page $n · +$angle°', 'الصفحة $n · +$angle°');
  String summary(int files, int pages, int selected) => t(
    '$files files · $pages pages · $selected selected',
    '$files ملفات · $pages صفحات · $selected محددة',
  );
  String get imported => t(
    'PDFs imported. Originals remain unchanged.',
    'تم استيراد الملفات. النسخ الأصلية لم تتغير.',
  );
  String get saved => t('New PDF saved.', 'تم حفظ ملف PDF جديد.');
  String get download => t(
    'Download started. Check your browser downloads.',
    'بدأ التنزيل. تحقق من تنزيلات المتصفح.',
  );
  String get saveCancelled => t(
    'Save cancelled. Your workspace is unchanged.',
    'تم إلغاء الحفظ. مساحة العمل لم تتغير.',
  );
  String get cleared => t('Workspace cleared.', 'تم مسح مساحة العمل.');
  String get about => t(
    'About and open-source licenses',
    'حول التطبيق وتراخيص المصادر المفتوحة',
  );
  String get explanation => t(
    'Exports contain the displayed pages in order. To split a PDF, select one partition, extract it, then select the next partition. Rotation adds to the original page angle. Clear and reimport to restore removed pages. Document-level bookmarks, signatures, forms and attachments are not preserved or certified. Output is not a sanitizer; never trust an unknown PDF. Cancellation takes effect between engine tasks; an active parse/encode cannot be interrupted.',
    'يحتوي التصدير على الصفحات المعروضة بترتيبها. للتقسيم، حدد مجموعة واستخرجها ثم حدد المجموعة التالية. يضاف التدوير إلى زاوية الصفحة الأصلية. امسح وأعد الاستيراد لاستعادة الصفحات المحذوفة. لا نضمن حفظ الإشارات المرجعية أو التوقيعات أو النماذج أو المرفقات. الناتج ليس ملفاً منقّى أمنياً؛ لا تثق بملف مجهول. يسري الإلغاء بين مهام المحرك؛ لا يمكن قطع التحليل أو الترميز الجاري.',
  );
  String error(Failure failure) => switch (failure) {
    Failure.invalidPdf => t(
      'Invalid or damaged PDF. No files were added.',
      'ملف PDF غير صالح أو تالف. لم تُضف ملفات.',
    ),
    Failure.encrypted => t(
      'Encrypted PDFs are not supported. No files were added.',
      'الملفات المشفرة غير مدعومة. لم تُضف ملفات.',
    ),
    Failure.tooLarge => t(
      'File, workspace or output size limit exceeded.',
      'تم تجاوز الحد الأقصى لحجم الملف أو مساحة العمل أو الناتج.',
    ),
    Failure.tooManyFiles => t(
      'The workspace supports up to 10 files.',
      'تدعم مساحة العمل ١٠ ملفات كحد أقصى.',
    ),
    Failure.tooManyPages => t(
      'The workspace supports up to 500 pages.',
      'تدعم مساحة العمل ٥٠٠ صفحة كحد أقصى.',
    ),
    Failure.emptySelection => t(
      'Select at least one page.',
      'حدد صفحة واحدة على الأقل.',
    ),
    Failure.invalidPage => t(
      'Invalid page selection. Reimport the source PDF.',
      'اختيار صفحة غير صالح. أعد استيراد الملف.',
    ),
    Failure.cancelled => t(
      'Processing cancelled. No output was saved.',
      'تم إلغاء المعالجة. لم يُحفظ ناتج.',
    ),
    Failure.busy => t(
      'Please wait for the current operation.',
      'يرجى انتظار العملية الحالية.',
    ),
    Failure.exportFailed => t(
      'PDF export failed. No output was saved.',
      'فشل تصدير PDF. لم يُحفظ ناتج.',
    ),
    Failure.fileAccess => t(
      'Cannot access the file. Check location and permissions.',
      'تعذر الوصول للملف. تحقق من الموقع والأذونات.',
    ),
    Failure.existingFile => t(
      'That file already exists. Choose a new filename.',
      'الملف موجود بالفعل. اختر اسماً جديداً.',
    ),
    Failure.engineUnavailable => t(
      'PDF engine could not start. Retry or restart the app.',
      'تعذر تشغيل محرك PDF. أعد المحاولة أو أعد تشغيل التطبيق.',
    ),
  };
}
