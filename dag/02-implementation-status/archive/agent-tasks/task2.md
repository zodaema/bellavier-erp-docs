GOAL

เราต้องการ เพิ่ม debug log แบบอ่านง่าย รอบ ๆ ระบบ assign ช่าง เพื่อแยกแยะให้ชัดว่า:
	1.	ตอน assign token มันเจอ manager plan / assignment_plan_job / assignment_plan_node จริงหรือไม่
	2.	filterAvailable() ใช้ schema แบบไหนของ operator_availability (status / is_active / available หรือ unknown)

เป้าหมายคือ ถ้า log ขึ้นว่า
	•	No pre-assignment for node XXX in instance YYY → เราต้องรู้ให้ชัดว่ามันไม่เจอ plan จาก table ไหน
	•	[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available → ต้องเห็นว่า schema จริงมีคอลัมน์อะไรบ้าง

ห้ามเปลี่ยน behavior เดิม (soft mode):
	•	ห้าม throw exception ใหม่ใน AssignmentEngine
	•	ถ้า schema แปลก → ยังต้อง “assume all available” เหมือนเดิม
	•	เพิ่ม log อย่างเดียว ไม่ไป block assignment

⸻

FILE SCOPE

แก้เฉพาะไฟล์:
	•	source/BGERP/Service/AssignmentEngine.php

อย่าไปยุ่ง logic ในไฟล์อื่น (เช่น HatthasilpaAssignmentService, dag_token_api) นอกจากใช้เพื่ออ่าน context ถ้าจำเป็น

⸻

1) เพิ่ม DEBUG LOG รอบส่วน pre-assignment ใน assignOne()

ที่เมธอด:

private static function assignOne(\mysqli $db, int $tokenId, ?int $nodeId): void

1.1 Log context ตอนต้นฟังก์ชัน
ทันทีหลังจาก lock token และอ่าน $row ได้แล้ว (ก่อนเช็ค START node) ให้เพิ่ม log แบบนี้:

error_log(sprintf(
    '[AssignmentEngine] assignOne start: token_id=%d, node_id_param=%s, current_node_id=%s, instance_id=%s',
    $tokenId,
    $nodeId !== null ? (string)$nodeId : 'null',
    $row['current_node_id'] ?? 'null',
    $row['id_instance'] ?? 'null'
));

หลังจาก resolve $nodeId จาก current_node_id แล้ว ให้ log อีกรอบ:

error_log(sprintf(
    '[AssignmentEngine] assignOne resolved node: token_id=%d, node_id=%d',
    $tokenId,
    $nodeId
));

1.2 Log ตอน lookup job + instance
หลังจาก query $job = db_fetch_one(... job_graph_instance ...) แล้ว:

if ($job) {
    error_log(sprintf(
        '[AssignmentEngine] job context: token_id=%d, job_ticket_id=%s, graph_id=%s, instance_id=%s',
        $tokenId,
        $job['id_job_ticket'] ?? 'null',
        $job['id_graph'] ?? 'null',
        $job['id_instance'] ?? 'null'
    ));
} else {
    error_log(sprintf(
        '[AssignmentEngine] job context: token_id=%d has no job_graph_instance row',
        $tokenId
    ));
}

1.3 Log ระหว่าง MANAGER ASSIGNMENT
ใน block // 2a. Manager Assignment (from manager_assignment table):
	1.	ก่อนเรียก $assignmentService->findManagerAssignmentForToken(...) ให้ log parameter:

error_log(sprintf(
    '[AssignmentEngine] manager lookup: token_id=%d, job_ticket_id=%s, node_id=%d, node_code=%s',
    $tokenId,
    $job['id_job_ticket'] ?? 'null',
    $nodeId,
    $nodeCode ?? 'null'
));


	2.	หลังจากได้ $managerPlan แล้ว ใส่ log:

if ($managerPlan) {
    error_log(sprintf(
        '[AssignmentEngine] manager plan found: token_id=%d, assigned_to_user_id=%s, assigned_by_user_id=%s, method=%s',
        $tokenId,
        $managerPlan['assigned_to_user_id'] ?? 'null',
        $managerPlan['assigned_by_user_id'] ?? 'null',
        $managerPlan['assignment_method'] ?? 'null'
    ));
} else {
    error_log(sprintf(
        '[AssignmentEngine] manager plan not found for token_id=%d (job_ticket_id=%s, node_id=%d, node_code=%s)',
        $tokenId,
        $job['id_job_ticket'] ?? 'null',
        $nodeId,
        $nodeCode ?? 'null'
    ));
}


	3.	กรณี user ไม่เจอใน bgerp.account (ตอนนี้มี error_log อยู่แล้ว) ให้ถือว่าโอเค ไม่ต้องเพิ่ม
	4.	ใน catch (\Throwable $e) ที่ตอนนี้ log manager_lookup_error อยู่แล้ว ไม่ต้องเปลี่ยน behavior เพิ่มแค่ข้อมูลใน detail ถ้าจำเป็น (optional)

1.4 Log ระหว่าง JOB PLAN / NODE PLAN
หลัง query assignment_plan_job:

$planJob = db_fetch_all(...);

error_log(sprintf(
    '[AssignmentEngine] job_plan query: token_id=%d, job_ticket_id=%s, node_id=%d, rows=%d',
    $tokenId,
    $job['id_job_ticket'] ?? 'null',
    $nodeId,
    is_array($planJob) ? count($planJob) : 0
));

ถ้า $planJob มีค่า → ก่อน expandAssignees() ให้ log รายการคร่าว ๆ:

if ($planJob) {
    $debugSample = array_slice($planJob, 0, 3);
    error_log('[AssignmentEngine] job_plan sample: ' . json_encode($debugSample, JSON_UNESCAPED_UNICODE));
}

หลัง expandAssignees():

if ($candidates) {
    error_log(sprintf(
        '[AssignmentEngine] job_plan candidates: token_id=%d, node_id=%d, candidates=%s',
        $tokenId,
        $nodeId,
        json_encode($candidates)
    ));
}

ในฝั่ง NODE PLAN (fallback) ทำเหมือนกัน:
	•	log count ของ $planNode
	•	log sample rows
	•	log candidate list หลัง expandAssignees()

1.5 Log จุด No pre-assignment ...
ตรง block:

if (!$candidates && !$hadPlan) {
    $instanceId = $job['id_instance'] ?? ($row['id_instance'] ?? null);
    error_log(sprintf(
        '[hatthasilpa_assignment] No pre-assignment for instance %s, node %d (soft mode - skip auto-assign)',
        $instanceId ?? 'unknown',
        $nodeId
    ));
    ...
}

ให้เพิ่ม log ก่อน error_log เดิม เพื่อเห็นภาพรวม:

error_log(sprintf(
    '[AssignmentEngine] no_plan_summary: token_id=%d, node_id=%d, hadPlan=%s, managerPlan=%s, jobPlanRows=%d, nodePlanRows=%d',
    $tokenId,
    $nodeId,
    $hadPlan ? 'true' : 'false',
    isset($managerPlan) && $managerPlan ? 'true' : 'false',
    isset($planJob) && is_array($planJob) ? count($planJob) : 0,
    isset($planNode) && is_array($planNode) ? count($planNode) : 0
));

หมายเหตุ: ดูให้แน่ใจว่าใช้ตัวแปรที่ประกาศแล้วเท่านั้น (เช่น $managerPlan, $planJob, $planNode) ถ้าตัวใดอาจไม่มีใน scope ให้ initialize ไว้ก่อนใช้งาน เช่น
 $managerPlan = null; $planJob = []; $planNode = [];
เมื่อเริ่ม block if ($job) { ... }

⸻

2) เพิ่ม DEBUG LOG ใน filterAvailable() เพื่อตรวจ schema operator_availability

ในเมธอด:

private static function filterAvailable(\mysqli $db, array $ids): array

ตอนนี้มี logic เช็ค 3 schema กับ fallback unknown แล้ว ให้:

2.1 Log รายละเอียด columns จริง
หลังจาก SHOW COLUMNS FROM operator_availability loop เสร็จแล้ว ให้เพิ่ม:

error_log(sprintf(
    '[AssignmentEngine] filterAvailable schema detected: hasIsActive=%s, hasStatus=%s, hasAvailable=%s, idColumn=%s',
    $hasIsActive ? 'true' : 'false',
    $hasStatus ? 'true' : 'false',
    $hasAvailable ? 'true' : 'false',
    $idColumn
));

(อย่าลืมว่า $idColumn มี default 'id_member' และอาจถูกเปลี่ยนเป็น 'operator_id')

2.2 Log branch ที่เลือกใช้
	•	ใน if ($hasIsActive) { ... } ให้เพิ่ม:

error_log('[AssignmentEngine] filterAvailable: using schema=is_active with idColumn=' . $idColumn);


	•	ใน elseif ($hasStatus) { ... }:

error_log('[AssignmentEngine] filterAvailable: using schema=status/date with idColumn=' . $idColumn);


	•	ใน elseif ($hasAvailable) { ... }:

error_log('[AssignmentEngine] filterAvailable: using schema=available with idColumn=' . $idColumn);


	•	ใน else { ... } (unknown schema) ให้เสริมข้อมูล columns:

error_log('[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available');

ถ้าอยากละเอียดขึ้น (optional) สามารถ query อีกรอบ:

$colsResult = $db->query("SHOW COLUMNS FROM operator_availability");
$colNames = [];
if ($colsResult) {
    while ($col = $colsResult->fetch_assoc()) {
        $colNames[] = $col['Field'] ?? '';
    }
    $colsResult->free();
}
error_log('[AssignmentEngine] filterAvailable: operator_availability columns = ' . json_encode($colNames));



2.3 Log ขนาด input/output (แต่ไม่ต้อง log รายชื่อทั้งหมด)
ต้นฟังก์ชัน filterAvailable() หลังเช็ค $ids ว่าไม่ว่าง:

error_log(sprintf(
    '[AssignmentEngine] filterAvailable called: candidate_count=%d',
    count($ids)
));

ตอนท้ายก่อน return $out ?: $ids;:

error_log(sprintf(
    '[AssignmentEngine] filterAvailable result: input=%d, available=%d',
    count($ids),
    $out ? count($out) : count($ids)
));

ใน branch unknown schema (fail-open) ตอน return $ids; จะถือว่า “available = input” อยู่แล้ว

⸻

3) ข้อจำกัดสำคัญ (อย่าทำผิด)
	1.	ห้ามเปลี่ยน logic การตัดสินใจ assignment
	•	ห้ามเปลี่ยนค่า return ของ assignOne() หรือ filterAvailable() ยกเว้นในกรณีที่ตอนนี้เขียนผิดจริง ๆ
	•	ห้ามเปลี่ยน fallback “unknown schema → assume all available”
	2.	ห้ามโยน exception ใหม่ใน AssignmentEngine
	•	ทุกอย่างต้อง soft mode เหมือนเดิม: ใช้ error_log() + logDecision() เท่านั้น
	3.	อย่าลืม run tests เดิมที่เกี่ยวข้อง
	•	vendor/bin/phpunit tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php --testdox --verbose
	•	vendor/bin/phpunit tests/Integration/HatthasilpaE2E_CancelRestartSpawnTest.php --testdox --verbose
	•	และ test suite ที่เคยใช้ confirm AssignmentEngine (ถ้ามี)
	4.	อย่าทำให้ log noisy เกินไปใน production:
	•	ยังไม่ต้องใส่ feature flag สำหรับ log ตอนนี้ (เราใช้ใน dev/staging)
	•	แต่อย่าพิมพ์รายการ member ids ทั้งหมดลง log (ใช้แค่ count หรือ sample บางส่วนก็พอ)

⸻

4) Output ที่ต้องการจากคุณ (Agent)
	1.	แก้ไขไฟล์ source/BGERP/Service/AssignmentEngine.php ตามข้อ 1–2
	2.	แสดง diff ที่ชัดเจนของไฟล์นี้
	3.	รัน PHPUnit tests ที่เกี่ยวข้อง และสรุปผล
	4.	สรุปให้ว่า:
	•	รับรองว่า log Unknown column 'is_active' จะไม่กลับมาอีก
	•	ตอนนี้จะสามารถแยกแยะได้ชัดว่า:
	•	ตอนที่ขึ้น No pre-assignment for node ... → มีหรือไม่มี manager plan / assignment_plan_job / assignment_plan_node จริง ๆ
	•	filterAvailable() ใช้ schema อะไรจาก operator_availability