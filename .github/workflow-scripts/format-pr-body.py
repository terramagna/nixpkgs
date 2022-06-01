import subprocess
import shutil
import sys
import os


def run(cmd, **kwargs):
    """Execute the given command and return the stdout as a decoded string."""

    cmd, *args = cmd.split(" ")

    resolved_cmd = shutil.which(cmd)
    if not resolved_cmd:
        raise Exception(f"Couldn't resolve command `{cmd}`.")

    res = subprocess.run([resolved_cmd, *args],
                         text=True,
                         capture_output=True,
                         **kwargs)

    # Raises `CalledProcessError` on non-zero exit.
    res.check_returncode()

    return res.stdout.strip()


def emit_action_output(data, *, name):
    """"Escape the given `out` following GitHub Action's escape criteria."""

    table = str.maketrans({
        "\n": "%0A",
        "\r": "%0D",
        "%":  "%25",
    })
    escaped = data.translate(table)
    print(f"::set-output name={name}::{escaped}")


# The script should fail if the runner doesn't provide this environment variable.
raw_pr_body = os.environ["RAW_PR_BODY"]

pr_body = run("git interpret-trailers --only-input", input=raw_pr_body)
pr_trailers = run("git interpret-trailers --parse", input=pr_body)

# Remove trailers from the commit message:
filtered_body = pr_body.removesuffix(pr_trailers)

# Format `filtered_body` with Prettier:
print("Formatting files with `npx prettier`...")
formatted_body = run(
    "npx --yes prettier --parser=markdown --prose-wrap=always --print-width=88",
    input=filtered_body
)
print("Done formatting.")

# Join the formatted body with the original trailers:
formatted_pr_body = "\n".join([
    formatted_body.strip(),
    "",
    pr_trailers
])

emit_action_output(formatted_pr_body.strip(), name="formatted_pr_body")
