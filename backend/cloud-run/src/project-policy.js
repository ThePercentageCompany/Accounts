import { requireThat } from './errors.js';
const active = row => row.isDeleted !== true && row.isDeleted !== 'TRUE';
export async function validateProject(sheets, companyId, table, action, old, values) {
  if (table === 'Projects') {
    const project = { ...old, ...values };
    if (action !== 'delete') {
      requireThat(typeof project.name === 'string' && project.name.trim() === project.name && project.name.length > 0 && project.name.length <= 200 &&
        ['ACTIVE', 'ARCHIVED'].includes(project.status) && (!project.description || project.description.length <= 1000),
        400, 'INVALID_PROJECT', 'Supply a project name, description and valid status.');
      const rows = (await sheets.read(companyId, ['Projects'])).Projects;
      requireThat(!rows.some(r => active(r) && r.recordId !== old?.recordId && r.name.toLowerCase() === project.name.toLowerCase()),
        409, 'PROJECT_EXISTS', 'A project with this name already exists.');
    }
    if (old && (action === 'delete' || project.name !== old.name)) {
      const tasks = (await sheets.read(companyId, ['Tasks'])).Tasks;
      requireThat(!tasks.some(t => active(t) && t.project === old.name), 409, 'PROJECT_REFERENCED', 'Reassign tasks before renaming or deleting this project.');
    }
  }
  if (table === 'Tasks' && action !== 'delete' && values.project && values.project !== old?.project) {
    const projects = (await sheets.read(companyId, ['Projects'])).Projects;
    requireThat(projects.some(p => active(p) && p.status === 'ACTIVE' && p.name === values.project),
      409, 'PROJECT_NOT_FOUND', 'Select an active project from this company.');
  }
}
