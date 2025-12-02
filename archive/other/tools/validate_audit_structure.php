<?php
/**
 * Validate audit document structure:
 * - Skeleton section must appear first.
 * - Any "Full ... Audit - End-to-End" sections must appear AFTER a separator line "⸻".
 * - Ensures there is at least one separator between skeleton and full reports.
 *
 * Usage:
 *   php docs/tools/validate_audit_structure.php
 */

$files = [
    __DIR__ . '/../02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md',
    __DIR__ . '/../02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md',
    __DIR__ . '/../02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md',
    __DIR__ . '/../02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md', // allowed (will be skipped if not an audit file)
];

$errors = [];

foreach ($files as $file) {
    if (!is_file($file)) {
        continue;
    }
    $content = file_get_contents($file);
    if ($content === false) {
        $errors[] = "Cannot read file: $file";
        continue;
    }

    // Detect skeleton header (first non-empty line should mention "Skeleton" or be the roadmap file)
    $lines = preg_split('/\R/', $content);
    $firstNonEmpty = null;
    foreach ($lines as $line) {
        if (trim($line) !== '') {
            $firstNonEmpty = $line;
            break;
        }
    }

    $isRoadmap = (bool)preg_match('/DAG_IMPLEMENTATION_ROADMAP/i', $file);
    $isSkeletonOK = $isRoadmap || (strpos($firstNonEmpty ?? '', 'Skeleton') !== false);
    if (!$isSkeletonOK) {
        $errors[] = basename($file) . ': First section must be the Skeleton header.';
        continue;
    }

    // If file contains a "Full ... Audit - End-to-End" heading, ensure it is separated by "⸻"
    if (preg_match('/^# .+Audit - End-to-End/m', $content)) {
        // Ensure a separator "⸻" exists BEFORE the first full audit heading
        $posFull = strpos($content, "\n# ");
        $posSep = strpos($content, "⸻");
        if ($posFull !== false) {
            if ($posSep === false || $posSep > $posFull) {
                $errors[] = basename($file) . ': Missing separator "⸻" before Full Audit section.';
            }
        }
    }
}

if (!empty($errors)) {
    fwrite(STDERR, "Audit structure validation FAILED:\n- " . implode("\n- ", $errors) . "\n");
    exit(1);
}

echo "Audit structure validation OK\n";
exit(0);

