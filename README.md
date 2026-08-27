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
