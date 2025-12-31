# Session Categories Reference

Categories are AI-determined based on session content analysis. Choose the single best-fit category.

## Work Categories

### tickets
Work on specific tracked issues from Jira, SDP, Linear, or GitHub Issues.
- Has ticket reference (e.g., PROJ-123, SDP-456)
- Focused on defined requirements
- Usually has acceptance criteria

### features
Building new functionality or capabilities.
- Adding new endpoints, components, or modules
- User-facing enhancements
- New integrations

### bugs
Fixing defects or unexpected behavior.
- Debugging issues
- Error resolution
- Regression fixes

### infra
Infrastructure and DevOps work.
- CI/CD pipelines
- Deployment configurations
- Cloud resources (AWS, GCP, Azure)
- Kubernetes, Docker, Terraform

### investigation
Analyzing problems without immediate fix.
- Root cause analysis
- Performance profiling
- Security audits
- Log analysis

### docs
Documentation work.
- README updates
- API documentation
- Architecture decisions
- Runbooks

### meetings
Meeting-related work.
- Prep for meetings
- Follow-up action items
- Design reviews

### planning
Strategic and planning work.
- Sprint planning
- Architecture design
- Roadmap work
- Technical specifications

## Home/Personal Categories

### projects
Personal software projects.
- Side projects
- Open source contributions
- Personal tools

### learning
Educational and skill-building sessions.
- Tutorials and courses
- Technology exploration
- Certification prep
- Reading/studying

### health
Health and fitness related.
- Fitness tracking analysis
- Health app development
- Medical research

### finance
Financial projects.
- Budget tools
- Investment analysis
- Tax preparation

### hobbies
Hobby-related technical work.
- Home automation
- Media management
- Gaming projects

### maintenance
Personal system maintenance.
- Dotfiles management
- Tool updates
- Backup configurations

### family
Family-related projects.
- Shared calendars
- Family websites
- Photo organization

## Universal Categories

### research
Deep dive into a topic.
- Technology evaluation
- Competitive analysis
- Market research

### experiment
Trying something new.
- Proof of concepts
- Technology spikes
- "What if" explorations

### poc
Proof of concept implementations.
- Validation of approaches
- Minimal viable tests
- Feasibility studies

### support
Helping others.
- Answering questions
- Pair programming
- Code review support

## Category Selection Guidelines

1. **Prefer specific over generic**: Use `bugs` over `investigation` if fixing a bug
2. **Consider the primary goal**: A ticket that involves learning is still `tickets`
3. **Zone context matters**: Same work might be `features` at work, `projects` at home
4. **When ambiguous**: Ask the user or use the broader category

## Examples

| Session Content | Category |
|----------------|----------|
| "Fixed null pointer in user service" | bugs |
| "Implemented new payment gateway" | features |
| "Set up Kubernetes monitoring" | infra |
| "Why is the API slow?" | investigation |
| "Learning Rust basics" | learning |
| "Home Assistant automation" | hobbies |
| "Evaluated three database options" | research |
| "Quick test of new AI model" | experiment |
