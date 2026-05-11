DELETE has_permission WHERE in = role:editor;
DELETE has_permission WHERE in = role:admin AND out IN [
    permission:admin_jobs, permission:admin_drafts, permission:admin_publish,
    permission:admin_library, permission:admin_authors, permission:admin_ai,
    permission:admin_uploads
];
DELETE role:editor;
DELETE permission:admin_jobs;
DELETE permission:admin_drafts;
DELETE permission:admin_publish;
DELETE permission:admin_library;
DELETE permission:admin_authors;
DELETE permission:admin_ai;
DELETE permission:admin_uploads;
