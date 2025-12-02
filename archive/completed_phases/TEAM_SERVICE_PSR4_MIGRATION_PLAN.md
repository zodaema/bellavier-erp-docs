# Team Service PSR-4 Migration Plan

## Executive Summary
- Team-related services (`TeamExpansionService`, `TeamService`, `TeamMemberService`) ถูกย้ายไปอยู่ภายใต้ `source/BGERP/Service/` แล้ว โดยเหลือไฟล์ shim ใน `source/service/` เพื่อความเข้ากันได้ย้อนหลัง
- Composer autoload (`BGERP\` → `source/BGERP/`) จึงสามารถโหลดบริการเหล่านี้ได้โดยไม่ต้อง `require_once` manual อีกต่อไป
- API หลัก (`team_api.php`, `assignment_api.php`) และชุดทดสอบถูกปรับให้พึ่ง autoload แล้ว เหลืองานอัปเดตเอกสารและ regression test ครบชุดเพื่อปิดเฟส

## Scope & Impact Analysis
| หมวด | รายละเอียด |
| --- | --- |
| บริการหลัก | `source/BGERP/Service/TeamExpansionService.php`, `source/BGERP/Service/TeamService.php`, `source/BGERP/Service/TeamMemberService.php` (พร้อม shim ใน `source/service/`) |
| API/หน้า UI ที่ใช้ | `source/team_api.php`, `source/assignment_api.php`, `assets/javascripts/team/*.js`, `assets/javascripts/manager/assignment.js` (อาศัย API) |
| ทดสอบที่เกี่ยวข้อง | `tests/phase2/TeamExpansionServiceTest.php`, `tests/Service/TeamServiceTest.php`, Integration tests ของ assignment/token plan |
| เอกสาร/สคริปต์ | `docs/PHASE2_*`, `PHASE3.5_MANAGER_ASSIGNMENT_ENHANCEMENT.md`, CLI/plan docs ที่อ้าง path เดิม |

### Inventory Snapshot (Nov 7, 2025)
- `source/BGERP/Service/TeamExpansionService.php` → เก็บโค้ดหลักเต็มรูปแบบ; `source/service/TeamExpansionService.php` เหลือเพียง shim `class_alias`
- `source/service/TeamService.php`, `TeamMemberService.php`, `TeamWorkloadService.php` → shim (class_alias) ชี้ไปยัง PSR-4 service แล้ว
- `team_api.php` → ตัด `require_once` team services+DataService ออก เรียกผ่าน autoload
- `assignment_api.php` → ไม่ต้อง require manual `TeamExpansionService.php` อีกต่อไป
- `tests/phase2/TeamExpansionServiceTest.php` → ใช้ `vendor/autoload.php` แล้ว ไม่ include path เก่า
- เอกสาร `docs/PHASE2_DEPLOYMENT_GUIDE.md`, `PHASE2_TEAM_INTEGRATION_DETAILED_PLAN.md` ยังมีตัวอย่าง path เก่า (ต้องอัปเดตใน Phase 3)
- Composer autoload (`composer.json`) ใช้งานได้ตามปกติ (ต้องรัน `composer dump-autoload` หลัง merge)

### ความเสี่ยงจากการไม่แก้ไข
| Risk ID | คำอธิบาย | Likelihood | Impact | Note |
| --- | --- | --- | --- | --- |
| R1 | Feature ใหม่เรียกใช้ service ผ่าน autoload (ไม่ require manual) → Fatal `Class not found` | Medium | High | มีแนวโน้มสูงเมื่อ refactor ต่อ |
| R2 | ทีมงานสับสน path ทำให้ duplicate ไฟล์หรือแก้ไขไฟล์ผิดโฟลเดอร์ | Medium | Medium | พบมาแล้วใน Phase 3.5 |
| R3 | ทดสอบภายนอก (เช่น CLI, PHPUnit) ล้มเหลวเมื่อรันด้วย autoload-only | Low | High | โดยเฉพาะถ้า `require_once` ถูกลบในการรีแฟกเตอร์ |
| R4 | เอกสาร deployment/guide ชี้ path เก่า ทำให้ทีมปฏิบัติตามผิด | Medium | Medium | ต้องอัปเดตคู่มือ |

## Remediation Plan (3 Phases)

### Phase 1 – Inventory & Preparation (0.5 วัน)
1. สำรวจไฟล์ภายใต้ `source/service/` ที่ประกาศ namespace `BGERP\Service`
2. ทำรายการ API/CLI/Tests ที่ `require_once` เส้นทางเก่า
3. เตรียม branch + ตั้ง test baseline (`vendor/bin/phpunit --testdox`)

### Phase 2 – Migration & Code Update (1–1.5 วัน)
1. ย้ายไฟล์บริการไปยัง `source/BGERP/Service/`
2. ลบไฟล์ shim (`source/service/*.php`) หรือเปลี่ยนเป็นไฟล์บางๆ ที่ `class_alias` เฉพาะกรณีจำเป็น (ระบุใน CHANGELOG)
3. ปรับทุกไฟล์ให้พึ่ง autoload → ลบ `require_once __DIR__ . '/service/...';`
4. ปรับ tests (`tests/phase2/TeamExpansionServiceTest.php`) ให้โหลดผ่าน autoload (เพิ่ม `require_once vendor/autoload.php` ถ้าจำเป็น)
5. รัน `composer dump-autoload`

### Phase 3 – Validation & Documentation (0.5 วัน)
1. รันชุดทดสอบเต็ม (`vendor/bin/phpunit --testdox`)
2. Smoke test UI: `team_management`, `manager_assignment`, `token_management`
3. อัปเดตเอกสาร: `docs/PHASE2_DEPLOYMENT_GUIDE.md`, `PHASE3.5_MANAGER_ASSIGNMENT_ENHANCEMENT.md`, `STATUS.md`, `docs/INDEX.md`
4. เพิ่ม Release note ใน `CHANGELOG_NOV2025.md`

## Checklist ก่อนเริ่มงาน
- [ ] อ่าน `IMPLEMENTATION_CHECKLIST.md`, `docs/FUTURE_AI_CONTEXT.md`, `QUICK_REFERENCE_WORK_QUEUE.md`
- [ ] สำรอง branch หรือสร้าง branch ใหม่
- [ ] ประสานกับทีม QA สำหรับ regression หลัง migration

## Checklist หลังเสร็จงาน
- [ ] ทดสอบ API: `team_api.php?action=list_with_stats`, `assignment_api.php?action=assign_tokens`
- [ ] ทดสอบ CLI/Tests ที่อ้าง service เดิม (`tests/phase2/run_all_tests.php`)
- [ ] ตรวจ `error_log` เพื่อหา autoload failure
- [ ] อัปเดต `docs/INDEX.md`
- [ ] แจ้งทีมผ่าน release notes/Internal comms

## Appendix – ไฟล์ที่ต้องรีวิวเพิ่มเติม
- `source/team_api.php`: ✅ ลบ `require_once` team services แล้ว (ใช้ autoload) – ตรวจ regression ต่อเนื่อง
- `source/assignment_api.php`: ✅ ปรับเป็น autoload แล้ว
- `tests/phase2/TeamExpansionServiceTest.php`: ✅ ใช้ `vendor/autoload.php`
- เอกสาร `docs/PHASE2_*`: ❗ ยังมีตัวอย่าง `require_once 'source/service/TeamExpansionService.php'` ต้องอัปเดตใน Phase 3


