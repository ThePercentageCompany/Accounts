# Employee references

`GET /v1/employee/references/{table}?section={editorSection}` exposes picker fields after checking section grants. Document editors read customer/public company references; payroll editors read employee identity/status; capital editors read shareholder identity/status; task access permits project selection. Responses omit bank details, salary amounts and credentials. Generic reads retain section and SELF scope restrictions.
