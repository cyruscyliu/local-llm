.PHONY: help task-summary task-runnable task-next task-reset task-set task-output

help:
	@echo "Common commands:"
	@echo "  make task-summary"
	@echo "  make task-runnable"
	@echo "  make task-next"
	@echo "  make task-reset TASK_ID=03_deploy_postgres"
	@echo "  make task-set TASK_ID=03_deploy_postgres STATUS=in_progress [ERROR='...']"
	@echo "  make task-output TASK_ID=03_deploy_postgres KV='port=5432 host=db'"

task-summary:
	@./scripts/tasks.py summary

task-runnable:
	@./scripts/tasks.py runnable

task-next:
	@./scripts/tasks.py next

task-reset:
	@test -n "$(TASK_ID)" || (echo "Missing TASK_ID"; exit 2)
	@./scripts/tasks.py reset "$(TASK_ID)"

task-set:
	@test -n "$(TASK_ID)" || (echo "Missing TASK_ID"; exit 2)
	@test -n "$(STATUS)" || (echo "Missing STATUS"; exit 2)
	@./scripts/tasks.py set "$(TASK_ID)" "$(STATUS)" --error "$(ERROR)"

task-output:
	@test -n "$(TASK_ID)" || (echo "Missing TASK_ID"; exit 2)
	@test -n "$(KV)" || (echo "Missing KV (space-separated KEY=VALUE pairs)"; exit 2)
	@./scripts/tasks.py output "$(TASK_ID)" $(KV)

