#!/usr/bin/env python3
"""Простой анализатор Kubernetes audit log."""

from __future__ import annotations

import json
import logging
import sys
from pathlib import Path
from typing import Any, Callable, Optional

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
LOG = logging.getLogger("audit-analyzer")


Event = dict[str, Any]
CheckResult = Optional[tuple[str, dict[str, Any]]]


def load_events(path: Path) -> list[Event]:
    events: list[Event] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as err:
                LOG.warning("Строка %d: %s", line_number, err)
    return events


def event_user(event: Event) -> str:
    return event.get("user", {}).get("username", "unknown")


def event_status(event: Event) -> int:
    return int(event.get("responseStatus", {}).get("code", 0))


def check_secret_access(event: Event) -> CheckResult:
    obj = event.get("objectRef", {})
    verb = event.get("verb")
    if obj.get("resource") != "secrets" or verb not in {"get", "list", "watch"}:
        return None

    user = event_user(event)
    suspicious = not user.startswith("system:serviceaccount:kube-")
    if user.startswith("system:serviceaccount:"):
        parts = user.split(":")
        if len(parts) > 2 and parts[2] not in {"kube-system", "kube-public", "kube-node-lease"}:
            suspicious = True

    if not suspicious:
        return None

    return (
        "secrets_access",
        {
            "success": 200 <= event_status(event) < 300,
            "response_code": event_status(event),
        },
    )


def check_privileged_pod(event: Event) -> CheckResult:
    obj = event.get("objectRef", {})
    if obj.get("resource") != "pods" or event.get("verb") != "create":
        return None

    spec = event.get("requestObject", {}).get("spec", {})
    containers = spec.get("containers", [])
    for container in containers:
        if container.get("securityContext", {}).get("privileged") is True:
            return (
                "privileged_pod",
                {
                    "success": 200 <= event_status(event) < 300,
                    "response_code": event_status(event),
                },
            )
    return None


def check_exec(event: Event) -> CheckResult:
    obj = event.get("objectRef", {})
    if event.get("verb") != "create" or obj.get("subresource") != "exec":
        return None

    namespace = obj.get("namespace", "")
    if namespace not in {"kube-system", "kube-public"}:
        return None

    return (
        "exec",
        {
            "success": event_status(event) in {101, 200, 201},
            "response_code": event_status(event),
        },
    )


def check_rolebinding(event: Event) -> CheckResult:
    obj = event.get("objectRef", {})
    if obj.get("resource") not in {"rolebindings", "clusterrolebindings"}:
        return None
    if event.get("verb") != "create":
        return None

    role_name = event.get("requestObject", {}).get("roleRef", {}).get("name")
    if role_name not in {"cluster-admin", "admin", "edit"}:
        return None

    return (
        "rolebinding",
        {
            "success": 200 <= event_status(event) < 300,
            "response_code": event_status(event),
        },
    )


def check_audit_policy_delete(event: Event) -> CheckResult:
    if event.get("verb") != "delete":
        return None
    obj = event.get("objectRef", {})
    name = obj.get("name", "") or obj.get("resource", "")
    if "audit" not in str(name).lower():
        return None

    return (
        "audit_policy_delete",
        {
            "success": 200 <= event_status(event) < 300,
            "response_code": event_status(event),
        },
    )


CHECKS: list[Callable[[Event], CheckResult]] = [
    check_secret_access,
    check_privileged_pod,
    check_exec,
    check_rolebinding,
    check_audit_policy_delete,
]


def analyse(events: list[Event]) -> dict[str, Any]:
    summary = {
        "total_events": len(events),
        "secrets_access": 0,
        "privileged_pod": 0,
        "exec": 0,
        "rolebinding": 0,
        "audit_policy_delete": 0,
    }

    suspicious: list[Event] = []

    for event in events:
        tags: List[str] = []
        details: Dict[str, Any] = {}
        for check in CHECKS:
            result = check(event)
            if result:
                tag, info = result
                tags.append(tag)
                details[tag] = info
                summary[tag] += 1
        if tags:
            event_copy = event.copy()
            event_copy["_analysis"] = {
                "tags": tags,
                "user": event_user(event),
                "namespace": event.get("objectRef", {}).get("namespace", ""),
                "timestamp": event.get("requestReceivedTimestamp"),
                "details": details,
            }
            suspicious.append(event_copy)

    summary["suspicious_events"] = len(suspicious)
    return {"summary": summary, "events": suspicious}


def save_report(report: dict[str, Any], output_path: Path) -> None:
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    LOG.info("Подозрительные события сохранены в %s", output_path)


def print_summary(report: dict[str, Any]) -> None:
    summary = report["summary"]
    LOG.info(
        "Всего событий: %(total_events)d | Подозрительных: %(suspicious_events)d | "
        "secrets: %(secrets_access)d | privileged pods: %(privileged_pod)d | "
        "exec: %(exec)d | rolebinding: %(rolebinding)d | audit-policy delete: %(audit_policy_delete)d",
        summary,
    )


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        LOG.error("Использование: analyze-audit.py <audit.log> [audit-extract.json]")
        return 1

    input_path = Path(argv[1])
    if not input_path.exists():
        LOG.error("Файл не найден: %s", input_path)
        return 1

    output_path = Path(argv[2]) if len(argv) > 2 else Path("audit-extract.json")

    events = load_events(input_path)
    report = analyse(events)

    print_summary(report)
    save_report(report, output_path)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
