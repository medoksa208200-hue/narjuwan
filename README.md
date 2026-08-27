# Narjuwan Cloudflare Pages

حزمة Static جاهزة لـ GitHub وCloudflare Pages. لا تحتاج Node أو Express أو tRPC.

- `/index.html`: بوابة العملاء العامة.
- `/efragh/index.html`: بوابة الموظفين لنماذج الإفراغ.
- الاتصال بـ Supabase يتم بمفتاح Publishable فقط.
- عمليات الإفراغ الحساسة تمر عبر RPCs محمية بجلسة موظف مخزنة في Supabase.
- إجمالي قيمة الوحدة في الإفراغ مصدره الوحيد `units.final_price`.

## Cloudflare Pages
Framework preset: None
Build command: اتركه فارغًا
Output directory: جذر المستودع


## v3
Frontend now talks to the Supabase Edge Function `narjuwan-api` instead of calling PostgREST directly. This avoids browser API-key/header compatibility issues.


## تحديث الإفراغ
- رابط الفوتر الرسمي: targate.sa
- خيار تطبيق ضريبة التصرفات العقارية لكل نموذج قبل الإصدار.
- العرض المالي والمساحات بدون كسور عشرية، مع الإبقاء على بيانات المصدر الأصلية في قاعدة البيانات.


## V5 refinements
- One-page A4 print tuning for evacuation forms.
- Simplified signature blocks (role + signature line only).
- Saudi mobile validation: 10 digits, starts with 05, digits only.
- Professional date picker with automatic Umm al-Qura Hijri conversion in the browser.


## V6 updates
- Target logo is packaged locally in `assets/target-logo.png` so it prints reliably without depending on the remote GIF.
- The evacuation-form QR code is a real scannable QR and opens the selected unit directly in the public portal using `project`, `building`, and `unit` query parameters.
