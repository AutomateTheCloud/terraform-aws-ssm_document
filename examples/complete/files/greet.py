# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0


def handler(events, context):
    """Return a greeting for the runbook's Message parameter."""
    return {"greeting": "Hello, " + events["message"] + "!"}
