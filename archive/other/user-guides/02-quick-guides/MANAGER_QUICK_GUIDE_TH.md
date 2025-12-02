# คู่มือใช้งานเร็ว - สำหรับผู้จัดการ

**ฉบับที่:** 1.0  
**วันที่:** 4 พฤศจิกายน 2025  
**สำหรับ:** ผู้จัดการ, หัวหน้างาน (Managers)

---

## 💼 **ระบบที่ใช้:**

### **1. Work Queue (สำหรับดูภาพรวม)**
```
URL: http://bellavier-erp/?p=work_queue
Device: Desktop/Tablet
Purpose: ดูงานทั้งหมด, เช็ค status
```

### **2. Manager Dashboard (สำหรับมอบหมายงาน)**
```
URL: http://bellavier-erp/?p=manager_dashboard
Device: Desktop/Tablet  
Purpose: Assign งานให้ช่าง
```

---

## 🎯 **Workflow ประจำวัน**

### **เช้า (08:00):**
```
1. เปิด Manager Dashboard
   ↓
2. เห็นงาน: 50 tokens รอทำ
   ├─ Cutting: 20 tokens
   ├─ Sewing: 15 tokens
   └─ Assembly: 15 tokens
   ↓
3. เช็คทีม: ช่าง 5 คนออนไลน์
   ├─ สมชาย (Cutting specialist) - 0 งาน
   ├─ สมหญิง (Sewing specialist) - 0 งาน
   └─ ...
   ↓
4. Assign งาน:
   ┌─────────────────────────────┐
   │ Drag token → Drop on ช่าง  │
   └─────────────────────────────┘
   
   หรือ:
   
   ┌─────────────────────────────┐
   │ Select 10 tokens            │
   │ Choose: สมชาย              │
   │ [Assign]                    │
   └─────────────────────────────┘
   
5. ✅ ช่างได้รับแจ้งบนมือถือ
```

---

## 📊 **การมอบหมายงาน (Assignment)**

### **แบบที่ 1: Drag & Drop (ง่ายที่สุด)**
```
1. เลือก token (คลิกที่การ์ด)
2. Drag ไปวาง บนช่าง
3. ✅ Assigned!

ใช้เวลา: 5 วินาที/token
```

### **แบบที่ 2: Bulk Assignment (เร็วที่สุด)**
```
1. เลือกหลาย tokens (Checkbox)
2. เลือกช่าง (Dropdown)
3. กด [Assign Selected]
4. ✅ Assigned!

ใช้เวลา: 1 นาที สำหรับ 10 tokens
```

### **แบบที่ 3: Smart Assignment (อัตโนมัติ)**
```
1. กด [Auto Assign]
2. ระบบจะ:
   - ดู skill ของช่าง
   - ดู workload ปัจจุบัน
   - แบ่งงานอัตโนมัติ
3. ✅ Done!

ใช้เวลา: 10 วินาที สำหรับ 50 tokens
```

---

## 👀 **การติดตามงาน (Monitoring)**

### **Real-time Status:**
```
Work Queue แสดง:

┌─────────────────────────────────┐
│ งานที่มอบหมายแล้ว (30)         │
├─────────────────────────────────┤
│ 👷 สมชาย (10 tokens)           │
│ ├─ Active: 1 (กำลังทำ)         │
│ ├─ Completed: 5 (เสร็จแล้ว)    │
│ └─ Pending: 4 (รอทำ)           │
│                                  │
│ 👷 สมหญิง (15 tokens)          │
│ ├─ Active: 2 (กำลังทำ)         │
│ ├─ Completed: 8 (เสร็จแล้ว)    │
│ └─ Pending: 5 (รอทำ)           │
│                                  │
│ งานที่ยังไม่ได้มอบหมาย (20)    │
└─────────────────────────────────┘
```

### **Performance Dashboard:**
```
วันนี้:
- ทั้งหมด: 100 tokens
- เสร็จแล้ว: 45 (45%)
- กำลังทำ: 10 (10%)
- รออยู่: 45 (45%)

ช่างที่เร็วที่สุด: สมชาย (15 tokens/วัน)
ช่างที่ช้าที่สุด: สมศักดิ์ (8 tokens/วัน)
```

---

## 🔄 **การ Reassign (มอบหมายใหม่)**

### **เมื่อไร:**
```
- ช่างลาป่วย
- ช่างทำไม่ทัน
- Load balancing
```

### **วิธีการ:**
```
1. เปิด Manager Dashboard
2. เห็น: สมชาย (10 tokens รอทำ)
3. Select tokens ที่ยังไม่เริ่ม (Pending)
4. กด [Reassign]
5. เลือกช่างคนใหม่
6. ✅ Done!

ช่างเก่า: แจ้งเตือน "งานถูกยกเลิก"
ช่างใหม่: แจ้งเตือน "คุณได้รับงานใหม่"
```

---

## 📈 **การตั้งค่า Priority**

### **ระดับความสำคัญ:**
```
🔴 Urgent (ด่วนมาก)
   - งานที่ต้องส่งวันนี้
   - ลูกค้า VIP
   
🟠 High (สำคัญ)
   - งานที่ต้องส่งใน 2-3 วัน
   - Order ใหญ่
   
🟢 Normal (ปกติ)
   - งานทั่วไป
   - ตามลำดับ
   
🔵 Low (ไม่เร่งด่วน)
   - งาน stock
   - เตรียมล่วงหน้า
```

### **วิธีตั้ง:**
```
1. Select tokens
2. เลือก Priority: Urgent/High/Normal/Low
3. Assign
4. ✅ ช่างจะเห็น badge สี (เรียงตาม priority)
```

---

## 🚨 **แก้ไขปัญหา**

### **ปัญหา: ช่างบอกว่า "ไม่เห็นงาน"**
```
เช็ค:
1. ช่าง login ถูก tenant หรือไม่?
2. งานถูก assign ให้ช่างคนนี้หรือยัง?
3. ช่างกด Refresh หรือยัง?

แก้ไข:
- Reassign ใหม่
- ให้ช่าง Refresh PWA
```

### **ปัญหา: งานหาย**
```
เช็ค:
1. ดู Work Queue → งานอยู่ไหน?
2. เช็ค status: Completed? Cancelled?
3. เช็ค history: ใครทำไปแล้ว?

แก้ไข:
- Unassign ถ้าจำเป็น
- Re-create tokens ถ้าผิดพลาด
```

### **ปัญหา: ช่างทำช้า**
```
เช็ค:
1. เปิด Dashboard → เห็น work time
2. สมชาย: Started 2 hours ago, Paused 5 times
3. เช็ค: Pause เยอะไปหรือเปล่า?

Action:
- พูดคุยกับช่าง
- Reassign ถ้าจำเป็น
- ปรับ target time
```

---

## 📊 **รายงาน (Reports)**

### **รายงานประจำวัน:**
```
Dashboard → Daily Report

แสดง:
- ช่างแต่ละคนทำได้กี่ชิ้น
- เวลาเฉลี่ย/ชิ้น
- Pause time
- Efficiency score
```

### **รายงานประจำสัปดาห์:**
```
Dashboard → Weekly Report

แสดง:
- Production output
- Top performers
- Bottlenecks (ขั้นตอนที่ช้า)
- Recommendations
```

---

## 💡 **Best Practices**

### **1. Assign ตอนเช้า**
```
✅ Assign งานทั้งวันตั้งแต่เช้า
✅ ช่างรู้ว่าต้องทำอะไรบ้าง
✅ Plan ได้ดีกว่า
```

### **2. Load Balancing**
```
✅ แบ่งงานเท่าๆ กัน
✅ ดู skill ของแต่ละคน
✅ ไม่ให้คนเดียวงานเยอะเกินไป
```

### **3. Priority ชัดเจน**
```
✅ ตั้ง priority ให้ถูกต้อง
✅ Urgent = ทำก่อน
✅ ช่างรู้ว่าอะไรสำคัญ
```

### **4. Monitor อย่างสม่ำเสมอ**
```
✅ เช็คทุก 1-2 ชั่วโมง
✅ แก้ปัญหาทันที
✅ Re-assign ถ้า bottleneck
```

---

## 🎯 **เป้าหมายที่ดี**

```
ช่าง 1 คน:
- เป้า: 20-30 tokens/วัน (ขึ้นอยู่กับความซับซ้อน)
- Pause time: < 20% ของเวลาทำงาน
- Quality: 95%+ QC pass rate

ทีมทั้งหมด (5 คน):
- เป้า: 100-150 tokens/วัน
- On-time delivery: > 90%
- Customer satisfaction: > 95%
```

---

## 🎓 **Training สำหรับทีม**

### **ระยะเวลา:**
```
Manager: 30-45 นาที
Operators: 15-30 นาที
Total: 1-2 ชั่วโมง
```

### **หัวข้อ:**
```
For Managers:
1. Dashboard overview (10 นาที)
2. Assignment workflow (15 นาที)
3. Monitoring (10 นาที)
4. Q&A (10 นาที)

For Operators:
1. PWA overview (5 นาที)
2. Start/Pause/Complete (10 นาที)
3. Assigned work (5 นาที)
4. Practice (10 นาที)
```

---

**เวลาฝึกอบรม:** 30-45 นาที  
**ความยาก:** ⭐⭐⭐ (ปานกลาง)  
**แนะนำ:** ฝึก hands-on ก่อนใช้จริง!

