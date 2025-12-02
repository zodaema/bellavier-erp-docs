# 📖 Bellavier ERP - User Manual

**Version:** 2.0  
**Last Updated:** October 30, 2025  
**For:** Production Floor & Office Users

---

## 🎯 **Getting Started**

### **What is Bellavier ERP?**

Bellavier ERP is a manufacturing management system designed for leather goods production. It helps you:
- ✅ Plan production jobs
- ✅ Track work progress in real-time
- ✅ Manage multiple operators
- ✅ Ensure quality control
- ✅ Monitor performance

---

### **Logging In**

1. Navigate to: `http://your-domain.com/bellavier-group-erp/`
2. Enter your **username** and **password**
3. Click **Login**

**First Time?**
- Contact your administrator for credentials
- Default admin: `admin` / (contact IT for password)

---

## 📋 **Job Tickets Overview**

### **What is a Job Ticket?**

A **Job Ticket** represents a production batch:
- **Job Name:** What you're making (e.g., "Leather Tote")
- **Target Qty:** How many pieces to produce
- **Due Date:** When it needs to be finished
- **Status:** Current state (Planned → In Progress → QC → Completed)

### **Navigating to Job Tickets**

1. Click **"Atelier"** in left sidebar
2. Click **"Job Tickets"**
3. You'll see a list of all current production jobs

---

## ✨ **Creating a Job Ticket**

### **Method 1: From Manufacturing Order (MO)**

1. Click **"+ New Ticket"** button
2. Select **MO** from dropdown
   - System shows remaining quantity
   - Cannot exceed MO quantity
3. Enter **Quantity** to produce
4. Click **Save**

### **Method 2: From Scratch**

1. Click **"+ New Ticket"**
2. Enter **Job Name**
3. Select **Product/SKU** (optional)
4. Enter **Target Quantity**
5. Select **Process Mode:**
   - **Piece:** Count individual items (e.g., 100 bags)
   - **Batch:** Single batch (e.g., 1 dye lot)
6. Set **Due Date** (optional)
7. Click **Save**

---

## 📝 **Managing Tasks**

### **What are Tasks?**

Tasks are individual work steps within a job:
- **Cutting** → **Sewing** → **Finishing** → **QC** → **Packing**

### **Adding Tasks**

**Option A: Manual Entry**
1. Click on a job ticket (opens detail panel)
2. Scroll to **"Tasks"** section
3. Click **"+ Add Task"**
4. Enter:
   - **Task Name** (e.g., "Cutting leather")
   - **Sequence** (order: 1, 2, 3...)
   - **Assigned To** (select operator)
   - **Depends On** (previous task that must finish first)
   - **Estimated Hours** (optional)
5. Click **Save**

**Option B: Import from Routing**
1. Click **"Import Routing"** button
2. System loads standard steps for this product
3. Select steps to import
4. Click **Import**
5. Tasks created automatically!

---

## 🔨 **Recording Work (WIP Logs)**

### **Understanding WIP Logs**

**WIP (Work In Progress) Logs** track what's happening on the floor:
- When operators start/stop work
- How much they've completed
- Any issues or notes

### **Adding a WIP Log (Desktop)**

1. Open job ticket detail panel
2. Scroll to **"WIP Logs"** section
3. Click **"+ Add Log"**
4. Fill in:
   - **Task:** Which step (if specific)
   - **Event Type:** What happened
     - **Start:** Beginning work
     - **Hold:** Pausing/lunch break
     - **Resume:** Back from pause
     - **Complete:** Finished quantity
     - **Fail:** Found defect
   - **Quantity:** How many (for Complete events)
   - **Operator:** Who did the work
   - **Notes:** Any comments
5. Click **Save**

**Result:** Progress updates automatically!

---

### **Recording Work (Mobile)**

**For operators on production floor:**

1. Open **Mobile WIP** app on phone/tablet
2. **Scan QR code** on job ticket (or select from list)
3. Select **Task**
4. Select **Event:**
   - 🟢 Start Work
   - ⏸️ Pause
   - ▶️ Resume
   - ✅ Complete
   - ⚠️ Report Defect
5. Enter **Quantity** (if completing)
6. Click **Submit**

**Benefits:**
- ✅ No need to walk to office computer
- ✅ Instant progress updates
- ✅ Real-time tracking
- ✅ Works offline (syncs when online)

---

### **Recording Work (PWA Scan Station)**

**For quick scanning:**

1. Open **Scan Station** on dedicated device
2. **Scan job ticket QR code**
3. **Quick Mode:** Tap action button
   - 🟢 Start
   - ⏸️ Hold
   - ▶️ Resume
   - ✅ Complete (enter qty)
   - ⚠️ Report Defect
4. Done!

**Detail Mode:** For more control
- Select specific task
- Choose event type
- Add notes

---

## 📊 **Understanding Progress**

### **How Progress is Calculated**

Progress is **AUTO-CALCULATED** based on completed work:

```
Progress % = (Completed Quantity / Target Quantity) × 100
```

**Example:**
- Target: 100 pieces
- Completed: 45 pieces
- Progress: 45.0%

### **Multiple Operators**

When multiple people work on same task:
- Each operator's work is tracked separately
- System sums all completed work
- Progress reflects total from all operators

**Example:**
- Operator A completes: 30 pieces
- Operator B completes: 25 pieces
- Total progress: 55% (55 out of 100)

### **Why Can't I Edit Progress Manually?**

Progress is **derived data** (calculated from work logs).

**Benefits:**
- ✅ Always accurate
- ✅ Can't be accidentally changed
- ✅ Audit trail of all work
- ✅ Supports multiple operators

**If progress seems wrong:**
- Click **"🔄 Recalculate"** button in WIP Logs section
- System will rebuild from all work logs

---

## 👥 **Assigning Operators**

### **To Assign a Task:**

1. Open task (click edit icon)
2. Select **"Assigned To"** from dropdown
   - Shows all active users
3. Click **Save**

**Assignment Benefits:**
- Clear responsibility
- Performance tracking
- Workload visibility

---

## 🔗 **Task Dependencies**

### **What are Dependencies?**

Some tasks must wait for others to finish:
- Can't sew before cutting
- Can't pack before QC

### **Setting Dependencies:**

1. Edit task
2. Select **"Depends On"** (previous task)
3. Save

**System enforces:**
- Can't start task B until task A is done
- Progress indicators show blocked tasks
- Workflow follows defined sequence

---

## ⚠️ **Reporting Quality Issues**

### **Desktop:**

1. Add WIP Log
2. Select **Event: Fail**
3. Enter **Quantity** affected
4. Add **Notes** (what's wrong)
5. Save

**System automatically:**
- Creates QC fail event
- Notifies QC team
- Updates ticket status to "Rework"

### **Mobile:**

1. Select task
2. Tap **"Report Defect"**
3. Take photo of issue (optional)
4. Enter quantity and description
5. Submit

---

## 📈 **Viewing Progress**

### **Dashboard View:**

Navigate to **Dashboard** to see:
- 📊 Today's production
- 📈 WIP by status
- ⚠️ Overdue tickets
- ✅ Completed this week

### **Ticket Detail View:**

Open any ticket to see:
- Overall progress bar
- Task-by-task progress
- Who's working on what
- Recent WIP logs
- Timeline of events

---

## 🔍 **Common Tasks**

### **Find a Specific Job**

**By Ticket Code:**
1. Use search box at top of table
2. Type ticket code (e.g., "JT251030001")
3. Press Enter

**By Job Name:**
1. Type job name in search
2. Results filter automatically

**By Status:**
1. Click status filter dropdown
2. Select status (e.g., "In Progress")

---

### **Check Who's Working on What**

1. Go to Job Tickets
2. Click on ticket
3. View **Tasks** section
4. **"Assigned To"** column shows operator
5. **Progress** column shows completion %

---

### **See Work History**

1. Open job ticket
2. Scroll to **"WIP Logs"** section
3. See all recorded events:
   - Who did what
   - When
   - How much
   - Any notes

**Filter by:**
- Date range
- Event type
- Operator
- Task

---

## ❓ **Troubleshooting**

### **"Progress seems wrong"**

**Solution:**
1. Open job ticket detail
2. Click **"🔄 Recalculate"** button
3. System recalculates from all work logs
4. Progress updates

**Why it happens:**
- Rare database sync issue
- After bulk data updates

---

### **"Can't start a task"**

**Possible reasons:**
1. **Task has dependency** → Previous task not finished
2. **No permission** → Contact administrator
3. **Task already completed** → Check status

---

### **"Can't find my work logs"**

**Check:**
1. Correct job ticket selected?
2. Date filter not too narrow?
3. Logs might be in different task

**Still missing?** Contact supervisor

---

### **"Error when saving"**

**Common validation errors:**
- **"Quantity exceeds target"** → Check remaining qty
- **"Task name required"** → Fill in all required fields
- **"Invalid event type"** → Select from dropdown

**Other errors:**
- Take screenshot of error message
- Contact IT support
- Include job ticket code

---

## 💡 **Tips & Best Practices**

### **For Operators:**

1. **Log work as it happens** (don't wait until end of day)
2. **Use mobile app** for convenience
3. **Be accurate with quantities**
4. **Report defects immediately**
5. **Add notes** for context (helps team)

### **For Supervisors:**

1. **Assign tasks** to balance workload
2. **Monitor progress** throughout day
3. **Review WIP logs** for bottlenecks
4. **Use dashboard** for overview
5. **Export reports** for meetings

### **For Planners:**

1. **Set realistic due dates**
2. **Import routings** to save time
3. **Link to MOs** for traceability
4. **Use dependencies** for complex workflows
5. **Review completed tickets** for estimating future jobs

---

## 📞 **Getting Help**

**Technical Issues:**
- Email: it@bellaviergroup.com
- Internal: #tech-support Slack channel

**Training:**
- Watch tutorial videos (coming soon)
- Attend weekly training sessions
- Ask your supervisor

**Feature Requests:**
- Submit via feedback form
- Discuss at monthly user group meetings

---

## 🎓 **Quick Reference**

| Task | Steps |
|------|-------|
| **Create Ticket** | + New Ticket → Fill form → Save |
| **Add Task** | Open ticket → + Add Task → Fill → Save |
| **Record Work** | + Add Log → Select event → Enter qty → Save |
| **Assign Operator** | Edit task → Select "Assigned To" → Save |
| **Check Progress** | Open ticket → View progress bars |
| **Report Defect** | + Add Log → Event: Fail → Details → Save |
| **Recalculate** | Open ticket → Scroll to WIP Logs → Click 🔄 |

---

**Need more help?** Check `docs/guide/TROUBLESHOOTING_GUIDE.md` or contact support!

---

*User Manual v2.0*  
*For Bellavier ERP Job Ticket System*  
*October 2025*

