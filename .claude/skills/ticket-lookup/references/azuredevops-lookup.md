# Azure DevOps Work Item Lookup

## Configuration

Add to your zone in `config.toml`:

```toml
[zones.work]
features.azure_devops = true

[zones.work.azure_devops]
organization = "your-org"
project = "YourProject"
```

## Environment Variables

Required:
- `ADO_PAT` - Personal Access Token from https://dev.azure.com/{org}/_usersSettings/tokens

Optional (override config):
- `ADO_ORGANIZATION` - Azure DevOps organization name
- `ADO_PROJECT` - Default project name

## PAT Permissions

When creating your Personal Access Token, grant these scopes:
- **Work Items**: Read (minimum for lookups)
- **Work Items**: Read & Write (if you want to update items later)

## Usage

```bash
# By work item ID
scripts/azuredevops-fetch.sh 12345

# With ADO- prefix
scripts/azuredevops-fetch.sh ADO-12345
```

## API Reference

The script uses Azure DevOps REST API v7.0:

```
GET https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?$expand=relations&api-version=7.0
Authorization: Basic base64(:$PAT)
```

## Output Fields

| Field | Source |
|-------|--------|
| ticket_id | ADO-{id} |
| title | System.Title |
| type | System.WorkItemType (Bug, Task, User Story, etc.) |
| status | System.State |
| priority | Microsoft.VSTS.Common.Priority |
| severity | Microsoft.VSTS.Common.Severity |
| assignee | System.AssignedTo |
| created_by | System.CreatedBy |
| created | System.CreatedDate |
| changed | System.ChangedDate |
| iteration | System.IterationPath |
| area | System.AreaPath |
| tags | System.Tags |
| parent | Parent work item ID (if linked) |
| url | Direct link to work item |
| description | System.Description (HTML stripped) |

## Work Item Types

Common Azure DevOps work item types:
- **Epic** - Large feature or initiative
- **Feature** - Deliverable feature
- **User Story** - User-facing requirement
- **Task** - Implementation task
- **Bug** - Defect to fix
- **Issue** - Problem to investigate

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid or expired PAT | Generate new PAT |
| 404 Not Found | Work item doesn't exist | Check ID |
| Azure DevOps not enabled | Feature disabled for zone | Add `features.azure_devops = true` |
