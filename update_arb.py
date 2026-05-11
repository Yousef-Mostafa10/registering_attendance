import json

en_file = 'lib/l10n/app_en.arb'
ar_file = 'lib/l10n/app_ar.arb'

en_data = json.load(open(en_file, 'r', encoding='utf-8'))
ar_data = json.load(open(ar_file, 'r', encoding='utf-8'))

new_keys_en = {
    "doctorsList": "Doctors List",
    "teachingAssistantsList": "Teaching Assistants List",
    "doctorsCount": "{count} Doctors",
    "@doctorsCount": {"placeholders": {"count": {"type": "String"}}},
    "taCount": "{count} Teaching Assistants",
    "@taCount": {"placeholders": {"count": {"type": "String"}}},
    "autoRefresh30": "Auto-refresh every 30 seconds",
    "searchDoctors": "...Search doctors",
    "searchTAs": "...Search TAs",
    "passwordReqs": "Password requirements:",
    "atLeast6Chars": "At least 6 characters",
    "bulkDeleteStudents": "Bulk Delete Students",
    "howToDeleteStudents": "How to delete students",
    "deleteOption1": "Option 1: Use \"Import from Excel\" to upload a .xlsx file containing a \"University Code\" column",
    "deleteOption2": "Option 2: Manually enter university codes one by one in the \"Add Manually\" section",
    "deleteOption3": "Review the compiled list of students below.",
    "deleteOption4": "Click \"Delete Students\" to permanently remove them from the system",
    "deleteOption5": "Warning: This action cannot be undone",
    "importFromExcel": "Import From Excel",
    "uploadExcelHint": "Upload an Excel file with a column named \"university code\" or \"code\"",
    "clearBtn": "Clear",
    "uploadExcel": "Upload Excel",
    "addManually": "Add Manually",
    "enterCodeAndPressAdd": "Enter a university code and press Add",
    "addBtn": "Add",
    "bulkCreateStudents": "Bulk Create Students",
    "createMultipleStudents": "Create Multiple Students",
    "addStudentsBulkSubtitle": "Add students one by one or in bulk",
    "howToCreateStudents": "How to create students",
    "createOption1": "Option 1: Use \"Import from Excel\" to upload a .xlsx file with \"Name\", \"University Email\", and \"University Code\" columns",
    "createOption2": "Option 2: Use the manual \"Add Student\" form to add students one by one to the list below",
    "createOption3": "Review the \"Students to Add\" list below to ensure accuracy",
    "createOption4": "Click \"Create Students\" to finalize and send to the server",
    "uploadExcelCreateHint": "Upload an Excel file with columns: name, universityEmail, universityCode",
    "addStudentBtn": "Add Student",
    "scanQrCode": "Scan QR Code",
    "enterPinCode": "Enter PIN Code",
    "attendanceReports": "Attendance Reports"
}

new_keys_ar = {
    "doctorsList": "قائمة الأطباء",
    "teachingAssistantsList": "قائمة المعيدين",
    "doctorsCount": "{count} أطباء",
    "@doctorsCount": {"placeholders": {"count": {"type": "String"}}},
    "taCount": "{count} معيدين",
    "@taCount": {"placeholders": {"count": {"type": "String"}}},
    "autoRefresh30": "تحديث تلقائي كل 30 ثانية",
    "searchDoctors": "...ابحث عن الأطباء",
    "searchTAs": "...ابحث عن المعيدين",
    "passwordReqs": ":متطلبات كلمة المرور",
    "atLeast6Chars": "6 أحرف على الأقل",
    "bulkDeleteStudents": "حذف الطلاب دفعة واحدة",
    "howToDeleteStudents": "كيفية حذف الطلاب",
    "deleteOption1": "الخيار 1: استخدم \"استيراد من إكسل\" لرفع ملف .xlsx يحتوي على عمود \"كود الجامعة\"",
    "deleteOption2": "الخيار 2: أدخل أكواد الجامعة يدوياً واحداً تلو الآخر في قسم \"إضافة يدوياً\"",
    "deleteOption3": "راجع القائمة المجمعة للطلاب أدناه.",
    "deleteOption4": "انقر على \"حذف الطلاب\" لإزالتهم نهائياً من النظام",
    "deleteOption5": "تحذير: لا يمكن التراجع عن هذا الإجراء",
    "importFromExcel": "استيراد من إكسل",
    "uploadExcelHint": "قم برفع ملف إكسل يحتوي على عمود باسم \"university code\" أو \"code\"",
    "clearBtn": "مسح",
    "uploadExcel": "رفع ملف إكسل",
    "addManually": "إضافة يدوياً",
    "enterCodeAndPressAdd": "أدخل كود الجامعة واضغط إضافة",
    "addBtn": "إضافة",
    "bulkCreateStudents": "إنشاء طلاب دفعة واحدة",
    "createMultipleStudents": "إنشاء عدة طلاب",
    "addStudentsBulkSubtitle": "أضف الطلاب واحداً تلو الآخر أو دفعة واحدة",
    "howToCreateStudents": "كيفية إنشاء الطلاب",
    "createOption1": "الخيار 1: استخدم \"استيراد من إكسل\" لرفع ملف .xlsx يحتوي على أعمدة \"Name\"، \"University Email\"، و \"University Code\"",
    "createOption2": "الخيار 2: استخدم نموذج \"إضافة طالب\" اليدوي لإضافة الطلاب للقائمة أدناه",
    "createOption3": "راجع قائمة \"الطلاب المراد إضافتهم\" أدناه لضمان الدقة",
    "createOption4": "انقر على \"إنشاء الطلاب\" للإنهاء والإرسال للخادم",
    "uploadExcelCreateHint": "قم برفع ملف إكسل بأعمدة: name, universityEmail, universityCode",
    "addStudentBtn": "إضافة طالب",
    "scanQrCode": "مسح رمز QR",
    "enterPinCode": "إدخال كود PIN",
    "attendanceReports": "تقارير الحضور"
}

en_data.update(new_keys_en)
ar_data.update(new_keys_ar)

with open(en_file, 'w', encoding='utf-8') as f:
    json.dump(en_data, f, indent=2, ensure_ascii=False)
with open(ar_file, 'w', encoding='utf-8') as f:
    json.dump(ar_data, f, indent=2, ensure_ascii=False)

print("ARB files updated successfully!")
