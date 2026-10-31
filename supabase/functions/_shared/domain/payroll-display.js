// Add only display identity to payroll rows already authorized by the caller.
export function payrollDisplay(rows, employees) {
  const identities = new Map(employees.map(employee => [employee.recordId, employee]));
  return rows.map(row => {
    if (row.isDeleted === true || row.isDeleted === 'TRUE') return row;
    const employee = identities.get(row.employeeId);
    return { ...row, employeeName: employee?.fullName || row.employeeName || 'Unknown employee',
      employeeCode: employee?.employeeCode || row.employeeCode || row.employeeId || '' };
  });
}
