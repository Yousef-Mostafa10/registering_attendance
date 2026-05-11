import json

en_file = 'lib/l10n/app_en.arb'
ar_file = 'lib/l10n/app_ar.arb'

en_data = json.load(open(en_file, 'r', encoding='utf-8'))
ar_data = json.load(open(ar_file, 'r', encoding='utf-8'))

new_keys_en = {
    "totalStats": "Total",
    "absentStats": "Absent",
    "attendedStats": "Attended",
    "dangerAbsenceLimit": "Danger: You have exceeded the allowed absence limit (3) and may be deprived of exams",
    "sectionsTab": "Sections",
    "lecturesTab": "Lectures",
    "registerAttendance": "Register Attendance",
    "activeSession": "Active Session",
    "activeSessionOpen": "An active session is open!",
    "enterPinDescription": "Please enter the 4-digit PIN provided by the Doctor to register your attendance",
    "enterPinTitle": "Enter PIN",
    "pinCodeLabel": "PIN Code",
    "submitPinBtn": "Submit PIN"
}

new_keys_ar = {
    "totalStats": "الإجمالي",
    "absentStats": "غياب",
    "attendedStats": "حضور",
    "dangerAbsenceLimit": "خطر: لقد تجاوزت الحد المسموح للغياب (3) وقد تُحرم من الامتحانات",
    "sectionsTab": "سكاشن",
    "lecturesTab": "محاضرات",
    "registerAttendance": "تسجيل الحضور",
    "activeSession": "الجلسة النشطة",
    "activeSessionOpen": "!توجد جلسة نشطة الآن",
    "enterPinDescription": "يرجى إدخال رمز الـ PIN المكون من 4 أرقام المقدم من الدكتور لتسجيل حضورك",
    "enterPinTitle": "إدخال رمز PIN",
    "pinCodeLabel": "رمز PIN",
    "submitPinBtn": "إرسال رمز PIN"
}

en_data.update(new_keys_en)
ar_data.update(new_keys_ar)

with open(en_file, 'w', encoding='utf-8') as f:
    json.dump(en_data, f, indent=2, ensure_ascii=False)
with open(ar_file, 'w', encoding='utf-8') as f:
    json.dump(ar_data, f, indent=2, ensure_ascii=False)

print("ARB files updated successfully!")
